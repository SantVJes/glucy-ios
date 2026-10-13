import Foundation
import Testing
@testable import Glucy

/// El alta del perfil. Lo que no se negocia: **no existe un perfil sin consentimiento**, el
/// día de nacimiento no entra a la base, y el alta se termina sin conceder un solo permiso.
struct CompletarAltaTests {

    /// 19 de septiembre de 2025.
    private let ahora = Date(timeIntervalSince1970: 1_758_240_000)

    private func completar(
        en perfil: RepositorioPerfilFalso,
        salud: HealthKitFalso,
        nombre: String = "Ana",
        apellidos: String = "Ruiz",
        tipo: TipoUsuario = .tipo1,
        anio: Int = 1990,
        usaSensor: Bool = false,
        acepta: Bool = true
    ) async throws -> PerfilDato {
        try await CompletarAlta(perfil: perfil, salud: salud).ejecutar(
            nombre: nombre, apellidos: apellidos, tipoUsuario: tipo, anioNacimiento: anio,
            pesoKg: nil, unidadPreferida: .mgDl, usaSensor: usaSensor,
            aceptaConsentimiento: acepta, ahora: ahora
        )
    }

    @Test("4 · LFPDPPP: sin aceptar el consentimiento no se guarda nada")
    func sinConsentimientoNoHayPerfil() async throws {
        let perfil = RepositorioPerfilFalso()
        await #expect(throws: Rechazo.sinConsentimiento) {
            try await completar(en: perfil, salud: HealthKitFalso(), acepta: false)
        }
        #expect(try await perfil.existe() == false)
        #expect(try await perfil.actual() == nil)
        #expect(await ConsultarEntrada(perfil: perfil).ejecutar().consintio == false)
    }

    @Test("5 · LFPDPPP: al aceptar, la fecha del consentimiento es la de ese momento")
    func elConsentimientoLlevaSuFecha() async throws {
        let perfil = RepositorioPerfilFalso()
        let guardado = try await completar(en: perfil, salud: HealthKitFalso())

        #expect(guardado.consentimientoTsUtc == ahora)
        #expect(try await perfil.actual()?.consentimientoTsUtc == ahora)
        // Y esa es la puerta de la app.
        #expect(await ConsultarEntrada(perfil: perfil).ejecutar().consintio)
        // Nace sin candado y sin sincronizar: nada sale del teléfono hasta que se decida.
        #expect(!guardado.bloqueoBiometrico)
        #expect(!guardado.sincronizacionActiva)
    }

    @Test("6 · F-1: del nacimiento se guarda el año; el día siempre es el 1 de enero")
    func elDiaExactoNoEntra() async throws {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = .gmt

        for anio in [1958, 1990, 2004, 2010] {
            let guardado = try await completar(
                en: RepositorioPerfilFalso(), salud: HealthKitFalso(), anio: anio
            )
            let partes = utc.dateComponents(
                [.year, .month, .day, .hour, .minute, .second], from: guardado.fechaNacimiento
            )
            #expect(partes.year == anio)
            #expect(partes.month == 1)
            #expect(partes.day == 1)
            #expect(partes.hour == 0 && partes.minute == 0 && partes.second == 0)
        }
        // Quien no llega a la edad mínima no se da de alta, ni aceptando.
        await #expect(throws: Rechazo.edadInsuficiente) {
            try await completar(en: RepositorioPerfilFalso(), salud: HealthKitFalso(), anio: 2011)
        }
    }

    @Test("11 · C-3: el alta acepta las cuatro opciones de tipo de usuario", arguments: TipoUsuario.allCases)
    func lasCuatroOpciones(tipo: TipoUsuario) async throws {
        let guardado = try await completar(en: RepositorioPerfilFalso(), salud: HealthKitFalso(), tipo: tipo)
        #expect(guardado.tipoUsuario == tipo)
        // Y el registro de insulina nace calculado del tipo (RF-14).
        #expect(guardado.registraInsulina == ReglasDePerfil.registraInsulinaPorOmision(para: tipo))
    }

    @Test("12 · F-1: el alta se completa con el nombre y los apellidos vacíos")
    func elNombreEsOpcional() async throws {
        let perfil = RepositorioPerfilFalso()
        let guardado = try await completar(en: perfil, salud: HealthKitFalso(), nombre: "", apellidos: "  ")
        #expect(guardado.nombre.isEmpty)
        #expect(guardado.apellidos.isEmpty)
        #expect(try await perfil.existe())

        // Lo que sí se rechaza es un nombre con cifras o signos.
        await #expect(throws: Rechazo.perfilNoValido(.nombre)) {
            try await completar(en: RepositorioPerfilFalso(), salud: HealthKitFalso(), nombre: "Ana 2")
        }
    }

    @Test("13 · RF-06: el alta «sin sensor» se completa sin pedir ningún permiso")
    func sinSensorNoSePideNada() async throws {
        let perfil = RepositorioPerfilFalso()
        let salud = HealthKitFalso()
        let guardado = try await completar(en: perfil, salud: salud, usaSensor: false)

        #expect(await salud.vecesPedidoPermiso == 0)
        #expect(!guardado.usaSensor)
        #expect(guardado.consentimientoTsUtc != nil)
    }

    @Test("14 · RF-06: si Salud no deja pedir el permiso, devuelve false y no lanza")
    func unPermisoNegadoNoEsUnError() async throws {
        let salud = HealthKitFalso()
        await salud.fallarPermisos(con: PermisoRevocado())
        let alta = CompletarAlta(perfil: RepositorioPerfilFalso(), salud: salud)

        #expect(await alta.pedirPermisoDeSalud() == false)
        #expect(await salud.vecesPedidoPermiso == 1)

        // Sin Salud en el dispositivo tampoco es un error, y ni se intenta.
        let sinSalud = HealthKitFalso(disponible: false)
        #expect(await CompletarAlta(perfil: RepositorioPerfilFalso(), salud: sinSalud).pedirPermisoDeSalud() == false)
        #expect(await sinSalud.vecesPedidoPermiso == 0)

        // Cuando la hoja sí se puede mostrar, devuelve true.
        #expect(await CompletarAlta(perfil: RepositorioPerfilFalso(), salud: HealthKitFalso()).pedirPermisoDeSalud())
    }

    @Test("15 · RF-06: después de ese false el alta se completa igual, en modo sin sensor")
    @MainActor
    func elAltaSigueSinSensor() async throws {
        let perfil = RepositorioPerfilFalso()
        let salud = HealthKitFalso()
        await salud.fallarPermisos(con: PermisoRevocado())
        let modelo = AltaViewModel(completar: CompletarAlta(perfil: perfil, salud: salud))

        modelo.tipoUsuario = .tipo2Insulinodependiente
        modelo.textoAnio = "1975"
        modelo.elegir(usaSensor: true)

        // No avanza todavía: se queda para decir que seguimos sin sensor. No hay error.
        #expect(await modelo.continuarDelSensor() == false)
        #expect(modelo.seguimosSinSensor)
        #expect(modelo.usaSensor == false)
        #expect(modelo.fallo == nil)

        // Y con el siguiente toque continúa y termina.
        #expect(await modelo.continuarDelSensor())
        #expect(await modelo.aceptar(ahora: ahora))

        let guardado = try #require(try await perfil.actual())
        #expect(!guardado.usaSensor)
        #expect(guardado.consentimientoTsUtc == ahora)
        #expect(guardado.tipoUsuario == .tipo2Insulinodependiente)
    }
}
