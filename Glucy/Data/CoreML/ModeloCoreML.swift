import CoreML
import Foundation

/// El artefacto de glucy-ml corriendo con Core ML, dentro del teléfono.
///
/// **Lo que hace de verdad esta clase es comprobar el contrato al cargar.** Predecir son tres
/// líneas; la razón de que exista es que un artefacto cuyas entradas no sean las que la app
/// calcula no puede llegar a la pantalla. Si `mg_dl` se llamara `glucosa`, Core ML no se
/// queja: recibe un diccionario con una llave que no conoce, usa su valor faltante para la
/// entrada que sí espera, y devuelve un número. Plausible y equivocado.
///
/// Es la misma comprobación que el backend hace al cargar el artefacto, y existe por el mismo
/// motivo: es el error más caro del proyecto y el más fácil de no ver.
actor ModeloCoreML: RepositorioModelo {

    /// Los nombres de los archivos en el paquete. Sin la versión adentro **a propósito**: la
    /// versión se lee de los metadatos del propio artefacto, así que reemplazarlo por uno
    /// reentrenado es copiar el archivo y nada más (RF-29).
    static let nombreM1 = "GlucyM1"
    static let nombreM2 = "GlucyM2"

    /// La salida que declara el artefacto convertido. Fijada aquí porque es parte del
    /// contrato: si cambiara, la conversión de glucy-ml tendría que decirlo.
    static let nombreDeLaSalida = "target"

    nonisolated let descrito: ModeloDescrito
    private let modelo: MLModel

    /// - Parameter nombre: el del archivo, sin extensión.
    /// - Parameter paquete: se puede pasar otro para las pruebas.
    init(nombre: String, paquete: Bundle = .main) throws {
        // Xcode compila el `.mlmodel` del proyecto a un `.mlmodelc` dentro del paquete; es ese
        // el que Core ML abre. Si no está, lo más probable es que el archivo no se haya
        // agregado al objetivo, y conviene que el error lo diga en lugar de sonar a corrupción.
        guard let url = paquete.url(forResource: nombre, withExtension: "mlmodelc") else {
            throw ErrorModelo.noEstaEnElPaquete(nombre: nombre)
        }

        let configuracion = MLModelConfiguration()
        // Solo CPU, y no por rendimiento: un ensamble de árboles no gana nada con la Neural
        // Engine, y lo que sí importa es que el mismo vector dé siempre el mismo número. La
        // comprobación de fidelidad contra XGBoost —0.000259 mg/dL de diferencia máxima en
        // M-1— se midió en CPU; dejar que el sistema elija otra unidad cambia el redondeo y
        // esa comprobación deja de significar nada.
        configuracion.computeUnits = .cpuOnly

        let cargado: MLModel
        do {
            cargado = try MLModel(contentsOf: url, configuration: configuracion)
        } catch {
            throw ErrorModelo.noSePudoCargar(
                nombre: nombre, motivo: error.localizedDescription
            )
        }

        let descripcion = cargado.modelDescription
        let entradas = descripcion.inputDescriptionsByName

        // 1. Los nombres, contra el contrato. Es la comprobación por la que existe esta clase.
        let declaradas = Set(entradas.keys)
        let delContrato = Set(VectorDeCaracteristicas.densas)
        guard declaradas == delContrato else {
            throw ErrorModelo.contratoRoto(
                sobran: declaradas.subtracting(delContrato).sorted(),
                faltan: delContrato.subtracting(declaradas).sorted()
            )
        }

        // 2. Que cada una sea un número suelto. Si una conversión futura produjera un arreglo,
        // el diccionario fallaría al predecir con un error que no explica nada; aquí se dice
        // cuál y cuándo.
        if let noEsDouble = entradas.first(where: { $0.value.type != .double })?.key {
            throw ErrorModelo.salidaInesperada(
                detalle: "la entrada \(noEsDouble) no es un número de doble precisión"
            )
        }

        // 3. La salida. `predictedFeatureName` es lo que el artefacto dice que hay que leer.
        guard descripcion.predictedFeatureName == Self.nombreDeLaSalida else {
            throw ErrorModelo.salidaInesperada(
                detalle: "la salida se llama \(descripcion.predictedFeatureName ?? "nada") "
                    + "y se esperaba \(Self.nombreDeLaSalida)"
            )
        }

        // 4. Los metadatos, que son los que cumplen RF-25. Sin versión no hay auditoría de
        // con qué se calculó un número, y sin horizonte el de 60 minutos podría cargarse donde
        // va el de 30: predeciría bien y contestaría otra pregunta.
        let metadatos = descripcion.metadata
        let propios = (metadatos[.creatorDefinedKey] as? [String: Any] ?? [:])
            .compactMapValues { $0 as? String }
        let version = propios["glucy.version"] ?? (metadatos[.versionString] as? String)
        guard let version, !version.isEmpty else {
            throw ErrorModelo.metadatosIncompletos(falta: "glucy.version")
        }
        guard let horizonte = propios["glucy.horizonte_min"].flatMap({ Int($0) }) else {
            throw ErrorModelo.metadatosIncompletos(falta: "glucy.horizonte_min")
        }

        modelo = cargado
        descrito = ModeloDescrito(
            version: version,
            horizonteMin: horizonte,
            // Del metadato cuando viene, porque lleva el orden del contrato; el diccionario de
            // Core ML no tiene orden. Para predecir da igual —se alimenta por nombre— y para
            // enseñar los factores en pantalla, no.
            caracteristicas: propios["glucy.caracteristicas"]?
                .split(separator: ",").map { String($0) }
                ?? entradas.keys.sorted(),
            // Lo que el archivo dice de sí mismo. Mientras sea falso, las métricas de este
            // modelo no van al documento final (riesgo R-2).
            metricasSePuedenReportar: propios["glucy.se_puede_reportar"] == "true"
        )
    }

    func predecir(_ vector: [String: Double]) async throws -> Double {
        let entradas = try MLDictionaryFeatureProvider(
            // `MLFeatureValue(double:)` explícito en lugar de dejar que el puente elija: un
            // `NaN` tiene que llegar como `NaN` al árbol, que es quien sabe para qué lado
            // mandar la fila con un hueco. Rellenarlo desvía hasta 19.8 mg/dL.
            dictionary: vector.mapValues { MLFeatureValue(double: $0) }
        )
        // La sobrecarga asíncrona, que es la que iOS 17 añadió: la síncrona existe todavía,
        // pero el compilador elige esta y pide el `await`.
        let salida = try await modelo.prediction(from: entradas)
        guard let valor = salida.featureValue(for: Self.nombreDeLaSalida)?.doubleValue else {
            throw ErrorModelo.salidaInesperada(
                detalle: "no vino \(Self.nombreDeLaSalida) en la respuesta del modelo"
            )
        }
        guard valor.isFinite else {
            throw ErrorModelo.salidaInesperada(detalle: "el modelo devolvió \(valor)")
        }
        return valor
    }
}
