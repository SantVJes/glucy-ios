import Foundation

/// El estado del sensor que Inicio dibuja. Distinto del modo: «no tengo sensor» y «mi sensor
/// no escribe desde las 8:05» no son lo mismo, y solo la segunda tiene algo que hacer.
nonisolated enum EstadoDelSensor: Sendable, Equatable {
    /// El perfil no usa sensor. No hay nada que avisar: quien no tiene sensor no tiene un
    /// sensor roto.
    case noConfigurado
    case alDia
    /// Con sensor configurado y la última lectura más vieja que la frescura. `desde` es
    /// `nil` cuando todavía no ha llegado ninguna.
    case sinDatos(desde: Date?)
}

/// La regla que evita predecir con datos rancios (RF-06c).
nonisolated enum DecisionModo {

    /// Modo en el que la app tiene derecho a estar.
    ///
    /// `sensor` solo si HealthKit está entregando lecturas y la última muestra de origen
    /// sensor tiene menos de 15 minutos. En cualquier otro caso `sinSensor`, y la pantalla
    /// lo dice: degradar y declararlo es mejor que seguir proyectando con datos viejos
    /// (caso P-03).
    ///
    /// Revocar el permiso desde Salud llega aquí como `lecturaHealthKitActiva == false`;
    /// la app no se cae, cambia de modo (RF-07, caso P-09).
    static func modoActual(
        lecturaHealthKitActiva: Bool,
        tsUltimaSensor: Date?,
        ahora: Date,
        frescuraMin: Double = ConfiguracionDominio.frescuraSensorMin
    ) -> ModoApp {
        guard lecturaHealthKitActiva, let tsUltimaSensor else { return .sinSensor }
        let antiguedadMin = ahora.timeIntervalSince(tsUltimaSensor) / 60
        return antiguedadMin <= frescuraMin ? .sensor : .sinSensor
    }

    /// Si el sensor que la persona dijo tener está escribiendo.
    ///
    /// El umbral es `frescuraSensorMin`, **el mismo** que decide el modo: dos números para
    /// la misma idea terminan divergiendo.
    ///
    /// - Parameter tsUltimaDelSensor: la última lectura que entró por Salud. Un pinchazo
    ///   reciente no cuenta: no prueba que el sensor escriba.
    static func estadoDelSensor(
        usaSensor: Bool,
        tsUltimaDelSensor: Date?,
        ahora: Date,
        frescuraMin: Double = ConfiguracionDominio.frescuraSensorMin
    ) -> EstadoDelSensor {
        guard usaSensor else { return .noConfigurado }
        guard let tsUltimaDelSensor else { return .sinDatos(desde: nil) }
        let antiguedadMin = ahora.timeIntervalSince(tsUltimaDelSensor) / 60
        return antiguedadMin <= frescuraMin ? .alDia : .sinDatos(desde: tsUltimaDelSensor)
    }

    /// En modo sin sensor la app **no** puede anticipar hipoglucemias y tiene que decirlo
    /// (RF-10b, riesgo R-6, caso P-04). Un sistema que promete una alerta que no puede dar
    /// es peor que uno que no la promete.
    static func puedeAlertarHipoglucemia(modo: ModoApp) -> Bool {
        modo == .sensor
    }
}
