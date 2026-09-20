import Foundation

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

    /// En modo sin sensor la app **no** puede anticipar hipoglucemias y tiene que decirlo
    /// (RF-10b, riesgo R-6, caso P-04). Un sistema que promete una alerta que no puede dar
    /// es peor que uno que no la promete.
    static func puedeAlertarHipoglucemia(modo: ModoApp) -> Bool {
        modo == .sensor
    }
}
