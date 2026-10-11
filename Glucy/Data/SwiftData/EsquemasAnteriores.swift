import Foundation
import SwiftData

// Los modelos tal como eran en las versiones anteriores del esquema.
//
// **Por qué existen:** SwiftData reconoce cada versión por la forma de sus tablas. Si la V1,
// la V2 y la V3 apuntan a las mismas clases —las de hoy—, las tres tienen la misma forma, y
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
}
