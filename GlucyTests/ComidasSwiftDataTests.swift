import Foundation
import Testing
@testable import Glucy

/// El repositorio de comidas.
/// `ContenedorDependencias` es `@Observable` y vive en el hilo principal, como corresponde a algo
/// que van a consumir las vistas. Los repositorios de adentro son actores: que la prueba
/// corra en el principal no los ata a él.
@MainActor
struct ComidasSwiftDataTests {

    private let ahora = Date(timeIntervalSince1970: 1_758_240_000)

    /// Prueba 3 · RF-36b — se guarda, se relee con su UUID y nace en `pendiente`.
    @Test("3 · RF-36b: la comida se guarda y se relee con su UUID, en pendiente")
    func comidaSeGuardaYSeRelee() async throws {
        let dependencias = try ContenedorDependencias.enMemoria()
        let dato = ComidaDato(
            tsUtc: ahora,
            carbsG: 60,
            tiempoAbsorcionMin: 180,
            origen: .manual,
            descripcion: "Enchiladas"
        )

        #expect(try await dependencias.comidas.guardar(dato))

        let leida = try await dependencias.comidas.porUuid(dato.uuid)
        #expect(leida?.uuid == dato.uuid)
        #expect(leida?.carbsG == 60)
        #expect(leida?.tiempoAbsorcionMin == 180)
        #expect(leida?.descripcion == "Enchiladas")
        #expect(leida?.syncEstado == .pendiente)
        #expect(try await dependencias.comidas.contar() == 1)
    }

    /// Prueba 12 · RF-20 — es la ventana que va a consumir el COB, y se calcula en el
    /// teléfono sin pedirle nada a nadie. Lo de fuera de la ventana no se devuelve, y lo
    /// que no está registrado no se infiere (D-9, RF-37).
    @Test("12 · RF-20: recientes(horas:) de comidas devuelve solo la ventana pedida")
    func recientesDevuelveSoloLaVentana() async throws {
        let dependencias = try ContenedorDependencias.enMemoria()

        let hace1h = ahora.addingTimeInterval(-3600)
        let hace5h = ahora.addingTimeInterval(-5 * 3600)

        try await dependencias.comidas.guardar(
            ComidaDato(tsUtc: hace1h, carbsG: 30, origen: .manual))
        try await dependencias.comidas.guardar(
            ComidaDato(tsUtc: hace5h, carbsG: 80, origen: .manual))

        let ventana = try await dependencias.comidas.recientes(horas: 3, hasta: ahora)
        #expect(ventana.count == 1)
        #expect(ventana.first?.carbsG == 30)

        let ventanaLarga = try await dependencias.comidas.recientes(horas: 6, hasta: ahora)
        #expect(ventanaLarga.count == 2)
        #expect(ventanaLarga.map(\.carbsG) == [80, 30])   // de la más vieja a la más nueva
    }
}
