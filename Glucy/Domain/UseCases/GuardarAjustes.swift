import Foundation

/// Lo que la pantalla de Ajustes puede cambiar del perfil.
///
/// No están aquí, ni van a estar, las entradas de un calculador de bolo: Glucy guarda el
/// nombre de la insulina y su duración de acción porque con eso estima cuánta sigue
/// trabajando, no cuánta habría que aplicarse (regla 7).
nonisolated struct AjustesEditables: Sendable, Equatable {
    var nombre: String
    var apellidos: String
    var pesoKg: Double?
    /// Solo el año (F-1).
    var anioNacimiento: Int
    var tipoUsuario: TipoUsuario
    var unidadPreferida: UnidadGlucosa
    var umbralHipo: Double
    var umbralHiper: Double
    var tipoInsulinaRapida: String
    var duracionAccionH: Double
    var registraInsulina: Bool
    var tiempoAbsorcionMin: Int
    var usaSensor: Bool
    var sincronizacionActiva: Bool
    var bloqueoBiometrico: Bool

    init(perfil: PerfilDato) {
        nombre = perfil.nombre
        apellidos = perfil.apellidos
        pesoKg = perfil.pesoKg
        anioNacimiento = ReglasDePerfil.anio(de: perfil.fechaNacimiento)
        tipoUsuario = perfil.tipoUsuario
        unidadPreferida = perfil.unidadPreferida
        umbralHipo = perfil.umbralHipo
        umbralHiper = perfil.umbralHiper
        tipoInsulinaRapida = perfil.tipoInsulinaRapida ?? ""
        duracionAccionH = perfil.duracionAccionInsulinaH
        registraInsulina = perfil.registraInsulina
        tiempoAbsorcionMin = perfil.tiempoAbsorcionPorOmisionMin
        usaSensor = perfil.usaSensor
        sincronizacionActiva = perfil.sincronizacionActiva
        bloqueoBiometrico = perfil.bloqueoBiometrico
    }
}

/// Guardar lo que la persona cambió en Ajustes, con la misma validación del alta.
nonisolated struct GuardarAjustes: Sendable {
    let perfil: any RepositorioPerfil

    /// Lo que hay guardado hoy. `nil` si todavía no hay alta.
    func actuales() async throws -> AjustesEditables? {
        try await perfil.actual().map(AjustesEditables.init(perfil:))
    }

    /// - Parameter ahora: se pasa, no se toma de `Date()` dentro, para poder probarlo.
    /// - Throws: el `Rechazo` del primer campo que no vale. Si lanza, **no se guarda nada**.
    @discardableResult
    func ejecutar(_ cambios: AjustesEditables, ahora: Date = Date()) async throws -> PerfilDato {
        // Ajustes no es otra puerta: sin un alta con consentimiento no hay nada que editar.
        guard let actual = try await perfil.actual(), actual.consentimientoTsUtc != nil else {
            throw Rechazo.sinConsentimiento
        }

        let nombre = cambios.nombre.trimmingCharacters(in: .whitespaces)
        let apellidos = cambios.apellidos.trimmingCharacters(in: .whitespaces)
        let insulina = cambios.tipoInsulinaRapida.trimmingCharacters(in: .whitespaces)

        if let rechazo = Validacion.validarPerfil(
            nombre: nombre,
            apellidos: apellidos,
            anioNacimiento: cambios.anioNacimiento,
            pesoKg: cambios.pesoKg,
            umbralHipo: cambios.umbralHipo,
            umbralHiper: cambios.umbralHiper,
            tipoInsulinaRapida: insulina,
            duracionAccionH: cambios.duracionAccionH,
            tiempoAbsorcionMin: cambios.tiempoAbsorcionMin,
            ahora: ahora
        ) {
            throw rechazo
        }

        let dato = PerfilDato(
            uuid: actual.uuid,
            nombre: nombre,
            apellidos: apellidos,
            pesoKg: cambios.pesoKg,
            fechaNacimiento: ReglasDePerfil.fechaDeAnio(cambios.anioNacimiento),
            tipoUsuario: cambios.tipoUsuario,
            umbralHipo: cambios.umbralHipo,
            umbralHiper: cambios.umbralHiper,
            tiempoAbsorcionPorOmisionMin: cambios.tiempoAbsorcionMin,
            duracionAccionInsulinaH: cambios.duracionAccionH,
            usaSensor: cambios.usaSensor,
            registraInsulina: cambios.registraInsulina,
            // El consentimiento no se toca desde aquí: lo escribe `CompletarAlta` y solo él.
            consentimientoTsUtc: actual.consentimientoTsUtc,
            unidadPreferida: cambios.unidadPreferida,
            tipoInsulinaRapida: insulina.isEmpty ? nil : insulina,
            sincronizacionActiva: cambios.sincronizacionActiva,
            bloqueoBiometrico: cambios.bloqueoBiometrico,
            creadoTsUtc: actual.creadoTsUtc,
            actualizadoTsUtc: ahora,
            zonaHoraria: actual.zonaHoraria
        )
        try await perfil.guardar(dato)
        return dato
    }
}
