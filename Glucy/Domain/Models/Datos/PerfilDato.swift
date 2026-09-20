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
        self.creadoTsUtc = creadoTsUtc
        self.actualizadoTsUtc = actualizadoTsUtc
        self.zonaHoraria = zonaHoraria
        self.syncEstado = syncEstado
    }
}
