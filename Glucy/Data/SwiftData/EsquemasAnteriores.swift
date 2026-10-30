import Foundation
import SwiftData

// Los modelos tal como eran en las versiones anteriores del esquema.
//
// **Por qué existen:** SwiftData reconoce cada versión por la forma de sus tablas. Si todas
// las versiones apuntan a las mismas clases —las de hoy—, todas tienen la misma forma, y
// al abrir una base que de verdad es vieja el plan de migración no la reconoce y la app se
// cae al arrancar con «Duplicate version checksums detected». No es un error que se pueda
// atrapar: es una excepción, y se lleva la app con las semanas de datos adentro.
//
// Por eso cada versión guarda aquí una copia congelada de las tablas que cambiaron después.
// **Estas clases no se editan nunca.** Solo las usa el plan de migración; el resto de la app
// trabaja con los modelos de `Domain/Models/`.

extension EsquemaGlucyV1 {

    /// `LecturaGlucosa` antes de los tres campos de RF-05b.
    @Model
    nonisolated final class LecturaGlucosa {
        @Attribute(.unique) var uuid: UUID
        var mgDl: Double
        var tsUtc: Date
        var zonaHoraria: String
        var origen: Origen
        var contexto: ContextoComida?
        var confirmadaPorUsuario: Bool
        var atipica: Bool
        var escritaEnHealthKit: Bool
        var nota: String?
        var syncEstado: SyncEstado

        init(uuid: UUID = UUID(), mgDl: Double, tsUtc: Date, origen: Origen) {
            self.uuid = uuid
            self.mgDl = mgDl
            self.tsUtc = tsUtc
            zonaHoraria = TimeZone.current.identifier
            self.origen = origen
            confirmadaPorUsuario = true
            atipica = false
            escritaEnHealthKit = false
            syncEstado = .pendiente
        }
    }

    /// `Comida` antes de `porciones`. Es la misma en la V1 y en la V2.
    @Model
    nonisolated final class Comida {
        @Attribute(.unique) var uuid: UUID
        var tsUtc: Date
        var zonaHoraria: String
        var carbsG: Double
        var tiempoAbsorcionMin: Int
        var origen: Origen
        var descripcion: String?
        var codigoBarras: String?
        var nombreProducto: String?
        var porcionG: Double?
        var confirmadaPorUsuario: Bool
        var escritaEnHealthKit: Bool
        var nota: String?
        var syncEstado: SyncEstado

        init(
            uuid: UUID = UUID(), tsUtc: Date, carbsG: Double, origen: Origen,
            porcionG: Double? = nil
        ) {
            self.uuid = uuid
            self.tsUtc = tsUtc
            zonaHoraria = TimeZone.current.identifier
            self.carbsG = carbsG
            tiempoAbsorcionMin = ConfiguracionDominio.absorcionPorOmisionMin
            self.origen = origen
            self.porcionG = porcionG
            confirmadaPorUsuario = true
            escritaEnHealthKit = false
            syncEstado = .pendiente
        }
    }

    /// `ProductoCache` antes de `encontrado`. Es la misma en la V1 y en la V2.
    @Model
    nonisolated final class ProductoCache {
        @Attribute(.unique) var codigoBarras: String
        var nombre: String
        var marca: String?
        var carbsPor100g: Double
        var porcionSugeridaG: Double?
        var fuente: String
        var consultadoTsUtc: Date
        var zonaHoraria: String
        var syncEstado: SyncEstado

        init(codigoBarras: String, nombre: String, carbsPor100g: Double) {
            self.codigoBarras = codigoBarras
            self.nombre = nombre
            self.carbsPor100g = carbsPor100g
            fuente = "Open Food Facts"
            consultadoTsUtc = Date()
            zonaHoraria = TimeZone.current.identifier
            syncEstado = .local
        }
    }
    /// `DosisInsulina` cuando `motivo` todavía era obligatorio. Es la misma en la V1, la V2
    /// y la V3.
    @Model
    nonisolated final class DosisInsulina {
        @Attribute(.unique) var uuid: UUID
        var tsUtc: Date
        var zonaHoraria: String
        var unidades: Double
        var tipo: TipoInsulina
        var motivo: MotivoDosis
        var origen: Origen
        var duracionAccionH: Double
        var escritaEnHealthKit: Bool
        var nota: String?
        var syncEstado: SyncEstado

        init(
            uuid: UUID = UUID(), tsUtc: Date, unidades: Double, tipo: TipoInsulina,
            motivo: MotivoDosis
        ) {
            self.uuid = uuid
            self.tsUtc = tsUtc
            zonaHoraria = TimeZone.current.identifier
            self.unidades = unidades
            self.tipo = tipo
            self.motivo = motivo
            origen = .manual
            duracionAccionH = ConfiguracionDominio.duracionAccionPorOmisionH
            escritaEnHealthKit = false
            syncEstado = .pendiente
        }
    }

    /// `Perfil` antes de `registraInsulina`. Es el mismo en la V1, la V2 y la V3.
    @Model
    nonisolated final class Perfil {
        @Attribute(.unique) var uuid: UUID
        var nombre: String
        var apellidos: String
        var pesoKg: Double?
        var fechaNacimiento: Date
        var tipoUsuario: TipoUsuario
        var umbralHipo: Double
        var umbralHiper: Double
        var tiempoAbsorcionPorOmisionMin: Int
        var duracionAccionInsulinaH: Double
        var usaSensor: Bool
        var creadoTsUtc: Date
        var actualizadoTsUtc: Date
        var zonaHoraria: String
        var syncEstado: SyncEstado

        init(uuid: UUID = UUID(), fechaNacimiento: Date, tipoUsuario: TipoUsuario) {
            self.uuid = uuid
            nombre = ""
            apellidos = ""
            self.fechaNacimiento = fechaNacimiento
            self.tipoUsuario = tipoUsuario
            umbralHipo = ConfiguracionDominio.umbralHipoPorOmision
            umbralHiper = ConfiguracionDominio.umbralHiperPorOmision
            tiempoAbsorcionPorOmisionMin = ConfiguracionDominio.absorcionPorOmisionMin
            duracionAccionInsulinaH = ConfiguracionDominio.duracionAccionPorOmisionH
            usaSensor = false
            creadoTsUtc = Date()
            actualizadoTsUtc = Date()
            zonaHoraria = TimeZone.current.identifier
            syncEstado = .local
        }
    }
}

extension EsquemaGlucyV4 {

    /// `Perfil` con `registraInsulina` y antes de los cinco campos de F-1.
    @Model
    nonisolated final class Perfil {
        @Attribute(.unique) var uuid: UUID
        var nombre: String
        var apellidos: String
        var pesoKg: Double?
        var fechaNacimiento: Date
        var tipoUsuario: TipoUsuario
        var umbralHipo: Double
        var umbralHiper: Double
        var tiempoAbsorcionPorOmisionMin: Int
        var duracionAccionInsulinaH: Double
        var usaSensor: Bool
        var registraInsulina: Bool = true
        var creadoTsUtc: Date
        var actualizadoTsUtc: Date
        var zonaHoraria: String
        var syncEstado: SyncEstado

        init(
            uuid: UUID = UUID(), nombre: String = "", pesoKg: Double? = nil,
            fechaNacimiento: Date, tipoUsuario: TipoUsuario,
            umbralHipo: Double = ConfiguracionDominio.umbralHipoPorOmision,
            duracionAccionInsulinaH: Double = ConfiguracionDominio.duracionAccionPorOmisionH,
            usaSensor: Bool = false, registraInsulina: Bool = true
        ) {
            self.uuid = uuid
            self.nombre = nombre
            apellidos = ""
            self.pesoKg = pesoKg
            self.fechaNacimiento = fechaNacimiento
            self.tipoUsuario = tipoUsuario
            self.umbralHipo = umbralHipo
            umbralHiper = ConfiguracionDominio.umbralHiperPorOmision
            tiempoAbsorcionPorOmisionMin = ConfiguracionDominio.absorcionPorOmisionMin
            self.duracionAccionInsulinaH = duracionAccionInsulinaH
            self.usaSensor = usaSensor
            self.registraInsulina = registraInsulina
            creadoTsUtc = Date()
            actualizadoTsUtc = Date()
            zonaHoraria = TimeZone.current.identifier
            syncEstado = .local
        }
    }
}

extension EsquemaGlucyV5 {

    /// `Perfil` con los cinco campos de F-1 y antes de `asistenteActivo`.
    @Model
    nonisolated final class Perfil {
        @Attribute(.unique) var uuid: UUID
        var nombre: String
        var apellidos: String
        var pesoKg: Double?
        var fechaNacimiento: Date
        var tipoUsuario: TipoUsuario
        var umbralHipo: Double
        var umbralHiper: Double
        var tiempoAbsorcionPorOmisionMin: Int
        var duracionAccionInsulinaH: Double
        var usaSensor: Bool
        var registraInsulina: Bool = true
        var consentimientoTsUtc: Date?
        var unidadPreferida: UnidadGlucosa?
        var tipoInsulinaRapida: String?
        var sincronizacionActiva: Bool = false
        var bloqueoBiometrico: Bool = false
        var creadoTsUtc: Date
        var actualizadoTsUtc: Date
        var zonaHoraria: String
        var syncEstado: SyncEstado

        init(
            uuid: UUID = UUID(), nombre: String = "", pesoKg: Double? = nil,
            fechaNacimiento: Date, tipoUsuario: TipoUsuario,
            umbralHipo: Double = ConfiguracionDominio.umbralHipoPorOmision,
            duracionAccionInsulinaH: Double = ConfiguracionDominio.duracionAccionPorOmisionH,
            usaSensor: Bool = false, registraInsulina: Bool = true
        ) {
            self.uuid = uuid
            self.nombre = nombre
            apellidos = ""
            self.pesoKg = pesoKg
            self.fechaNacimiento = fechaNacimiento
            self.tipoUsuario = tipoUsuario
            self.umbralHipo = umbralHipo
            umbralHiper = ConfiguracionDominio.umbralHiperPorOmision
            tiempoAbsorcionPorOmisionMin = ConfiguracionDominio.absorcionPorOmisionMin
            self.duracionAccionInsulinaH = duracionAccionInsulinaH
            self.usaSensor = usaSensor
            self.registraInsulina = registraInsulina
            consentimientoTsUtc = nil
            unidadPreferida = nil
            tipoInsulinaRapida = nil
            sincronizacionActiva = false
            bloqueoBiometrico = false
            creadoTsUtc = Date()
            actualizadoTsUtc = Date()
            zonaHoraria = TimeZone.current.identifier
            syncEstado = .local
        }
    }
}
