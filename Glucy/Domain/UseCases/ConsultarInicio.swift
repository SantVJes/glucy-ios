import Foundation

/// Todo lo que la pantalla de inicio dibuja, ya resuelto.
nonisolated struct EstadoInicio: Sendable, Equatable {
    let modo: ModoApp
    /// Minutos desde la última lectura. `nil` si nunca hubo una. No se inventa un cero: en
    /// pantalla se leería como «recién medido» (RF-06c).
    let antiguedadMin: Double?
    let ultima: LecturaGlucosaDato?
    /// Ya partida en tramos: cada tramo es una línea continua y entre tramos hay un hueco
    /// de más de `interpolacionMaximaMin`. En modo sin sensor viene un tramo por punto.
    let tramos: [[PuntoGrafica]]
    /// El intervalo de tiempo que cubre la gráfica: tres horas con sensor, siete días sin él.
    let ventana: ClosedRange<Date>
    let carbohidratosActivosG: Double
    let insulinaActivaUI: Double
    /// Si la app puede anticipar una hipoglucemia. En modo sin sensor es `false` y la
    /// pantalla lo declara (RF-10b).
    let puedeAlertarHipoglucemia: Bool
}

/// Junta lo que la pantalla de inicio necesita y decide lo que hay que decidir: qué ventana
/// se enseña en cada modo y dónde se corta la línea. Así el ViewModel no decide nada.
///
/// **No produce ninguna predicción.** Todos los puntos que devuelve son `.medida`: en la
/// fase 1 no hay modelo, y una proyección sin modelo sería una extrapolación inventada con
/// apariencia de predicción (RF-10).
nonisolated struct ConsultarInicio: Sendable {
    let lecturas: any RepositorioLecturas
    let modo: ConsultarModo
    let carbohidratosActivos: CalcularCarbohidratosActivos
    let insulinaActiva: CalcularInsulinaActiva

    /// - Parameter lecturaHealthKitActiva: si la última consulta a Salud respondió. Ver
    ///   `ConsultarModo`.
    /// - Parameter ahora: se pasa, no se toma de `Date()` dentro, para poder probarlo.
    func ejecutar(lecturaHealthKitActiva: Bool, ahora: Date = Date()) async throws -> EstadoInicio {
        let estadoModo = try await modo.ejecutar(
            lecturaHealthKitActiva: lecturaHealthKitActiva, ahora: ahora
        )
        let ultima = try await lecturas.ultima()

        let segundos: TimeInterval = switch estadoModo.modo {
        case .sensor: ConfiguracionDominio.ventanaInicioSensorH * 3600
        case .sinSensor: ConfiguracionDominio.ventanaInicioSinSensorDias * 86_400
        }
        let desde = ahora.addingTimeInterval(-segundos)

        // Solo lo que se midió. Si la glucosa sube y no hay comida registrada, la gráfica
        // sube y no hay comida registrada: no se deduce nada de la forma de la curva
        // (RF-37, D-9, caso P-12).
        let puntos = try await lecturas.entre(desde: desde, hasta: ahora).map {
            PuntoGrafica(id: $0.uuid, ts: $0.tsUtc, mgDl: $0.mgDl, serie: .medida, origen: $0.origen)
        }

        let tramos: [[PuntoGrafica]] = switch estadoModo.modo {
        case .sensor: TramosDeSerie.partir(puntos)
        // Un tramo por punto: con eso es imposible que la gráfica una dos pinchazos
        // separados por horas con una recta que nadie midió (RF-23).
        case .sinSensor: puntos.map { [$0] }
        }

        return EstadoInicio(
            modo: estadoModo.modo,
            antiguedadMin: ultima.map { ahora.timeIntervalSince($0.tsUtc) / 60 },
            ultima: ultima,
            tramos: tramos,
            ventana: desde...ahora,
            carbohidratosActivosG: try await carbohidratosActivos.ejecutar(ahora: ahora),
            insulinaActivaUI: try await insulinaActiva.ejecutar(ahora: ahora),
            puedeAlertarHipoglucemia: estadoModo.puedeAlertarHipoglucemia
        )
    }
}
