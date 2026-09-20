import Foundation
import SwiftData

/// La persona que usa la app y los parámetros con los que se calculan sus reglas.
///
/// Hay uno solo. Los campos marcados como «no sube» son los que identifican a la persona
/// (regla 3): del resto, el backend solo necesita los parámetros de cálculo.
@Model
nonisolated final class Perfil {
    /// Lo genera el teléfono, nunca la base ni el servidor.
    @Attribute(.unique) var uuid: UUID

    /// No sube al backend (regla 3).
    var nombre: String
    /// No sube al backend (regla 3).
    var apellidos: String
    /// No sube al backend (regla 3).
    var pesoKg: Double?

    var fechaNacimiento: Date
    var tipoUsuario: TipoUsuario

    /// Umbrales del perfil. Mueven el TBR y el TAR; el TIR se mide siempre contra
    /// `ConfiguracionDominio.rangoObjetivo`, que es fijo.
    var umbralHipo: Double
    var umbralHiper: Double

    /// Parámetros de las curvas. Sin ellos el COB y el IOB se calcularían con una curva
    /// equivocada, por eso el alta del perfil los pregunta.
    var tiempoAbsorcionPorOmisionMin: Int
    var duracionAccionInsulinaH: Double

    /// Lo que la persona declara en el alta. El modo real lo decide `DecisionModo` con la
    /// frescura de la última lectura, no este campo.
    var usaSensor: Bool

    var creadoTsUtc: Date
    var actualizadoTsUtc: Date
    /// Identificador de `TimeZone`, por ejemplo `America/Mexico_City` (regla 5).
    var zonaHoraria: String

    var syncEstado: SyncEstado

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
        syncEstado: SyncEstado = .pendiente
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
