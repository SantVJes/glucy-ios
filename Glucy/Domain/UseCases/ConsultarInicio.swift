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
    /// Si el sensor que la persona dijo tener está escribiendo. No es el modo.
    let estadoDelSensor: EstadoDelSensor
    /// Las predicciones a 30 y 60 minutos, o el motivo de que no haya. El motivo se enseña:
    /// un número ausente sin explicación se lee como una falla de la app.
    let proyeccion: Result<[Proyeccion], SinProyeccion>
    /// El umbral de hipoglucemia **del perfil**, el que estaba vigente al calcular. Va en el
    /// estado porque el aviso de RF-10 lo registra junto con la alerta: quien movió su umbral
    /// a 80 cambió qué cuenta como alerta, y sin guardarlo no se podría explicar después por
    /// qué se avisó de un 75 el martes y no el lunes.
    let umbralHipo: Double
}

/// Junta lo que la pantalla de inicio necesita y decide lo que hay que decidir: qué ventana
/// se enseña en cada modo y dónde se corta la línea. Así el ViewModel no decide nada.
///
/// **La predicción la calcula `CalcularPrediccion` y esto solo la coloca**: los puntos medidos
/// van en sus tramos y los predichos en un tramo aparte, marcados `.proyectada`, para que la
/// gráfica los dibuje punteados. Lo medido y lo predicho no se pueden parecer: una persona a
/// media noche tiene que distinguirlos sin leer la leyenda.
///
/// La ventana se estira hasta la predicción más lejana. Sin eso la línea punteada se calcula,
/// se dibuja fuera de la escala y no se ve: el peor de los dos fallos posibles, porque parece
/// que la app no predice.
nonisolated struct ConsultarInicio: Sendable {
    let lecturas: any RepositorioLecturas
    let modo: ConsultarModo
    let carbohidratosActivos: CalcularCarbohidratosActivos
    let insulinaActiva: CalcularInsulinaActiva
    /// Para saber si la persona dijo tener sensor. Sin él, el sensor cuenta como no
    /// configurado.
    var perfil: (any RepositorioPerfil)? = nil
    /// Opcional porque hay pantallas y pruebas que no necesitan predicción. Sin él no se
    /// inventa nada: se dice que no hay modelo.
    var predecir: CalcularPrediccion? = nil

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

        var tramos: [[PuntoGrafica]] = switch estadoModo.modo {
        case .sensor: TramosDeSerie.partir(puntos)
        // Un tramo por punto: con eso es imposible que la gráfica una dos pinchazos
        // separados por horas con una recta que nadie midió (RF-23).
        case .sinSensor: puntos.map { [$0] }
        }

        let proyeccion: Result<[Proyeccion], SinProyeccion>
        if let predecir {
            // `try?` y no `try`: que el modelo no cargue no puede tumbar la pantalla de
            // inicio. Se queda sin línea punteada y lo dice.
            proyeccion = (try? await predecir.ejecutar(modo: estadoModo.modo, ahora: ahora))
                ?? .failure(.sinModelo(detalle: "la consulta del modelo falló"))
        } else {
            proyeccion = .failure(.sinModelo(detalle: "no se configuró el predictor"))
        }

        var hasta = ahora
        if case let .success(proyecciones) = proyeccion, let primera = proyecciones.first {
            // El tramo punteado arranca en la lectura desde la que se predijo, no en el borde
            // derecho de la gráfica: así la línea sale del punto medido y se ve de dónde
            // viene. Va con `minutos: 0`, que es el id reservado para la base.
            tramos.append(
                [
                    PuntoGrafica.proyectado(
                        ts: primera.base.ts, mgDl: primera.base.mgDl, minutos: 0
                    )
                ] + proyecciones.map {
                    PuntoGrafica.proyectado(
                        ts: $0.objetivo, mgDl: $0.valorMgDl, minutos: $0.horizonteMin
                    )
                }
            )
            hasta = max(hasta, proyecciones.map(\.objetivo).max() ?? ahora)
        }

        // La última que entró por Salud, venga marcada como sensor o como HealthKit.
        let delSensor = [
            try await lecturas.ultima(origen: .sensor), try await lecturas.ultima(origen: .healthkit),
        ].compactMap { $0?.tsUtc }.max()
        let delPerfil = try? await perfil?.actual()
        let usaSensor = delPerfil?.usaSensor ?? false

        return EstadoInicio(
            modo: estadoModo.modo,
            antiguedadMin: ultima.map { ahora.timeIntervalSince($0.tsUtc) / 60 },
            ultima: ultima,
            tramos: tramos,
            ventana: desde...hasta,
            carbohidratosActivosG: try await carbohidratosActivos.ejecutar(ahora: ahora),
            insulinaActivaUI: try await insulinaActiva.ejecutar(ahora: ahora),
            puedeAlertarHipoglucemia: estadoModo.puedeAlertarHipoglucemia,
            estadoDelSensor: DecisionModo.estadoDelSensor(
                usaSensor: usaSensor, tsUltimaDelSensor: delSensor, ahora: ahora
            ),
            proyeccion: proyeccion,
            umbralHipo: delPerfil?.umbralHipo ?? ConfiguracionDominio.umbralHipoPorOmision
        )
    }
}
