import Foundation

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

    private let consultar: ConsultarInicio
    private let sincronizar: SincronizarLecturasDelSensor
    private let ajustes: ConsultarAjustesDeInsulina

    init(
        consultar: ConsultarInicio,
        sincronizar: SincronizarLecturasDelSensor,
        ajustes: ConsultarAjustesDeInsulina
    ) {
        self.consultar = consultar
        self.sincronizar = sincronizar
        self.ajustes = ajustes
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
        }
    }

    // MARK: - Lo que la pantalla pregunta

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
        return "\(Self.entero(ultima.mgDl)) miligramos por decilitro. \(letrero)"
    }

    var pieDeLaGrafica: String {
        switch estado?.modo {
        case .sensor: "Aún no puedo proyectar: eso llega cuando el modelo esté entrenado."
        case .sinSensor, nil: "Cada punto es una medición tuya. Sin serie continua no hay curva que dibujar."
        }
    }

    var textoSinPuntos: String {
        "No tienes mediciones en los últimos \(Int(ConfiguracionDominio.ventanaInicioSinSensorDias)) días."
    }

    /// Una frase con cada cifra y su unidad. Describe lo que hay, sin interpretar hacia
    /// dónde va: decir «subiendo» ya sería empezar a proyectar.
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
        return "\(periodo): \(cuantas), de \(Self.entero(minimo)) a \(Self.entero(maximo)) "
            + "miligramos por decilitro. La más reciente, \(Self.entero(ultimo.mgDl))."
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
}
