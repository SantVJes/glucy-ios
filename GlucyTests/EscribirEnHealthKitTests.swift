import Foundation
import Testing
@testable import Glucy

/// Qué se escribe en Salud y qué no. La prueba que no puede fallar es la 8: lo del sensor
/// no se reescribe, o la serie se duplica en cada arranque.
struct EscribirEnHealthKitTests {

    private let ahora = Date(timeIntervalSince1970: 1_758_240_000)

    /// Prueba 7 · RF-15 — lo capturado a mano llega a Salud y queda anotado.
    @Test("7 · RF-15: una lectura manual sí se escribe en Salud")
    func manualSeEscribe() async throws {
        let salud = HealthKitFalso()
        let repositorio = RepositorioLecturasFalso()
        let dato = LecturaGlucosaDato(mgDl: 112, tsUtc: ahora, origen: .manual)

        let escrita = await EscribirEnHealthKit(servicio: salud, lecturas: repositorio)
            .ejecutar(dato)

        #expect(escrita)
        #expect(await salud.escritas.map(\.uuid) == [dato.uuid])
        #expect(await repositorio.marcadasEnHealthKit == [dato.uuid])
    }

    /// Prueba 8 · **RF-15b, caso P-14** — una lectura del sensor ya está en Salud.
    @Test("8 · RF-15b (P-14): una lectura del sensor no se escribe en Salud")
    func P14_sensorNoSeEscribe() async throws {
        let salud = HealthKitFalso()
        let repositorio = RepositorioLecturasFalso()
        let dato = LecturaGlucosaDato(mgDl: 134, tsUtc: ahora, origen: .sensor)

        let escrita = await EscribirEnHealthKit(servicio: salud, lecturas: repositorio)
            .ejecutar(dato)

        #expect(!escrita)
        #expect(await salud.escritas.isEmpty)
        #expect(await repositorio.marcadasEnHealthKit.isEmpty)

        // Tampoco lo que vino de Salud por otra vía.
        let deSalud = LecturaGlucosaDato(mgDl: 134, tsUtc: ahora, origen: .healthkit)
        await EscribirEnHealthKit(servicio: salud, lecturas: repositorio).ejecutar(deSalud)
        #expect(await salud.escritas.isEmpty)
    }

    /// Prueba 9 · RF-15 — la foto del glucómetro es captura de Glucy, igual que la manual.
    @Test("9 · RF-15: una lectura por foto del glucómetro sí se escribe")
    func fotoSeEscribe() async throws {
        let salud = HealthKitFalso()
        let repositorio = RepositorioLecturasFalso()
        let dato = LecturaGlucosaDato(mgDl: 98, tsUtc: ahora, origen: .fotoGlucometro)

        let escrita = await EscribirEnHealthKit(servicio: salud, lecturas: repositorio)
            .ejecutar(dato)

        #expect(escrita)
        #expect(await salud.escritas.map(\.uuid) == [dato.uuid])
    }
}
