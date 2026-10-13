import Foundation
import Testing
@testable import Glucy

/// Lo que Ajustes deja cambiar, con los mismos límites que el alta. Si un cambio no vale,
/// no se guarda nada.
struct GuardarAjustesTests {

    private let ahora = Date(timeIntervalSince1970: 1_758_240_000)

    /// Un perfil recién dado de alta, y sus ajustes listos para editar.
    private func montar(
        tipo: TipoUsuario = .tipo1
    ) async throws -> (GuardarAjustes, RepositorioPerfilFalso, AjustesEditables) {
        let perfil = RepositorioPerfilFalso()
        try await CompletarAlta(perfil: perfil, salud: HealthKitFalso()).ejecutar(
            nombre: "Ana", apellidos: "", tipoUsuario: tipo, anioNacimiento: 1990, pesoKg: nil,
            unidadPreferida: .mgDl, usaSensor: false, aceptaConsentimiento: true, ahora: ahora
        )
        let guardar = GuardarAjustes(perfil: perfil)
        return (guardar, perfil, try #require(try await guardar.actuales()))
    }

    @Test("16 · F-1: un umbral de hipoglucemia de 95 se rechaza; de 85, se guarda")
    func elUmbralDeHipoglucemia() async throws {
        let (guardar, perfil, ajustes) = try await montar()

        var fuera = ajustes
        fuera.umbralHipo = 95
        await #expect(throws: Rechazo.perfilNoValido(.umbralHipo)) {
            try await guardar.ejecutar(fuera, ahora: ahora)
        }
        #expect(try await perfil.actual()?.umbralHipo == 70)

        var dentro = ajustes
        dentro.umbralHipo = 85
        try await guardar.ejecutar(dentro, ahora: ahora)
        #expect(try await perfil.actual()?.umbralHipo == 85)

        // El de hiperglucemia, igual: 140 a 300.
        var alto = dentro
        alto.umbralHiper = 320
        await #expect(throws: Rechazo.perfilNoValido(.umbralHiper)) {
            try await guardar.ejecutar(alto, ahora: ahora)
        }
    }

    @Test("17 · F-1: una duración de acción de 9 h se rechaza; de 8, se guarda")
    func laDuracionDeAccion() async throws {
        let (guardar, perfil, ajustes) = try await montar()

        var fuera = ajustes
        fuera.duracionAccionH = 9
        await #expect(throws: Rechazo.perfilNoValido(.duracionAccion)) {
            try await guardar.ejecutar(fuera, ahora: ahora)
        }
        #expect(try await perfil.actual()?.duracionAccionInsulinaH == 5)

        var dentro = ajustes
        dentro.duracionAccionH = 8
        dentro.tipoInsulinaRapida = " Lispro "
        try await guardar.ejecutar(dentro, ahora: ahora)
        let guardado = try #require(try await perfil.actual())
        #expect(guardado.duracionAccionInsulinaH == 8)
        #expect(guardado.tipoInsulinaRapida == "Lispro")
    }

    @Test("18 · F-1: un peso de 10 kg se rechaza; de 70, se guarda")
    func elPeso() async throws {
        let (guardar, perfil, ajustes) = try await montar()

        var fuera = ajustes
        fuera.pesoKg = 10
        await #expect(throws: Rechazo.perfilNoValido(.peso)) {
            try await guardar.ejecutar(fuera, ahora: ahora)
        }
        #expect(try await perfil.actual()?.pesoKg == nil)

        var dentro = ajustes
        dentro.pesoKg = 70
        try await guardar.ejecutar(dentro, ahora: ahora)
        #expect(try await perfil.actual()?.pesoKg == 70)

        // Y se puede volver a dejar en blanco: es opcional.
        dentro.pesoKg = nil
        try await guardar.ejecutar(dentro, ahora: ahora)
        #expect(try await perfil.actual()?.pesoKg == nil)
    }

    @Test("19 · RF-14: apagar el registro de insulina se guarda y se vuelve a leer")
    func ocultarLaInsulina() async throws {
        let (guardar, perfil, ajustes) = try await montar()
        #expect(ajustes.registraInsulina)
        #expect(await ConsultarAjustesDeInsulina(perfil: perfil).registraInsulina())

        var apagado = ajustes
        apagado.registraInsulina = false
        try await guardar.ejecutar(apagado, ahora: ahora.addingTimeInterval(60))

        #expect(try await guardar.actuales()?.registraInsulina == false)
        #expect(await ConsultarAjustesDeInsulina(perfil: perfil).registraInsulina() == false)

        // Guardar un ajuste no toca el consentimiento ni el resto del perfil.
        let guardado = try #require(try await perfil.actual())
        #expect(guardado.consentimientoTsUtc == ahora)
        #expect(guardado.nombre == "Ana")
        #expect(guardado.tipoUsuario == .tipo1)
        #expect(guardado.actualizadoTsUtc == ahora.addingTimeInterval(60))
    }
}
