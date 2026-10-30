import Foundation

/// Qué trajo el servidor, o por qué no trajo nada.
nonisolated enum ResultadoDelServidor: Sendable, Equatable {
    /// No hay dirección de backend configurada. La app funciona completa sin esto (regla 1):
    /// el número sigue saliendo, lo que falta son los factores y la frase.
    case sinBackend
    /// Había a quién preguntar y no contestó, o contestó algo que no sirve.
    case noLlego(motivo: String)
    case llego([FactoresYExplicacion])
}

/// Los factores y la explicación, que son la mitad de C-16 que no corre en el teléfono.
///
/// **El número no sale de aquí.** Lo calcula Core ML en el dispositivo y sigue saliendo sin
/// red (caso P-07). De aquí salen las cinco contribuciones SHAP —que un bosque convertido a
/// Core ML no puede dar, porque predice un número y nada más— y la frase en español llano.
///
/// Tres cosas que conviene leer antes del código:
///
/// 1. **Las dos llamadas van en segundo plano.** `GET /predict` contesta en menos de 200 ms,
///    pero `POST /explain` tarda de uno a tres segundos, y la pantalla de inicio tiene que
///    estar pintada mucho antes. Nada de esto bloquea nada.
/// 2. **Se pide la frase de un solo horizonte**, el que la pantalla enseña. Pedir las dos
///    duplicaría una llamada de tres segundos para una frase que nadie va a leer todavía.
/// 3. **Los dos números se comparan, y el que gana es el del teléfono.** Es el que se calculó
///    con la fila que el teléfono armó y el que sigue saliendo sin red. El desacuerdo se
///    guarda en lugar de descartarse: ya pasó una vez que los dos caminos no armaban la misma
///    fila, y el síntoma era un número plausible y equivocado.
nonisolated struct PedirFactoresYExplicacion: Sendable {
    /// `nil` cuando no hay dirección configurada.
    let backend: (any ClienteBackend)?
    /// Donde se guarda lo que llegó, para repintarlo al instante en el siguiente arranque.
    let cache: (any RepositorioPrediccionCache)?

    /// - Parameter proyecciones: las que calculó el teléfono. De la primera sale la frase.
    /// - Parameter cobG: los carbohidratos activos del momento, que van en el sobre de
    ///   `/explain` porque el modelo de lenguaje los menciona.
    /// - Parameter asistenteActivo: si la persona quiere la frase del modelo de lenguaje. Con
    ///   `false` el servidor arma la plantilla determinista y no llama a ningún modelo.
    func ejecutar(
        proyecciones: [Proyeccion],
        modo: ModoApp,
        umbralHipo: Double,
        umbralHiper: Double,
        cobG: Double,
        iobUI: Double,
        asistenteActivo: Bool = true
    ) async -> ResultadoDelServidor {
        guard let backend else { return .sinBackend }
        guard !proyecciones.isEmpty else { return .noLlego(motivo: "no hay predicción propia") }

        let remota: PrediccionRemota
        do {
            remota = try await backend.pedirPrediccion()
        } catch {
            return .noLlego(motivo: String(describing: error))
        }
        guard !remota.predicciones.isEmpty else {
            // En modo sin sensor el servidor contesta 200 sin predicciones y con su aviso.
            // No es un error suyo ni de la app (RF-10b).
            return .noLlego(motivo: remota.aviso ?? "el servidor no devolvió predicciones")
        }

        // La frase se pide una sola vez, para el horizonte que la pantalla enseña.
        let primera = proyecciones[0]
        var explicacion: String?
        var deLaPlantilla = false
        if let delServidor = remota.predicciones.first(where: {
            $0.horizonteMin == primera.horizonteMin
        }) {
            let sobre = Self.sobre(
                proyeccion: primera,
                shap: delServidor.shap,
                umbralHipo: umbralHipo,
                umbralHiper: umbralHiper,
                cobG: cobG,
                iobUI: iobUI,
                asistenteActivo: asistenteActivo
            )
            if let sobre, let llegada = try? await backend.pedirExplicacion(sobre) {
                explicacion = llegada.explicacion
                deLaPlantilla = llegada.origen == .plantilla
            }
        }

        var resultados: [FactoresYExplicacion] = []
        for proyeccion in proyecciones {
            guard let delServidor = remota.predicciones.first(where: {
                $0.horizonteMin == proyeccion.horizonteMin
            }) else { continue }

            let esLaDeLaFrase = proyeccion.horizonteMin == primera.horizonteMin
            let aporte = FactoresYExplicacion(
                horizonteMin: proyeccion.horizonteMin,
                valorDelServidorMgDl: delServidor.valorPredicho,
                tsBase: remota.tsBase,
                factores: delServidor.factores.map {
                    FactorDeLaPrediccion(nombre: $0.nombre, mgDl: $0.mgDl)
                },
                shap: delServidor.shap.map {
                    ContribucionDeLaPrediccion(variable: $0.variable, mgDl: $0.mgDl)
                },
                explicacion: esLaDeLaFrase ? explicacion : nil,
                deLaPlantilla: esLaDeLaFrase && deLaPlantilla,
                desacuerdoMgDl: Self.desacuerdo(
                    propio: proyeccion, delServidor: delServidor.valorPredicho,
                    tsBaseDelServidor: remota.tsBase
                )
            )
            resultados.append(aporte)

            try? await cache?.guardar(PrediccionGuardadaDato(
                tsUtc: proyeccion.base.ts,
                horizonteMin: proyeccion.horizonteMin,
                // El número del teléfono, no el del servidor: es el que la pantalla enseña.
                valorMgDl: proyeccion.valorMgDl,
                modo: modo,
                versionModelo: proyeccion.versionModelo,
                explicacion: aporte.explicacion,
                factores: aporte.factores,
                shap: aporte.shap
            ))
        }

        guard !resultados.isEmpty else {
            return .noLlego(motivo: "el servidor no respondió a los mismos horizontes")
        }
        return .llego(resultados)
    }

    /// Lo que quedó guardado de la última vez, para pintar la frase y los factores **antes**
    /// de preguntar. Sin esto, abrir la app en el metro deja la explicación en blanco aunque
    /// el número salga.
    func loQueHayGuardado(horizonteMin: Int) async -> FactoresYExplicacion? {
        guard let guardado = try? await cache?.ultima(horizonteMin: horizonteMin),
            guardado.explicacion != nil || !guardado.factores.isEmpty
        else { return nil }
        return .deLoGuardado(guardado)
    }

    /// Cuánto se separan los dos números, cuando los dos partieron del mismo instante.
    ///
    /// Si cada camino partió de una lectura distinta, la diferencia no dice nada de la
    /// implementación y compararlos sería inventar un problema: devuelve `nil`.
    static func desacuerdo(
        propio: Proyeccion, delServidor: Double, tsBaseDelServidor: Date?
    ) -> Double? {
        guard let tsBaseDelServidor else { return nil }
        let separacion = abs(tsBaseDelServidor.timeIntervalSince(propio.base.ts))
        guard separacion <= ConfiguracionDominio.mismoInstanteBaseSeg else { return nil }

        let diferencia = abs(delServidor - propio.valorMgDl)
        guard diferencia > ConfiguracionDominio.desacuerdoQueSeRegistraMgDl else { return nil }
        return diferencia
    }

    /// El sobre de `/explain`. `nil` si no hay contribuciones que mandar: el servidor exige
    /// entre una y cinco, y un sobre que va a recibir un `400` es una explicación perdida.
    ///
    /// Lo que lleva y lo que no: **nada que identifique a la persona** (regla 3). El valor
    /// predicho que viaja es **el del teléfono**, porque la frase tiene que explicar el número
    /// que la pantalla enseña y no otro.
    static func sobre(
        proyeccion: Proyeccion,
        shap: [ContribucionRemota],
        umbralHipo: Double,
        umbralHiper: Double,
        cobG: Double,
        iobUI: Double,
        asistenteActivo: Bool
    ) -> ExplicacionPedida? {
        let cinco = Array(shap.prefix(ExplicacionPedida.contribucionesShap))
        guard !cinco.isEmpty else { return nil }

        let sobre = ExplicacionPedida(
            valorActual: proyeccion.base.mgDl,
            valorPredicho: proyeccion.valorMgDl,
            horizonteMin: proyeccion.horizonteMin,
            modo: .sensor,
            umbralHipo: umbralHipo,
            umbralHiper: umbralHiper,
            cobG: cobG,
            iobUI: iobUI,
            horaLocal: Calendar.current.component(.hour, from: proyeccion.base.ts),
            shap: cinco,
            asistenteActivo: asistenteActivo
        )
        return sobre.sirveParaMandar ? sobre : nil
    }
}
