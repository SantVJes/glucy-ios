import Foundation
import Testing
@testable import Glucy

/// El modo que el paso 8 va a dibujar. Quien decide es `DecisionModo`, del paso 1; aquí se
/// comprueba que se le dan los datos correctos.
struct ConsultarModoTests {

    private let ahora = Date(timeIntervalSince1970: 1_758_240_000)

    private func repositorioConSensor(haceMin: Double) async throws -> RepositorioLecturasFalso {
        let repositorio = RepositorioLecturasFalso()
        try await repositorio.guardar(LecturaGlucosaDato(
            mgDl: 120, tsUtc: ahora.addingTimeInterval(-haceMin * 60), origen: .sensor
        ))
        return repositorio
    }

    /// Prueba 10 · RF-06c — cinco minutos es fresco.
    @Test("10 · RF-06c: con la última muestra de hace 5 min el modo es sensor")
    func cincoMinutosEsSensor() async throws {
        let repositorio = try await repositorioConSensor(haceMin: 5)

        let estado = try await ConsultarModo(lecturas: repositorio)
            .ejecutar(lecturaHealthKitActiva: true, ahora: ahora)

        #expect(estado.modo == .sensor)
        #expect(estado.antiguedadMin == 5)
    }

    /// Prueba 11 · **P-03**, D-13 — a los 20 minutos ya no se predice con eso.
    @Test("11 · P-03: con la última muestra de hace 20 min el modo es sin sensor")
    func veinteMinutosEsSinSensor() async throws {
        let repositorio = try await repositorioConSensor(haceMin: 20)

        let estado = try await ConsultarModo(lecturas: repositorio)
            .ejecutar(lecturaHealthKitActiva: true, ahora: ahora)

        #expect(estado.modo == .sinSensor)
        #expect(estado.antiguedadMin == 20)
    }

    /// Prueba 12 — sin ninguna lectura del sensor la antigüedad es `nil`, no cero: un cero
    /// en pantalla se leería como «recién medido». Y un pinchazo reciente no cuenta.
    @Test("12 · sin muestras del sensor, sin sensor y antigüedad nil")
    func sinMuestrasAntiguedadNil() async throws {
        let repositorio = RepositorioLecturasFalso()
        try await repositorio.guardar(LecturaGlucosaDato(
            mgDl: 110, tsUtc: ahora.addingTimeInterval(-2 * 60), origen: .manual
        ))

        let estado = try await ConsultarModo(lecturas: repositorio)
            .ejecutar(lecturaHealthKitActiva: true, ahora: ahora)

        #expect(estado.modo == .sinSensor)
        #expect(estado.antiguedadMin == nil)
    }

    /// Prueba 13 · **P-04**, RF-10b — sin sensor no se promete una alerta que no se puede dar.
    @Test("13 · P-04: en modo sin sensor no se puede alertar de hipoglucemia")
    func sinSensorNoAlerta() async throws {
        let salud = HealthKitFalso()
        let ancla = AnclaHealthKit(dominio: "glucy.pruebas.\(UUID().uuidString)")
        defer { UserDefaults.standard.removePersistentDomain(forName: ancla.dominio!) }

        let resultado = await SincronizarLecturasDelSensor(
            servicio: salud, lecturas: RepositorioLecturasFalso(), ancla: ancla
        ).ejecutar(ahora: ahora)

        #expect(resultado.estado.modo == .sinSensor)
        #expect(!resultado.estado.puedeAlertarHipoglucemia)

        let fresco = try await ConsultarModo(lecturas: repositorioConSensor(haceMin: 5))
            .ejecutar(lecturaHealthKitActiva: true, ahora: ahora)
        #expect(fresco.puedeAlertarHipoglucemia)
    }
}
