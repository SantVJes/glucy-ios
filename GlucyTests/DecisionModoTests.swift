import Foundation
import Testing
@testable import Glucy

/// La regla que evita predecir con datos rancios (RF-06c).
struct DecisionModoTests {

    private let ahora = Date(timeIntervalSince1970: 1_758_240_000)

    /// P-03. A los 16 minutos ya no se predice: se degrada y se dice en pantalla.
    @Test("P-03: una lectura vieja degrada a modo sin sensor")
    func P03_lecturaViejaDegradaAModoSinSensor() {
        #expect(DecisionModo.modoActual(
            lecturaHealthKitActiva: true,
            tsUltimaSensor: ahora.addingTimeInterval(-16 * 60),
            ahora: ahora
        ) == .sinSensor)

        #expect(DecisionModo.modoActual(
            lecturaHealthKitActiva: true,
            tsUltimaSensor: ahora.addingTimeInterval(-14 * 60),
            ahora: ahora
        ) == .sensor)

        // Los 15 minutos exactos todavía son frescos.
        #expect(DecisionModo.modoActual(
            lecturaHealthKitActiva: true,
            tsUltimaSensor: ahora.addingTimeInterval(-15 * 60),
            ahora: ahora
        ) == .sensor)
    }

    /// P-09. Revocar el permiso desde Salud llega aquí como HealthKit inactivo.
    @Test("Sin HealthKit activo, o sin ninguna lectura, el modo es sin sensor")
    func sinHealthKitOSinLecturaEsSinSensor() {
        #expect(DecisionModo.modoActual(
            lecturaHealthKitActiva: false,
            tsUltimaSensor: ahora,
            ahora: ahora
        ) == .sinSensor)

        #expect(DecisionModo.modoActual(
            lecturaHealthKitActiva: true,
            tsUltimaSensor: nil,
            ahora: ahora
        ) == .sinSensor)
    }

    /// P-04. Un sistema que promete una alerta que no puede dar es peor que uno que no la
    /// promete (RF-10b, riesgo R-6).
    @Test("P-04: en modo sin sensor no hay alerta anticipada")
    func P04_sinSensorNoHayAlertaAnticipada() {
        #expect(DecisionModo.puedeAlertarHipoglucemia(modo: .sinSensor) == false)
        #expect(DecisionModo.puedeAlertarHipoglucemia(modo: .sensor))
    }
}
