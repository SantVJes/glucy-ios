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

    /// RF-14: el usuario secundario —prediabetes, resistencia a la insulina— no se aplica
    /// insulina, y una pestaña que no usa nunca le estorba. Nace en `true` porque el usuario
    /// principal es quien sí la usa.
    var registraInsulina: Bool = true

    /// Cuándo la persona aceptó, en UTC. `nil` significa **que no ha aceptado**, y mientras
    /// sea `nil` la app no entra: la LFPDPPP exige consentimiento expreso para datos de salud
    /// y un booleano sin fecha no sirve para demostrar cuándo se dio.
    var consentimientoTsUtc: Date?

    /// En qué unidad quiere ver sus cifras. Adentro **todo se guarda en mg/dL**; esto solo
    /// cambia cómo se muestran y cómo se interpreta lo que teclea.
    ///
    /// Es opcional en la tabla, y `nil` quiere decir mg/dL: la etapa ligera no rellena un
    /// enum en las filas que ya existían, y al leer un perfil migrado la app se caía. Fuera
    /// de `Data/` nadie ve el opcional: `PerfilDato` siempre trae una unidad.
    var unidadPreferida: UnidadGlucosa?

    /// El nombre comercial de su insulina rápida, tal como ella lo escriba. Es texto libre a
    /// propósito: una lista cerrada se queda corta en cuanto cambie de marca o de país.
    /// `nil` en quien no se aplica insulina.
    var tipoInsulinaRapida: String?

    /// Nace en `false`: nada sale del teléfono hasta que la persona lo decida (F-1). En la
    /// fase 1 no hay servidor todavía, así que encenderlo solo llena la cola.
    var sincronizacionActiva: Bool = false

    /// Si la app pide Face ID o Touch ID al abrirse. Nace **apagado**: una app de salud que
    /// se bloquea sola el primer día, sin que nadie lo pidiera, se desinstala.
    var bloqueoBiometrico: Bool = false

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
        registraInsulina: Bool = true,
        consentimientoTsUtc: Date? = nil,
        unidadPreferida: UnidadGlucosa = .mgDl,
        tipoInsulinaRapida: String? = nil,
        sincronizacionActiva: Bool = false,
        bloqueoBiometrico: Bool = false,
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
        self.registraInsulina = registraInsulina
        self.consentimientoTsUtc = consentimientoTsUtc
        self.unidadPreferida = unidadPreferida
        self.tipoInsulinaRapida = tipoInsulinaRapida
        self.sincronizacionActiva = sincronizacionActiva
        self.bloqueoBiometrico = bloqueoBiometrico
        self.creadoTsUtc = creadoTsUtc
        self.actualizadoTsUtc = actualizadoTsUtc
        self.zonaHoraria = zonaHoraria
        self.syncEstado = syncEstado
    }
}

// MARK: - Conversión a valor

extension Perfil {
    convenience init(dato: PerfilDato) {
        self.init(
            uuid: dato.uuid,
            nombre: dato.nombre,
            apellidos: dato.apellidos,
            pesoKg: dato.pesoKg,
            fechaNacimiento: dato.fechaNacimiento,
            tipoUsuario: dato.tipoUsuario,
            umbralHipo: dato.umbralHipo,
            umbralHiper: dato.umbralHiper,
            tiempoAbsorcionPorOmisionMin: dato.tiempoAbsorcionPorOmisionMin,
            duracionAccionInsulinaH: dato.duracionAccionInsulinaH,
            usaSensor: dato.usaSensor,
            registraInsulina: dato.registraInsulina,
            consentimientoTsUtc: dato.consentimientoTsUtc,
            unidadPreferida: dato.unidadPreferida,
            tipoInsulinaRapida: dato.tipoInsulinaRapida,
            sincronizacionActiva: dato.sincronizacionActiva,
            bloqueoBiometrico: dato.bloqueoBiometrico,
            creadoTsUtc: dato.creadoTsUtc,
            actualizadoTsUtc: dato.actualizadoTsUtc,
            zonaHoraria: dato.zonaHoraria,
            syncEstado: dato.syncEstado
        )
    }

    var dato: PerfilDato {
        PerfilDato(
            uuid: uuid,
            nombre: nombre,
            apellidos: apellidos,
            pesoKg: pesoKg,
            fechaNacimiento: fechaNacimiento,
            tipoUsuario: tipoUsuario,
            umbralHipo: umbralHipo,
            umbralHiper: umbralHiper,
            tiempoAbsorcionPorOmisionMin: tiempoAbsorcionPorOmisionMin,
            duracionAccionInsulinaH: duracionAccionInsulinaH,
            usaSensor: usaSensor,
            registraInsulina: registraInsulina,
            consentimientoTsUtc: consentimientoTsUtc,
            unidadPreferida: unidadPreferida ?? .mgDl,
            tipoInsulinaRapida: tipoInsulinaRapida,
            sincronizacionActiva: sincronizacionActiva,
            bloqueoBiometrico: bloqueoBiometrico,
            creadoTsUtc: creadoTsUtc,
            actualizadoTsUtc: actualizadoTsUtc,
            zonaHoraria: zonaHoraria,
            syncEstado: syncEstado
        )
    }
}
