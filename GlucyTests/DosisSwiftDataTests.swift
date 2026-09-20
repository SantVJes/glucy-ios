import Foundation
import Testing
@testable import Glucy

/// El repositorio de dosis de insulina. Registra lo que la persona dice haberse aplicado;
/// no calcula ni sugiere ninguna dosis (regla 7).
/// `ContenedorDependencias` es `@Observable` y vive en el hilo principal, como corresponde a algo
/// que van a consumir las vistas. Los repositorios de adentro son actores: que la prueba
/// corra en el principal no los ata a él.
@MainActor
struct DosisSwiftDataTests {

    private let ahora = Date(timeIntervalSince1970: 1_758_240_000)

    /// Prueba 4 · RF-36b — se guarda, se relee con su UUID y nace en `pendiente`.
    @Test("4 · RF-36b: la dosis se guarda y se relee con su UUID, en pendiente")
    func dosisSeGuardaYSeRelee() async throws {
        let dependencias = try ContenedorDependencias.enMemoria()
        let dato = DosisInsulinaDato(
            tsUtc: ahora,
            unidades: 6.5,
            tipo: .bolo,
            motivo: .comida
        )

        #expect(try await dependencias.dosis.guardar(dato))

        let leida = try await dependencias.dosis.porUuid(dato.uuid)
        #expect(leida?.uuid == dato.uuid)
        #expect(leida?.unidades == 6.5)
        #expect(leida?.tipo == .bolo)
        #expect(leida?.motivo == .comida)
        #expect(leida?.syncEstado == .pendiente)
        #expect(try await dependencias.dosis.contar() == 1)
    }

    /// Prueba 12 · RF-20 — la otra mitad: es la ventana que va a consumir el IOB.
    @Test("12 · RF-20: recientes(horas:) de dosis devuelve solo la ventana pedida")
    func recientesDevuelveSoloLaVentana() async throws {
        let dependencias = try ContenedorDependencias.enMemoria()

        let hace2h = ahora.addingTimeInterval(-2 * 3600)
        let hace9h = ahora.addingTimeInterval(-9 * 3600)

        try await dependencias.dosis.guardar(
            DosisInsulinaDato(tsUtc: hace2h, unidades: 4, tipo: .bolo, motivo: .comida))
        try await dependencias.dosis.guardar(
            DosisInsulinaDato(tsUtc: hace9h, unidades: 12, tipo: .basal, motivo: .programada))

        // La duración de acción por omisión son 5 h: más atrás no hay insulina que contar.
        let ventana = try await dependencias.dosis.recientes(horas: 5, hasta: ahora)
        #expect(ventana.count == 1)
        #expect(ventana.first?.unidades == 4)

        let ventanaLarga = try await dependencias.dosis.recientes(horas: 12, hasta: ahora)
        #expect(ventanaLarga.count == 2)
        #expect(ventanaLarga.map(\.unidades) == [12, 4])   // de la más vieja a la más nueva
    }
}
