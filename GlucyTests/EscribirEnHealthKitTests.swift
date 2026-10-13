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

    // MARK: - Paso 7: insulina y carbohidratos

    @Test("14 · RF-15: la dosis se escribe en Salud con su UUID como identificador")
    func laDosisSeEscribeConSuUuid() async throws {
        let salud = HealthKitFalso()
        let dosis = RepositorioDosisFalso()
        let dato = DosisInsulinaDato(tsUtc: ahora, unidades: 4, tipo: .bolo)

        let escrita = await EscribirEnHealthKit(
            servicio: salud, lecturas: RepositorioLecturasFalso(), dosis: dosis
        ).ejecutar(dato)

        #expect(escrita)
        let enSalud = try #require(await salud.insulinaEnSalud[dato.uuid])
        #expect(enSalud.unidades == 4)
        // El tipo viaja con ella: de ahí sale la razón de bolo o basal.
        #expect(enSalud.tipo == .bolo)
        #expect(await dosis.marcadasEnHealthKit == [dato.uuid])
    }

    @Test("15 · RF-15b: escribir la dosis dos veces no crea dos muestras")
    func escribirDosVecesNoDuplica() async throws {
        let salud = HealthKitFalso()
        let escribir = EscribirEnHealthKit(servicio: salud, lecturas: RepositorioLecturasFalso())
        let dato = DosisInsulinaDato(tsUtc: ahora, unidades: 4, tipo: .bolo)

        // Un reintento, con el mismo registro.
        await escribir.ejecutar(dato)
        await escribir.ejecutar(dato)

        // El mismo identificador las dos veces: Salud reemplaza, no agrega.
        #expect(await salud.insulinaEnSalud.count == 1)
        #expect(await salud.insulinaEnSalud.keys.first == dato.uuid)

        // Y la que ya consta como escrita ni siquiera se vuelve a mandar.
        let otraSalud = HealthKitFalso()
        let yaEscrita = DosisInsulinaDato(
            tsUtc: ahora, unidades: 4, tipo: .bolo, escritaEnHealthKit: true
        )
        let escrita = await EscribirEnHealthKit(
            servicio: otraSalud, lecturas: RepositorioLecturasFalso()
        ).ejecutar(yaEscrita)
        #expect(!escrita)
        #expect(await otraSalud.insulinaEnSalud.isEmpty)
    }

    @Test("18 · RF-15: una comida se escribe en Salud como carbohidratos, con su UUID")
    func laComidaSeEscribeComoCarbohidratos() async throws {
        let salud = HealthKitFalso()
        let comidas = ComidasSwiftData(modelContainer: try ContenedorGlucy.crear(enMemoria: true))
        let registrar = RegistrarComida(
            repositorio: comidas,
            salud: EscribirEnHealthKit(
                servicio: salud, lecturas: RepositorioLecturasFalso(), comidas: comidas
            )
        )

        let dato = try await registrar.ejecutar(
            carbsG: 45, tsUtc: ahora, origen: .barcode, porcionG: 30, porciones: 2, ahora: ahora
        )

        let enSalud = try #require(await salud.carbohidratosEnSalud[dato.uuid])
        #expect(enSalud.carbsG == 45)
        #expect(try await comidas.porUuid(dato.uuid)?.escritaEnHealthKit == true)
        // No se escribió como ninguna otra cosa.
        #expect(await salud.insulinaEnSalud.isEmpty)
        #expect(await salud.escritas.isEmpty)

        // Y el «Deshacer» de la comida también la quita de Salud.
        try await registrar.deshacer(dato)
        #expect(await salud.carbohidratosEnSalud.isEmpty)
        #expect(try await comidas.contar() == 0)
    }
}
