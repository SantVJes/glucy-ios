import Foundation

/// El modo en el que la app tiene derecho a estar, con lo que la pantalla de inicio va a
/// necesitar para decirlo en el paso 8.
nonisolated struct EstadoModo: Sendable, Equatable {
    let modo: ModoApp
    /// Minutos desde la última lectura del sensor. `nil` si nunca hubo una: no se inventa
    /// un cero, que en pantalla se leería como «recién medido».
    let antiguedadMin: Double?

    /// En modo sin sensor la app no puede anticipar hipoglucemias y lo tiene que declarar
    /// (RF-10b, caso P-04). Se expone aquí para que nadie lo recalcule por su cuenta.
    var puedeAlertarHipoglucemia: Bool {
        DecisionModo.puedeAlertarHipoglucemia(modo: modo)
    }
}

/// Junta la frescura de la última lectura del sensor con si HealthKit está respondiendo, y
/// se lo pasa a `DecisionModo`, que es quien decide (RF-06c).
nonisolated struct ConsultarModo: Sendable {
    let lecturas: any RepositorioLecturas

    /// `lecturaHealthKitActiva` no es un estado de autorización: iOS no dice si hay permiso
    /// de lectura, porque decirlo ya sería un dato de salud. Es «la última consulta a Salud
    /// respondió». Si no respondió, da igual por qué: el modo es sin sensor. Así la
    /// revocación del permiso llega por el mismo camino que un sensor apagado (RF-07, P-09).
    ///
    /// La antigüedad es la de la última lectura de origen **sensor**, no la de cualquiera:
    /// un pinchazo de hace dos minutos no vuelve fresca una serie que dejó de llegar.
    func ejecutar(lecturaHealthKitActiva: Bool, ahora: Date = Date()) async throws -> EstadoModo {
        let ultima = try await lecturas.ultima(origen: .sensor)
        let modo = DecisionModo.modoActual(
            lecturaHealthKitActiva: lecturaHealthKitActiva,
            tsUltimaSensor: ultima?.tsUtc,
            ahora: ahora
        )
        return EstadoModo(
            modo: modo,
            antiguedadMin: ultima.map { ahora.timeIntervalSince($0.tsUtc) / 60 }
        )
    }
}
