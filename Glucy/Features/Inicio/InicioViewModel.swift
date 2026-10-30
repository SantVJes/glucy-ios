import Foundation

/// Un aviso listo para dibujarse: la frase y, aparte, qué clase de aviso es.
nonisolated struct AvisoEnPantalla: Sendable, Equatable {
    let tipo: AvisoPrevisto
    let texto: String
}

/// El estado de la pantalla de inicio.
///
/// **No decide nada**: el modo, la ventana de la gráfica y dónde se corta la línea vienen ya
/// resueltos de `ConsultarInicio`. Aquí solo se pide, se guarda y se le da forma de texto.
@Observable
final class InicioViewModel {

    /// `nil` hasta la primera respuesta. Después nunca vuelve a `nil`: si una consulta
    /// falla se queda la anterior, porque la pantalla no se vacía para volver a llenarse.
    private(set) var estado: EstadoInicio?
    /// Si ya terminó la primera consulta, con respuesta o sin ella.
    private(set) var cargado = false
    /// `true` solo cuando una consulta tarda lo bastante como para notarse. Una que
    /// responde en milisegundos no tiene por qué hacer parpadear el valor cada minuto.
    private(set) var actualizando = false
    /// Arranca en `false`: a quien ocultó la insulina no se le dibuja ni un instante (RF-14).
    private(set) var registraInsulina = false
    /// Cuánto tardó el valor en estar listo desde el lanzamiento. Solo se llena cuando la
    /// prueba del arranque lo pide; en la app de todos los días es siempre `nil`.
    private(set) var segundosHastaElValor: Double?

    /// Lo que el servidor aportó sobre la primera predicción: los factores y la frase.
    /// Empieza con lo que quedó guardado la última vez y se reemplaza si llega algo nuevo.
    private(set) var delServidor: FactoresYExplicacion?
    /// Qué pasó con el último aviso. `nil` mientras no haya habido ninguno.
    private(set) var resultadoDelAviso: ResultadoDelAviso?

    private let consultar: ConsultarInicio
    private let sincronizar: SincronizarLecturasDelSensor
    private let ajustes: ConsultarAjustesDeInsulina
    /// `nil` en las pruebas que no miran la explicación.
    private let pedirAlServidor: PedirFactoresYExplicacion?
    /// La petición en vuelo. Se cancela antes de empezar otra: la pantalla se recalcula cada
    /// minuto y `POST /explain` tarda hasta tres segundos, así que dos pasadas seguidas
    /// podrían dejar llegando la respuesta de la vieja después de la nueva.
    private var tareaDelServidor: Task<Void, Never>?
    /// `nil` en las pruebas que no miran el aviso, y entonces no se avisa nada.
    private let avisar: AvisarDeLaProyeccion?

    init(
        consultar: ConsultarInicio,
        sincronizar: SincronizarLecturasDelSensor,
        ajustes: ConsultarAjustesDeInsulina,
        pedirAlServidor: PedirFactoresYExplicacion? = nil,
        avisar: AvisarDeLaProyeccion? = nil
    ) {
        self.consultar = consultar
        self.sincronizar = sincronizar
        self.ajustes = ajustes
        self.pedirAlServidor = pedirAlServidor
        self.avisar = avisar
    }

    func ponerAlDia(ahora: Date = Date()) async {
        let aviso = Task {
            try? await Task.sleep(for: .milliseconds(400))
            if !Task.isCancelled { actualizando = true }
        }
        defer {
            aviso.cancel()
            actualizando = false
            cargado = true
        }

        registraInsulina = await ajustes.registraInsulina()
        // La pasada trae lo nuevo del sensor y, sobre todo, dice si Salud respondió: de
        // eso depende el modo (RF-06c, RF-07).
        let pasada = await sincronizar.ejecutar(ahora: ahora)
        if let nuevo = try? await consultar.ejecutar(
            lecturaHealthKitActiva: pasada.saludRespondio, ahora: ahora
        ) {
            estado = nuevo
            anotarElArranque()
            // Los factores y la frase arrancan primero porque no bloquean: se van a una
            // tarea. El aviso va después, que es el que puede abrir un diálogo.
            pedirLoDelServidor(nuevo)
            await avisarSiHaceFalta(nuevo, ahora: ahora)
        }
    }

    /// Los factores y la frase, **en segundo plano y sin bloquear nada**.
    ///
    /// `GET /predict` contesta en menos de 200 ms, pero `POST /explain` tarda de uno a tres
    /// segundos: la cifra de la pantalla no puede esperarlos. Lo guardado se pinta de
    /// inmediato, y lo que llegue lo reemplaza.
    private func pedirLoDelServidor(_ estado: EstadoInicio) {
        guard let pedirAlServidor,
            case let .success(proyecciones) = estado.proyeccion,
            let primera = proyecciones.first
        else { return }

        tareaDelServidor?.cancel()
        tareaDelServidor = Task { [weak self] in
            let guardado = await pedirAlServidor.loQueHayGuardado(
                horizonteMin: primera.horizonteMin
            )
            guard !Task.isCancelled else { return }
            if let guardado, self?.delServidor == nil { self?.delServidor = guardado }

            let resultado = await pedirAlServidor.ejecutar(
                proyecciones: proyecciones,
                modo: estado.modo,
                umbralHipo: estado.umbralHipo,
                umbralHiper: estado.umbralHiper,
                cobG: estado.carbohidratosActivosG,
                iobUI: estado.insulinaActivaUI,
                asistenteActivo: estado.asistenteActivo
            )
            guard !Task.isCancelled else { return }
            if case let .llego(aportes) = resultado, let aporte = aportes.first {
                self?.delServidor = aporte
            }
        }
    }

    /// La frase en español llano, cuando hay. En inicio sale una sola línea: lo demás está en
    /// la pantalla de factores, a un toque.
    var fraseDeLaExplicacion: String? { delServidor?.explicacion }

    /// Si vale la pena ofrecer la pantalla de factores. Sin factores que enseñar no se ofrece
    /// un toque que lleva a una pantalla vacía.
    var hayFactoresQueVer: Bool { !(delServidor?.paraLaPantalla.isEmpty ?? true) }

    /// Lo que la pantalla de factores necesita, ya reunido.
    func modeloDeLosFactores() -> FactoresViewModel {
        var primera: Proyeccion?
        if case let .success(proyecciones) = estado?.proyeccion {
            primera = proyecciones.first
        }
        return FactoresViewModel(
            aporte: delServidor,
            valorPropioMgDl: primera?.valorMgDl,
            objetivo: primera?.objetivo
        )
    }

    /// El aviso sale **después** de que la pantalla ya tiene el estado, a propósito: si hay
    /// que pedir el permiso del sistema, el diálogo no retrasa la cifra que la persona abrió
    /// la app para ver.
    private func avisarSiHaceFalta(_ estado: EstadoInicio, ahora: Date) async {
        guard let avisar, case let .success(proyecciones) = estado.proyeccion else { return }
        resultadoDelAviso = try? await avisar.ejecutar(
            proyecciones: proyecciones,
            modo: estado.modo,
            umbralHipo: estado.umbralHipo,
            ahora: ahora
        )
    }

    /// La línea que se enseña cuando la app vio venir una baja y el sistema no va a entregar
    /// el aviso. Se dice en lugar de dejar a la persona esperando una alerta que no va a
    /// llegar; no lleva ninguna indicación de tratamiento (regla 7).
    var avisoQueNoVaASalir: String? {
        guard case .some(.registradaSinPermiso) = resultadoDelAviso else { return nil }
        return "Esta app no tiene permiso para avisarte. Puedes dárselo en Ajustes del "
            + "iPhone, en Notificaciones."
    }

    private func anotarElArranque() {
        #if DEBUG
        guard MedicionDeArranque.activa, segundosHastaElValor == nil, estado?.ultima != nil else { return }
        segundosHastaElValor = MedicionDeArranque.segundosDesdeElLanzamiento()
        #endif
    }

    // MARK: - Lo que la pantalla pregunta

    /// La franja del sensor. Solo sale para quien dijo tener sensor y lleva un rato sin
    /// recibir nada; quien no lo tiene no la ve nunca.
    ///
    /// Dice la hora de la última lectura y no «hace 40 minutos»: la hora se puede cruzar con
    /// lo que la persona estaba haciendo. Y no habla de conexión, porque no hay ninguna en
    /// juego: es la app del fabricante la que dejó de escribir en Salud.
    var textoSinDatosDelSensor: String? {
        guard case let .sinDatos(desde) = estado?.estadoDelSensor else { return nil }
        guard let desde else {
            return "Todavía no llegan datos de tu sensor. Revisa que la app de tu sensor esté abierta."
        }
        let hora = desde.formatted(date: .omitted, time: .shortened)
        return "Sin datos de tu sensor desde las \(hora). Revisa que la app de tu sensor esté abierta."
    }

    /// Mientras no se sepa con certeza que el modo es sensor, el aviso está. El único
    /// estado que lo quita es el que sí puede alertar (RF-10b, caso P-04).
    var mostrarAvisoSinSensor: Bool {
        estado?.puedeAlertarHipoglucemia != true
    }

    /// El primer día: ya se consultó y no hay ninguna lectura.
    var sinLecturas: Bool {
        cargado && estado != nil && estado?.ultima == nil
    }

    /// Se consultó y la base no respondió, sin nada anterior que enseñar.
    var sinRespuesta: Bool {
        cargado && estado == nil
    }

    var contenidoDeLaGrafica: ContenidoGrafica? {
        guard let estado, !estado.tramos.isEmpty else { return nil }
        return .serie(
            tramos: estado.tramos, unirConLinea: estado.modo == .sensor, ventana: estado.ventana
        )
    }

    // MARK: - Textos

    var textoValor: String? {
        estado?.ultima.map { Self.entero($0.mgDl) }
    }

    /// «Con sensor · hace 2 min» o «Sin sensor · última medición hace 3 h».
    var letreroDelModo: String {
        Self.letrero(modo: estado?.modo ?? .sinSensor, antiguedadMin: estado?.antiguedadMin, hablado: false)
    }

    var valorHablado: String? {
        guard let estado, let ultima = estado.ultima else { return nil }
        let letrero = Self.letrero(modo: estado.modo, antiguedadMin: estado.antiguedadMin, hablado: true)
        // La estimación va aquí también, no solo en el resumen de la gráfica: va dibujada
        // dentro de este bloque, y el bloque se lee con una sola etiqueta. Sin esto, quien usa
        // VoiceOver no se enteraría de la cifra que la pantalla enseña más grande después del
        // valor de ahora.
        let estimado = primeraProyeccion.map {
            " Estimado: \(Self.entero($0.valorMgDl)) miligramos por decilitro "
                + "a las \(Self.hora($0.objetivo))."
        } ?? ""
        return "\(Self.entero(ultima.mgDl)) miligramos por decilitro. \(letrero)\(estimado)"
    }

    /// La del horizonte más corto, que es la que la pantalla enseña arriba.
    private var primeraProyeccion: Proyeccion? {
        guard case let .success(proyecciones) = estado?.proyeccion else { return nil }
        return proyecciones.min(by: { $0.horizonteMin < $1.horizonteMin })
    }

    var pieDeLaGrafica: String {
        switch estado?.modo {
        case .sensor: Self.pieConSensor(estado?.proyeccion)
        case .sinSensor, nil:
            "Cada punto es una medición tuya. Sin serie continua no hay curva que dibujar."
        }
    }

    /// «La línea punteada es una estimación: alrededor de 142 mg/dL a las 2:35 p.m. …»
    ///
    /// Siempre con **la hora** y nunca con «dentro de media hora»: el horizonte se cuenta
    /// desde la lectura con la que se predijo, y si esa lectura tiene doce minutos, media hora
    /// alcanza a dieciocho. Y siempre cerrando con que conviene medirse, que es lo único que
    /// se puede decir sin dar una indicación de tratamiento (regla 7).
    static func pieConSensor(_ proyeccion: Result<[Proyeccion], SinProyeccion>?) -> String {
        guard let proyeccion else { return "" }
        switch proyeccion {
        case let .success(proyecciones) where !proyecciones.isEmpty:
            let valores = proyecciones.map {
                "\(entero($0.valorMgDl)) mg/dL a las \(hora($0.objetivo))"
            }
            return "La línea punteada es una estimación: alrededor de "
                + valores.joined(separator: ", y de ")
                + ". Conviene medirte para confirmarlo."
        case .success:
            return "No tengo con qué estimar todavía."
        case .failure(.sinSensor):
            // No debería llegar aquí —esto solo se llama en modo sensor— y si llega, lo que
            // toca decir es lo que la regla 8 obliga a decir.
            return "Sin sensor no puedo anticipar una glucosa baja."
        case .failure(.serieInsuficiente):
            return "Todavía no tengo suficientes lecturas seguidas para estimar."
        case .failure(.sinModelo):
            return "No puedo estimar ahora mismo. Tus registros y tus gráficas siguen igual."
        case let .failure(.fueraDeRango(valor)):
            // Se dice el número en lugar de callarlo: es un síntoma, y quien lo vea en una
            // prueba de campo tiene que poder reportarlo.
            return "La estimación salió fuera de lo posible (\(entero(valor)) mg/dL), "
                + "así que no la enseño."
        }
    }

    /// Lo que la estimación anticipa, con su tipo aparte del texto.
    ///
    /// El tipo va suelto porque la pantalla elige con él el icono y el color; deducirlo del
    /// texto obligaría a leer la primera palabra, y entonces cambiar una frase cambiaría una
    /// flecha sin que nadie lo note.
    ///
    /// La frase nombra lo que va a pasar y **no qué hacer** (regla 7). Lo único que pide es
    /// medirse, que es una medición y no un tratamiento.
    var avisoDeLaProyeccion: AvisoEnPantalla? {
        guard case let .success(proyecciones) = estado?.proyeccion,
              let primera = proyecciones.first(where: { $0.aviso != nil }),
              let aviso = primera.aviso
        else { return nil }
        let que = aviso == .bajaPrevista ? "Baja prevista" : "Alta prevista"
        return AvisoEnPantalla(
            tipo: aviso,
            texto: "\(que) a las \(Self.hora(primera.objetivo)): alrededor de "
                + "\(Self.entero(primera.valorMgDl)) mg/dL. Mídete para confirmarlo."
        )
    }

    /// La cifra de dentro de media hora, debajo de la de ahora: «→ 142 mg/dL a las 2:35 p.m.»
    ///
    /// Es la promesa del eslogan, «tu glucosa, media hora antes», y es lo único que la pantalla
    /// enseña grande además del valor de ahora: un dato y una acción por pantalla. La flecha va
    /// porque el color no puede ser lo único que distinga lo estimado de lo medido.
    ///
    /// Con la hora, no con «en 30 minutos»: el horizonte se cuenta desde la lectura con la que
    /// se predijo.
    var cifraDeLaProyeccion: String? {
        primeraProyeccion.map {
            "\(Self.entero($0.valorMgDl)) mg/dL a las \(Self.hora($0.objetivo))"
        }
    }

    /// Lo mismo que el pie, para VoiceOver: con la unidad dicha entera y sin abreviar la hora.
    var proyeccionHablada: String? {
        guard case let .success(proyecciones) = estado?.proyeccion, !proyecciones.isEmpty
        else { return nil }
        let dichas = proyecciones.map {
            "\(Self.entero($0.valorMgDl)) miligramos por decilitro a las \(Self.hora($0.objetivo))"
        }
        return "Estimación: alrededor de " + dichas.joined(separator: ", y de ")
            + ". Conviene medirte para confirmarlo."
    }

    /// Con qué versión del modelo se calculó, para la pantalla de ajustes y para el reporte
    /// (RF-25). No se enseña en Inicio: ahí no significa nada para quien usa la app.
    var versionDelModelo: String? {
        guard case let .success(proyecciones) = estado?.proyeccion else { return nil }
        return proyecciones.first?.versionModelo
    }

    var textoSinPuntos: String {
        "No tienes mediciones en los últimos \(Int(ConfiguracionDominio.ventanaInicioSinSensorDias)) días."
    }

    /// Una frase con cada cifra y su unidad, y después la estimación si la hay.
    ///
    /// Lo medido y lo estimado van en frases separadas y la estimación se nombra como tal: la
    /// gráfica distingue las dos series con el trazo, y quien la escucha necesita que algo haga
    /// ese papel. Lo medido no se interpreta —decir «subiendo» sería proyectar sin modelo—; lo
    /// estimado sale del modelo y se dice con su hora.
    var resumenDeLaGrafica: String {
        guard let estado else { return "" }
        let valores = estado.tramos.flatMap { $0 }.map(\.mgDl)
        guard let minimo = valores.min(), let maximo = valores.max(),
              let ultimo = estado.tramos.last?.last else { return textoSinPuntos }

        let periodo = switch estado.modo {
        case .sensor: "Tu glucosa de las últimas \(Int(ConfiguracionDominio.ventanaInicioSensorH)) horas"
        case .sinSensor: "Tus mediciones de los últimos \(Int(ConfiguracionDominio.ventanaInicioSinSensorDias)) días"
        }
        let cuantas = valores.count == 1 ? "1 medición" : "\(valores.count) mediciones"
        let medido = "\(periodo): \(cuantas), de \(Self.entero(minimo)) a "
            + "\(Self.entero(maximo)) miligramos por decilitro. "
            + "La más reciente, \(Self.entero(ultimo.mgDl))."
        return [medido, proyeccionHablada].compactMap { $0 }.joined(separator: " ")
    }

    var textoCarbohidratos: String {
        Self.entero(estado?.carbohidratosActivosG ?? 0)
    }

    /// Una cifra y nada más: no se compara contra nada ni va seguida de un consejo (regla 7).
    var textoInsulina: String {
        String(format: "%.1f", estado?.insulinaActivaUI ?? 0)
    }

    // MARK: - Formato

    static func letrero(modo: ModoApp, antiguedadMin: Double?, hablado: Bool) -> String {
        let antiguedad = antiguedadMin.map { textoAntiguedad(minutos: $0, hablado: hablado) }
        let separador = hablado ? ", " : " · "
        switch (modo, antiguedad) {
        case let (.sensor, antiguedad?): return "Con sensor\(separador)\(antiguedad)"
        case (.sensor, nil): return "Con sensor"
        case let (.sinSensor, antiguedad?): return "Sin sensor\(separador)última medición \(antiguedad)"
        case (.sinSensor, nil): return "Sin sensor"
        }
    }

    /// «hace 2 min», «hace 3 h», «hace 4 días». Siempre hacia abajo: una lectura de hace
    /// 59 minutos no es de «hace 1 h».
    static func textoAntiguedad(minutos: Double, hablado: Bool = false) -> String {
        let minutosEnteros = Int(max(minutos, 0))
        guard minutosEnteros >= 1 else { return "hace un momento" }
        if minutosEnteros < 60 {
            let unidad = hablado ? (minutosEnteros == 1 ? "minuto" : "minutos") : "min"
            return "hace \(minutosEnteros) \(unidad)"
        }
        let horas = minutosEnteros / 60
        if horas < 48 {
            let unidad = hablado ? (horas == 1 ? "hora" : "horas") : "h"
            return "hace \(horas) \(unidad)"
        }
        return "hace \(horas / 24) días"
    }

    static func entero(_ valor: Double) -> String {
        String(Int(valor.rounded()))
    }

    /// La hora en el formato corto del sistema, que respeta si la persona usa 12 o 24 horas.
    static func hora(_ instante: Date) -> String {
        instante.formatted(date: .omitted, time: .shortened)
    }
}
