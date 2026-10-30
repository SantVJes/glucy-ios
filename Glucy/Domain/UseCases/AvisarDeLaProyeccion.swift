import Foundation

/// Qué pasó cuando la app intentó avisar. Lo devuelve el caso de uso para que la pantalla
/// pueda decirlo en una línea, en lugar de que la persona espere una alerta que no va a llegar.
nonisolated enum ResultadoDelAviso: Sendable, Equatable {
    /// La alerta se emitió y el sistema la aceptó.
    case avisado(AlertaDato)
    /// Se registró la alerta, pero el sistema no la va a entregar porque no hay permiso.
    /// La pantalla lo dice; el registro queda para poder medir el tiempo de anticipación.
    case registradaSinPermiso(AlertaDato)
    /// No había nada que avisar.
    case nadaQueAvisar
    /// Modo sin sensor: **la app no puede anticipar una hipoglucemia** y no lo finge
    /// (RF-10b, regla 8, caso P-04).
    case sinSensorNoSeAnticipa
    /// Ya se avisó de esto hace poco y la estimación no empeoró.
    case yaSeAviso(AlertaDato)
}

/// El aviso de hipoglucemia prevista (RF-10).
///
/// Cuatro decisiones que conviene leer antes del código:
///
/// 1. **Solo avisa de glucosa baja prevista.** La alta prevista se ve en la pantalla y no
///    manda una notificación. No es un olvido: con una comida al día se dispararía casi
///    siempre, y el criterio de aceptación del modelo es una tasa de falsas alarmas ≤ 15 %
///    porque «un modelo que avisa de más se apaga solo». La hipoglucemia es el evento
///    central del producto; la hiperglucemia no es urgente de la misma manera.
/// 2. **Solo en modo sensor.** Sin serie continua no hay predicción, y por lo tanto no hay
///    alerta anticipada. La pantalla ya lo declara arriba, fijo y sin poder descartarse.
/// 3. **No se repite.** Se compara contra la última alerta de ese mismo horizonte: dentro de
///    la espera solo se vuelve a avisar si la estimación empeoró de verdad.
/// 4. **El texto se arma aquí, no en una vista.** Una notificación no tiene pantalla detrás,
///    y poniéndolo aquí la regla de que **ningún aviso da una instrucción de tratamiento**
///    (regla 7) se comprueba en una prueba unitaria en lugar de depender de que alguien lea
///    el código de la capa del sistema.
nonisolated struct AvisarDeLaProyeccion: Sendable {
    let alertas: any RepositorioAlertas
    let avisos: any ServicioAvisos

    /// - Parameter proyecciones: las que `CalcularPrediccion` devolvió, en orden de horizonte.
    /// - Parameter umbralHipo: el del perfil, que es el que se registra con la alerta: quien
    ///   mueve su umbral cambia qué cuenta como alerta, y sin guardarlo no se podría explicar
    ///   después por qué se avisó de un 75 el martes y no el lunes.
    func ejecutar(
        proyecciones: [Proyeccion],
        modo: ModoApp,
        umbralHipo: Double,
        ahora: Date = Date()
    ) async throws -> ResultadoDelAviso {
        guard modo == .sensor else { return .sinSensorNoSeAnticipa }

        // La más cercana de las que avisan de una baja: si la de 30 y la de 60 minutos avisan
        // las dos, la que importa es la primera, porque es la que deja menos tiempo.
        guard let baja = proyecciones.first(where: { $0.aviso == .bajaPrevista }) else {
            return .nadaQueAvisar
        }

        let anterior = try await alertas.ultima(horizonteMin: baja.horizonteMin)
        if let anterior,
            !Self.vuelveAAvisar(
                anterior: anterior, valorMgDl: baja.valorMgDl, ahora: ahora
            )
        {
            return .yaSeAviso(anterior)
        }

        let alerta = AlertaDato(
            tsUtc: ahora,
            valorMgDl: baja.valorMgDl,
            umbralMgDl: umbralHipo,
            horizonteMin: baja.horizonteMin,
            modo: modo
        )
        try await alertas.guardar(alerta)

        // El permiso se pide **con la alerta en la mano** y no al abrir la app por primera
        // vez: un permiso que se pide sin contexto se niega, y negado no se vuelve a
        // preguntar nunca.
        var permiso = await avisos.permiso()
        if permiso == .sinPreguntar {
            permiso = (try? await avisos.pedirPermiso()) == true ? .concedido : .negado
        }
        guard permiso == .concedido else { return .registradaSinPermiso(alerta) }

        do {
            try await avisos.entregar(Self.aviso(de: alerta, objetivo: baja.objetivo))
        } catch {
            // El registro se queda. La alerta existió, y que el sistema no la haya entregado
            // es exactamente lo que hay que poder ver después.
            return .registradaSinPermiso(alerta)
        }
        try await alertas.marcarEntregada(uuid: alerta.uuid)
        return .avisado(alerta)
    }

    /// Si hay que volver a avisar, habiendo avisado antes.
    ///
    /// Pasada la espera, sí. Dentro de la espera, solo si la estimación empeoró más que el
    /// error del propio modelo: pasar de «vas a 68» a «vas a 50» es información nueva, pasar
    /// de 68 a 66 no lo es.
    static func vuelveAAvisar(anterior: AlertaDato, valorMgDl: Double, ahora: Date) -> Bool {
        let minutos = ahora.timeIntervalSince(anterior.tsUtc) / 60
        if minutos >= ConfiguracionDominio.esperaEntreAvisosMin { return true }
        return anterior.valorMgDl - valorMgDl
            >= ConfiguracionDominio.empeoraParaVolverAAvisarMgDl
    }

    /// El texto del aviso.
    ///
    /// Lo que lleva y lo que no: la cifra con su unidad, la hora a la que apunta, y que es una
    /// estimación que conviene confirmar midiendo. **Ninguna indicación de tratamiento**: no
    /// dice cuántos gramos tomar, ni que se tome algo, ni que se ajuste nada (regla 7). Medir
    /// no es tratarse, y es lo único que la app puede pedir.
    static func aviso(de alerta: AlertaDato, objetivo: Date) -> AvisoParaEntregar {
        AvisoParaEntregar(
            identificador: alerta.uuid.uuidString,
            titulo: "Puede que bajes",
            cuerpo: "Alrededor de \(Int(alerta.valorMgDl.rounded())) mg/dL a las "
                + "\(hora(objetivo)). Es una estimación; conviene medirte para confirmarla.",
            vibra: true
        )
    }

    /// La hora, como la lee la persona. En la zona del teléfono, que es donde está leyendo.
    static func hora(_ fecha: Date) -> String {
        fecha.formatted(date: .omitted, time: .shortened)
    }
}
