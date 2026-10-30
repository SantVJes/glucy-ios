import Foundation
import Testing
@testable import Glucy

/// Los dos artefactos de verdad, cargados del paquete de la app.
///
/// **Esto es lo que cierra el contrato entre los tres repositorios.** `glucy-ml` entrena,
/// convierte y comprueba la conversión fila por fila contra XGBoost; lo que no podía comprobar
/// desde Python es que el teléfono alimente al modelo igual. Aquí se predice con una fila
/// calculada por `VectorDeCaracteristicas` y se compara contra el número que el XGBoost
/// original dio para esa misma fila, fijado como literal.
///
/// Si alguien reemplaza los `.mlmodel` por unos reentrenados, estas dos cifras cambian y la
/// prueba falla. **Es lo que se quiere**: adoptar un modelo nuevo tiene que ser una decisión
/// visible, con sus números nuevos escritos al lado.
struct ModeloCoreMLTests {

    /// Una fila calculada a mano y verificada contra el pipeline, la misma de
    /// `VectorDeCaracteristicasTests`: serie de 13 lecturas subiendo 5 mg/dL cada cinco
    /// minutos hasta 160, una comida de 60 g hace 90 minutos con absorción de 180, un bolo de
    /// 6 UI hace tres horas, y medianoche exacta de un viernes.
    private static let fila: [String: Double] = [
        "mg_dl": 160, "rezago_5": 155, "rezago_10": 150, "rezago_15": 145,
        "rezago_30": 130, "rezago_60": 100,
        "derivada_1": 1, "derivada_2": 0,
        "media_30": 147.5, "media_60": 132.5,
        "cob": 30, "iob": 6 * 0.158_796_415_372_838_06,
        "hora_sin": 0, "hora_cos": 1, "dia_semana": 4,
    ]

    /// La misma fila con los huecos que deja una serie de dos lecturas. Va aparte porque
    /// comprueba otra cosa: que Core ML trate el `NaN` como lo trata XGBoost. El artefacto
    /// trae 498 nodos con `missingValueTracksTrueChild`, y si el teléfono no respetara eso la
    /// predicción se desviaría hasta 19.8 mg/dL.
    private static var filaConHuecos: [String: Double] {
        var con = fila
        for nombre in ["rezago_10", "rezago_15", "rezago_30", "rezago_60", "derivada_2",
                       "media_60"] {
            con[nombre] = Double.nan
        }
        return con
    }

    private func cargar(_ nombre: String) throws -> ModeloCoreML {
        try ModeloCoreML(nombre: nombre)
    }

    // MARK: - Lo que el artefacto declara

    @Test("Las entradas del artefacto son exactamente las que la app calcula")
    func lasEntradasCuadranConElContrato() throws {
        // Es la comprobación por la que existe `ModeloCoreML`. Si un nombre no cuadrara, el
        // `init` lanzaría `contratoRoto` y esto no llegaría a ejecutarse: que cargue **es** la
        // prueba. La lista se mira además para que, si alguien cambia el orden del contrato, se
        // vea aquí y no en una predicción torcida.
        for nombre in [ModeloCoreML.nombreM1, ModeloCoreML.nombreM2] {
            let modelo = try cargar(nombre)
            #expect(modelo.descrito.caracteristicas == VectorDeCaracteristicas.densas)
        }
    }

    @Test("Cada artefacto dice su versión y su horizonte")
    func cadaArtefactoDiceSuVersionYSuHorizonte() throws {
        let m1 = try cargar(ModeloCoreML.nombreM1)
        let m2 = try cargar(ModeloCoreML.nombreM2)

        #expect(m1.descrito.horizonteMin == 30)
        #expect(m2.descrito.horizonteMin == 60)
        // La versión sale del archivo y no de una constante de Swift, así que reemplazar el
        // artefacto no deja a la app reportando una versión que no calculó el número (RF-25).
        #expect(m1.descrito.version == "v0.2.0-simulador")
        #expect(m2.descrito.version == "v0.2.0-simulador")
    }

    @Test("Los artefactos de hoy dicen que sus métricas no se pueden reportar")
    func lasMetricasDeHoyNoSePuedenReportar() throws {
        // Están entrenados con el simulador fisiológico, no con datos de personas. Lo dice el
        // propio archivo, y por eso sus métricas no van al documento final (riesgo R-2). El
        // día que llegue OhioT1DM esta prueba falla, y eso es la señal de que hay que
        // actualizar el reporte.
        let m1 = try cargar(ModeloCoreML.nombreM1)
        let m2 = try cargar(ModeloCoreML.nombreM2)
        #expect(m1.descrito.metricasSePuedenReportar == false)
        #expect(m2.descrito.metricasSePuedenReportar == false)
    }

    @Test("Un artefacto que no está en el paquete se dice, no se adivina")
    func unArtefactoQueNoEstaSeDice() {
        #expect(throws: ErrorModelo.noEstaEnElPaquete(nombre: "GlucyM9")) {
            try ModeloCoreML(nombre: "GlucyM9")
        }
    }

    // MARK: - El número, contra el XGBoost original

    @Test("M-1 da el mismo número que el XGBoost con el que se entrenó")
    func m1DaElMismoNumeroQueXgboost() async throws {
        let modelo = try cargar(ModeloCoreML.nombreM1)
        let entradas = try VectorDeCaracteristicas.paraCoreML(Self.fila)
        let valor = try await modelo.predecir(entradas)
        // 160.777_74 es lo que `m1-v0.2.0-simulador.ubj` devuelve para esta fila en float32.
        // La tolerancia es de una centésima; la diferencia medida en la conversión fue de
        // 0.000 259 mg/dL sobre 2 000 filas.
        #expect(abs(valor - 160.777_74) < 0.01, "Core ML dio \(valor)")
    }

    @Test("M-2 da el mismo número que el XGBoost con el que se entrenó")
    func m2DaElMismoNumeroQueXgboost() async throws {
        let modelo = try cargar(ModeloCoreML.nombreM2)
        let entradas = try VectorDeCaracteristicas.paraCoreML(Self.fila)
        let valor = try await modelo.predecir(entradas)
        #expect(abs(valor - 139.964_63) < 0.01, "Core ML dio \(valor)")
    }

    @Test("Una fila con huecos da el número que da XGBoost con esos mismos huecos")
    func losHuecosSeTratanIgualQueEnXgboost() async throws {
        // La comprobación que no se podía hacer desde Python. Si Core ML ignorara el valor
        // faltante, estos números serían otros: la desviación medida al no respetarlo llegaba
        // a 19.8 mg/dL en M-1 y a 35.9 en M-2.
        let entradas = try VectorDeCaracteristicas.paraCoreML(Self.filaConHuecos)
        let m1 = try await cargar(ModeloCoreML.nombreM1).predecir(entradas)
        let m2 = try await cargar(ModeloCoreML.nombreM2).predecir(entradas)
        #expect(abs(m1 - 158.900_01) < 0.01, "M-1 con huecos dio \(m1)")
        #expect(abs(m2 - 154.951_94) < 0.01, "M-2 con huecos dio \(m2)")
    }

    @Test("La fila que calcula la app es la misma que se le pasa al modelo")
    func laFilaDeLaAppEsLaQueSePasa() async throws {
        // Las cifras de arriba van escritas a mano para poder cotejarlas con Python. Esta
        // prueba cierra el círculo: la misma fila, pero calculada por `VectorDeCaracteristicas`
        // a partir de lecturas, comidas y dosis, tiene que dar el mismo número.
        let instante = Date(timeIntervalSince1970: 1_758_240_000)
        let serie = (0..<13).map { indice in
            LecturaGlucosaDato(
                mgDl: 100 + Double(indice) * 5,
                tsUtc: instante.addingTimeInterval(-Double(12 - indice) * 5 * 60),
                origen: .sensor
            )
        }
        let vector = VectorDeCaracteristicas.denso(
            serie: serie,
            comidas: [ComidaDato(
                tsUtc: instante.addingTimeInterval(-90 * 60), carbsG: 60,
                tiempoAbsorcionMin: 180, origen: .manual
            )],
            dosis: [DosisInsulinaDato(
                tsUtc: instante.addingTimeInterval(-180 * 60), unidades: 6, tipo: .bolo
            )],
            ahora: instante,
            zona: TimeZone(identifier: "UTC")!
        )
        let entradas = try VectorDeCaracteristicas.paraCoreML(vector)
        let valor = try await cargar(ModeloCoreML.nombreM1).predecir(entradas)
        #expect(abs(valor - 160.777_74) < 0.01, "con la fila calculada dio \(valor)")
    }
}
