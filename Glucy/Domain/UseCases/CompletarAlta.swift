import Foundation

/// La única puerta que escribe el consentimiento. Vive en un caso de uso y no en el
/// ViewModel porque es la base legal para guardar datos de salud, no un campo más.
nonisolated struct CompletarAlta: Sendable {
    let perfil: any RepositorioPerfil
    let salud: any ServicioHealthKit

    /// - Parameter aceptaConsentimiento: si llega `false`, **no se guarda nada** y se lanza
    ///   el rechazo. No hay forma de crear un perfil sin consentimiento.
    /// - Parameter anioNacimiento: solo el año (F-1). El `Date` que se guarda es el 1 de
    ///   enero de ese año: así el día exacto no entra nunca a la base.
    /// - Parameter tipoInsulinaRapida: texto libre. No se guarda en quien no se aplica
    ///   insulina.
    /// - Parameter ahora: se pasa, no se toma de `Date()` dentro, para poder probarlo.
    /// - Throws: el `Rechazo` que impide el alta.
    @discardableResult
    func ejecutar(
        nombre: String,
        apellidos: String,
        tipoUsuario: TipoUsuario,
        anioNacimiento: Int,
        pesoKg: Double?,
        unidadPreferida: UnidadGlucosa,
        usaSensor: Bool,
        umbralHipo: Double = ConfiguracionDominio.umbralHipoPorOmision,
        umbralHiper: Double = ConfiguracionDominio.umbralHiperPorOmision,
        tipoInsulinaRapida: String? = nil,
        duracionAccionH: Double = ConfiguracionDominio.duracionAccionPorOmisionH,
        aceptaConsentimiento: Bool,
        ahora: Date = Date()
    ) async throws -> PerfilDato {
        // Antes que cualquier otra cosa: sin esto no se revisa ni se guarda nada (LFPDPPP).
        guard aceptaConsentimiento else { throw Rechazo.sinConsentimiento }

        let nombre = nombre.trimmingCharacters(in: .whitespaces)
        let apellidos = apellidos.trimmingCharacters(in: .whitespaces)
        let registraInsulina = ReglasDePerfil.registraInsulinaPorOmision(para: tipoUsuario)
        let insulina = tipoInsulinaRapida?.trimmingCharacters(in: .whitespaces)

        if let rechazo = Validacion.validarPerfil(
            nombre: nombre,
            apellidos: apellidos,
            anioNacimiento: anioNacimiento,
            pesoKg: pesoKg,
            umbralHipo: umbralHipo,
            umbralHiper: umbralHiper,
            tipoInsulinaRapida: insulina,
            duracionAccionH: duracionAccionH,
            tiempoAbsorcionMin: ConfiguracionDominio.absorcionPorOmisionMin,
            ahora: ahora
        ) {
            throw rechazo
        }

        // Una base que viene de antes del alta puede traer un perfil sin consentimiento: se
        // completa esa misma fila en lugar de dejar dos.
        let anterior = try await perfil.actual()
        let dato = PerfilDato(
            uuid: anterior?.uuid ?? UUID(),
            nombre: nombre,
            apellidos: apellidos,
            pesoKg: pesoKg,
            fechaNacimiento: ReglasDePerfil.fechaDeAnio(anioNacimiento),
            tipoUsuario: tipoUsuario,
            umbralHipo: umbralHipo,
            umbralHiper: umbralHiper,
            duracionAccionInsulinaH: duracionAccionH,
            // Lo que la persona declara. El modo real lo decide `DecisionModo` con la
            // frescura de la última lectura (RF-06c).
            usaSensor: usaSensor,
            registraInsulina: registraInsulina,
            consentimientoTsUtc: ahora,
            unidadPreferida: unidadPreferida,
            tipoInsulinaRapida: registraInsulina && insulina?.isEmpty == false ? insulina : nil,
            creadoTsUtc: anterior?.creadoTsUtc ?? ahora,
            actualizadoTsUtc: ahora
        )
        try await perfil.guardar(dato)
        return dato
    }

    /// Pide el permiso de lectura de Salud con su explicación ya mostrada. **Nunca lanza
    /// hacia la vista**: un permiso negado no es un error, es el modo sin sensor (RF-06).
    ///
    /// `true` no quiere decir que la persona dijo que sí: para lectura iOS no lo dice. Quiere
    /// decir que la hoja se pudo mostrar.
    func pedirPermisoDeSalud() async -> Bool {
        guard salud.disponible else { return false }
        do {
            try await salud.pedirPermisos()
            return true
        } catch {
            return false
        }
    }
}
