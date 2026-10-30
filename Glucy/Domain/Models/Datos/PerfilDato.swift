import Foundation

/// El perfil como valor.
///
/// Nace en `.local` y **no se encola nunca**: lo que identifica a la persona no sube
/// (regla 3). Los parámetros que el backend sí necesita para el modelo —los umbrales, el
/// tiempo de absorción, la duración de acción— viajarán en la fase 2 como una carga aparte
/// y reducida, no como esta fila. Así `nombre`, `apellidos` y `pesoKg` no tienen por dónde
/// escaparse.
nonisolated struct PerfilDato: Sendable, Equatable, Identifiable {
    var id: UUID { uuid }

    /// Lo genera el teléfono, nunca la base ni el servidor (RF-36c).
    let uuid: UUID
    /// No sube al backend (regla 3).
    let nombre: String
    /// No sube al backend (regla 3).
    let apellidos: String
    /// No sube al backend (regla 3).
    let pesoKg: Double?
    let fechaNacimiento: Date
    let tipoUsuario: TipoUsuario
    let umbralHipo: Double
    let umbralHiper: Double
    let tiempoAbsorcionPorOmisionMin: Int
    let duracionAccionInsulinaH: Double
    let usaSensor: Bool
    /// RF-14: quien no se aplica insulina puede ocultar su registro.
    let registraInsulina: Bool
    /// Cuándo aceptó, en UTC. `nil` es que no ha aceptado, y sin eso la app no entra.
    let consentimientoTsUtc: Date?
    /// Solo cambia cómo se muestran las cifras; adentro todo es mg/dL.
    let unidadPreferida: UnidadGlucosa
    /// Texto libre. `nil` en quien no se aplica insulina.
    let tipoInsulinaRapida: String?
    let sincronizacionActiva: Bool
    let bloqueoBiometrico: Bool
    /// Si la frase que explica la estimación la redacta el asistente o la arma la app. Viaja
    /// a `POST /explain` como `asistente_activo`; apagado, el servidor usa la plantilla
    /// determinista y no llama a ningún modelo de lenguaje.
    let asistenteActivo: Bool
    let creadoTsUtc: Date
    let actualizadoTsUtc: Date
    /// Identificador de `TimeZone` (regla 5).
    let zonaHoraria: String
    let syncEstado: SyncEstado

    init(
        uuid: UUID = UUID(),
        nombre: String = "",
        apellidos: String = "",
        pesoKg: Double? = nil,
        fechaNacimiento: Date,
        tipoUsuario: TipoUsuario,
        umbralHipo: Double = ConfiguracionDominio.umbralHipoPorOmision,
        umbralHiper: Double = ConfiguracionDominio.umbralHiperPorOmision,
        tiempoAbsorcionPorOmisionMin: Int = ConfiguracionDominio.absorcionPorOmisionMin,
        duracionAccionInsulinaH: Double = ConfiguracionDominio.duracionAccionPorOmisionH,
        usaSensor: Bool = false,
        registraInsulina: Bool = true,
        consentimientoTsUtc: Date? = nil,
        unidadPreferida: UnidadGlucosa = .mgDl,
        tipoInsulinaRapida: String? = nil,
        sincronizacionActiva: Bool = false,
        bloqueoBiometrico: Bool = false,
        asistenteActivo: Bool = true,
        creadoTsUtc: Date = Date(),
        actualizadoTsUtc: Date = Date(),
        zonaHoraria: String = TimeZone.current.identifier,
        syncEstado: SyncEstado = .local
    ) {
        self.uuid = uuid
        self.nombre = nombre
        self.apellidos = apellidos
        self.pesoKg = pesoKg
        self.fechaNacimiento = fechaNacimiento
        self.tipoUsuario = tipoUsuario
        self.umbralHipo = umbralHipo
        self.umbralHiper = umbralHiper
        self.tiempoAbsorcionPorOmisionMin = tiempoAbsorcionPorOmisionMin
        self.duracionAccionInsulinaH = duracionAccionInsulinaH
        self.usaSensor = usaSensor
        self.registraInsulina = registraInsulina
        self.consentimientoTsUtc = consentimientoTsUtc
        self.unidadPreferida = unidadPreferida
        self.tipoInsulinaRapida = tipoInsulinaRapida
        self.sincronizacionActiva = sincronizacionActiva
        self.bloqueoBiometrico = bloqueoBiometrico
        self.asistenteActivo = asistenteActivo
        self.creadoTsUtc = creadoTsUtc
        self.actualizadoTsUtc = actualizadoTsUtc
        self.zonaHoraria = zonaHoraria
        self.syncEstado = syncEstado
    }
}
