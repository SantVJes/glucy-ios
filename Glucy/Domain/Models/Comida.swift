import Foundation
import SwiftData

/// Una comida registrada por la persona.
///
/// Nunca se infiere: si no hay registro, no hay comida (D-9, RF-37). Una subida de glucosa
/// sin registro se queda sin explicación antes que inventarle una causa (caso P-12).
@Model
nonisolated final class Comida {
    /// Lo genera el teléfono, nunca la base ni el servidor.
    @Attribute(.unique) var uuid: UUID

    var tsUtc: Date
    /// Identificador de `TimeZone`, por ejemplo `America/Mexico_City` (regla 5).
    var zonaHoraria: String

    var carbsG: Double

    /// Lo que usa el COB de esta comida. Se guarda por comida y no solo en el perfil: una
    /// cena lenta y un jugo no se absorben igual, y el histórico tiene que poder
    /// recalcularse con el valor que estaba vigente.
    var tiempoAbsorcionMin: Int

    var origen: Origen
    var descripcion: String?
    var codigoBarras: String?
    var nombreProducto: String?
    var porcionG: Double?

    /// Lo que llegó por código de barras o por OCR de la etiqueta se confirma antes de
    /// guardarse, sin umbral de confianza (D-11, caso P-01).
    var confirmadaPorUsuario: Bool

    /// La app escribe en HealthKit solo lo que ella capturó (RF-15b).
    var escritaEnHealthKit: Bool

    /// No sube al backend (regla 3).
    var nota: String?

    var syncEstado: SyncEstado

    init(
        uuid: UUID = UUID(),
        tsUtc: Date,
        zonaHoraria: String = TimeZone.current.identifier,
        carbsG: Double,
        tiempoAbsorcionMin: Int = ConfiguracionDominio.absorcionPorOmisionMin,
        origen: Origen,
        descripcion: String? = nil,
        codigoBarras: String? = nil,
        nombreProducto: String? = nil,
        porcionG: Double? = nil,
        confirmadaPorUsuario: Bool = true,
        escritaEnHealthKit: Bool = false,
        nota: String? = nil,
        syncEstado: SyncEstado = .pendiente
    ) {
        self.uuid = uuid
        self.tsUtc = tsUtc
        self.zonaHoraria = zonaHoraria
        self.carbsG = carbsG
        self.tiempoAbsorcionMin = tiempoAbsorcionMin
        self.origen = origen
        self.descripcion = descripcion
        self.codigoBarras = codigoBarras
        self.nombreProducto = nombreProducto
        self.porcionG = porcionG
        self.confirmadaPorUsuario = confirmadaPorUsuario
        self.escritaEnHealthKit = escritaEnHealthKit
        self.nota = nota
        self.syncEstado = syncEstado
    }
}
