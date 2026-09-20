import Foundation
import SwiftData

/// Una dosis que la persona **dice haberse aplicado**.
///
/// La app registra, no calcula ni sugiere (regla 7). Esa es la frontera con un dispositivo
/// médico regulado, y este modelo está del lado de acá.
@Model
nonisolated final class DosisInsulina {
    /// Lo genera el teléfono, nunca la base ni el servidor.
    @Attribute(.unique) var uuid: UUID

    var tsUtc: Date
    /// Identificador de `TimeZone`, por ejemplo `America/Mexico_City` (regla 5).
    var zonaHoraria: String

    /// Unidades internacionales, en múltiplos de 0.5: es lo que la pluma puede dosificar.
    var unidades: Double

    var tipo: TipoInsulina
    var motivo: MotivoDosis
    var origen: Origen

    /// Duración de acción vigente cuando se aplicó. Se guarda con la dosis para que el IOB
    /// del histórico no cambie si mañana el perfil mueve su DIA.
    var duracionAccionH: Double

    /// La app escribe en HealthKit solo lo que ella capturó (RF-15b).
    var escritaEnHealthKit: Bool

    /// No sube al backend (regla 3).
    var nota: String?

    var syncEstado: SyncEstado

    init(
        uuid: UUID = UUID(),
        tsUtc: Date,
        zonaHoraria: String = TimeZone.current.identifier,
        unidades: Double,
        tipo: TipoInsulina,
        motivo: MotivoDosis,
        origen: Origen = .manual,
        duracionAccionH: Double = ConfiguracionDominio.duracionAccionPorOmisionH,
        escritaEnHealthKit: Bool = false,
        nota: String? = nil,
        syncEstado: SyncEstado = .pendiente
    ) {
        self.uuid = uuid
        self.tsUtc = tsUtc
        self.zonaHoraria = zonaHoraria
        self.unidades = unidades
        self.tipo = tipo
        self.motivo = motivo
        self.origen = origen
        self.duracionAccionH = duracionAccionH
        self.escritaEnHealthKit = escritaEnHealthKit
        self.nota = nota
        self.syncEstado = syncEstado
    }
}
