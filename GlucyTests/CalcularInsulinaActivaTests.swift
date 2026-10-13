import Foundation
import Testing
@testable import Glucy

/// La insulina que sigue trabajando, con las dosis que la persona registró. Los números
/// esperados salen de `iob` en `referencia/reglas_clinicas.py` de glucy-backend: si el Swift
/// y esa referencia no coinciden, uno de los dos está mal.
struct CalcularInsulinaActivaTests {

    private let ahora = Date(timeIntervalSince1970: 1_758_240_000)

    private func hace(_ minutos: Double) -> Date {
        ahora.addingTimeInterval(-minutos * 60)
    }

    private func dosis(
        _ unidades: Double, haceMin minutos: Double, duracionH: Double = 5,
        tipo: TipoInsulina = .bolo
    ) -> DosisInsulinaDato {
        DosisInsulinaDato(
            tsUtc: hace(minutos), unidades: unidades, tipo: tipo, duracionAccionH: duracionH
        )
    }

    private func insulinaActiva(con dosis: [DosisInsulinaDato]) async throws -> Double {
        let repositorio = RepositorioDosisFalso()
        for d in dosis { try await repositorio.guardar(d) }
        return try await CalcularInsulinaActiva(dosis: repositorio).ejecutar(ahora: ahora)
    }

    @Test("8 · RF-14: mover la duración del perfil no cambia el IOB de una dosis ya guardada")
    @MainActor
    func moverElPerfilNoMueveElHistorico() async throws {
        let dependencias = ContenedorDependencias(
            contenedor: try ContenedorGlucy.crear(enMemoria: true), salud: HealthKitFalso()
        )
        let perfil = PerfilDato(
            fechaNacimiento: Date(timeIntervalSince1970: 800_000_000), tipoUsuario: .tipo1,
            duracionAccionInsulinaH: 5
        )
        try await dependencias.perfil.guardar(perfil)

        try await dependencias.registrarDosis.ejecutar(
            unidades: 4, tsUtc: hace(120), tipo: .bolo, motivo: nil,
            duracionAccionH: await dependencias.ajustesDeInsulina.duracionAccionH(),
            ahora: ahora
        )
        let antes = try await dependencias.calcularInsulinaActiva.ejecutar(ahora: ahora)
        // Referencia: iob([(4, 120)], dia_h=5)
        #expect(abs(antes - 1.6423197685921362) < 1e-12)

        // El perfil pasa a ocho horas. Con ocho, esa misma dosis daría 1.95.
        try await dependencias.perfil.guardar(PerfilDato(
            uuid: perfil.uuid, fechaNacimiento: perfil.fechaNacimiento, tipoUsuario: .tipo1,
            duracionAccionInsulinaH: 8
        ))
        #expect(await dependencias.ajustesDeInsulina.duracionAccionH() == 8)

        let despues = try await dependencias.calcularInsulinaActiva.ejecutar(ahora: ahora)
        #expect(despues == antes)
    }

    /// La que importa más.
    @Test("9 · RF-14: 4 UI hace cuatro horas da el mismo IOB que la referencia en Python")
    func coincideConLaReferencia() async throws {
        // Referencia: iob([(4, 240)]) = 0.13169947518651526
        let total = try await insulinaActiva(con: [dosis(4, haceMin: 240)])
        #expect(abs(total - 0.13169947518651526) < 1e-12)
    }

    @Test("10 · RF-14: dos dosis a distinta hora suman su IOB")
    func dosDosisSuman() async throws {
        // Referencia: iob([(4, 60), (2, 180)]) = 3.3736156449765407
        let total = try await insulinaActiva(con: [
            dosis(4, haceMin: 60),
            dosis(2, haceMin: 180),
            // La basal no cuenta como insulina activa en este modelo.
            dosis(20, haceMin: 90, tipo: .basal)
        ])
        #expect(abs(total - 3.3736156449765407) < 1e-12)
    }

    @Test("11 · RF-14: una dosis de hace nueve horas aporta cero")
    func nueveHorasDespuesNoQuedaNada() async throws {
        // Ni con la duración más larga que el perfil admite.
        #expect(try await insulinaActiva(con: [dosis(4, haceMin: 540, duracionH: 8)]) == 0)
        #expect(try await insulinaActiva(con: [dosis(4, haceMin: 540)]) == 0)
        #expect(try await insulinaActiva(con: []) == 0)
    }

    @Test("12 · RF-14: con dos dosis de distinta duración, cada una usa la suya")
    func cadaDosisConSuDuracion() async throws {
        // Referencia: iob([(4, 120)], dia_h=5) + iob([(4, 120)], dia_h=8)
        //           = 1.6423197685921362 + 1.9528088294247903
        let total = try await insulinaActiva(con: [
            dosis(4, haceMin: 120, duracionH: 5),
            dosis(4, haceMin: 120, duracionH: 8)
        ])
        #expect(abs(total - (1.6423197685921362 + 1.9528088294247903)) < 1e-12)
    }

    @Test("13 · RF-14: el cálculo pide ocho horas de dosis, no cinco")
    func pideOchoHoras() async throws {
        let repositorio = RepositorioDosisFalso()
        // Seis horas después, con una duración de ocho, esta dosis sigue activa. Pidiendo
        // solo cinco horas se quedaría fuera.
        try await repositorio.guardar(dosis(4, haceMin: 360, duracionH: 8))

        let total = try await CalcularInsulinaActiva(dosis: repositorio).ejecutar(ahora: ahora)

        #expect(await repositorio.horasPedidas == [8])
        // Referencia: iob([(4, 360)], dia_h=8) = 0.06030074227512472
        #expect(abs(total - 0.06030074227512472) < 1e-12)
    }
}
