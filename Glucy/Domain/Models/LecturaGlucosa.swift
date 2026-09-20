import Foundation
import SwiftData

/// Una lectura de glucosa, venga del sensor, de un pinchazo capturado a mano o de la foto
/// del glucómetro.
@Model
nonisolated final class LecturaGlucosa {
    /// Lo genera el teléfono, nunca la base ni el servidor.
    @Attribute(.unique) var uuid: UUID

    /// Siempre en mg/dL: HealthKit se consulta con `preferredUnits(for:)` y se convierte
    /// al entrar, para que adentro haya una sola unidad.
    var mgDl: Double

    var tsUtc: Date
    /// Identificador de `TimeZone`, por ejemplo `America/Mexico_City` (regla 5).
    var zonaHoraria: String

    var origen: Origen
    var contexto: ContextoComida?

    /// Todo valor de OCR entra confirmado por la persona o no entra (D-11, caso P-01).
    var confirmadaPorUsuario: Bool

    /// La marcó `Validacion.esAtipicaPorTasa`. Se conserva y se señala; no se borra.
    var atipica: Bool

    /// La app escribe en HealthKit solo lo que ella capturó. Lo que vino del sensor no se
    /// reescribe, o la serie se duplica al siguiente arranque (RF-15b, caso P-14).
    var escritaEnHealthKit: Bool

    /// No sube al backend (regla 3).
    var nota: String?

    var syncEstado: SyncEstado

    init(
        uuid: UUID = UUID(),
        mgDl: Double,
        tsUtc: Date,
        zonaHoraria: String = TimeZone.current.identifier,
        origen: Origen,
        contexto: ContextoComida? = nil,
        confirmadaPorUsuario: Bool = true,
        atipica: Bool = false,
        escritaEnHealthKit: Bool = false,
        nota: String? = nil,
        syncEstado: SyncEstado = .pendiente
    ) {
        self.uuid = uuid
        self.mgDl = mgDl
        self.tsUtc = tsUtc
        self.zonaHoraria = zonaHoraria
        self.origen = origen
        self.contexto = contexto
        self.confirmadaPorUsuario = confirmadaPorUsuario
        self.atipica = atipica
        self.escritaEnHealthKit = escritaEnHealthKit
        self.nota = nota
        self.syncEstado = syncEstado
    }
}
