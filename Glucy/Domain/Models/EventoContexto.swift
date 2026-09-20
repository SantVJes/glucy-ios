import Foundation
import SwiftData

/// Algo que afecta la glucosa sin ser comida ni insulina: ejercicio, sueño, estrés o
/// enfermedad. Solo existe si la persona lo registró (D-9, RF-37).
@Model
nonisolated final class EventoContexto {
    /// Lo genera el teléfono, nunca la base ni el servidor.
    @Attribute(.unique) var uuid: UUID

    var tsUtc: Date
    /// Identificador de `TimeZone`, por ejemplo `America/Mexico_City` (regla 5).
    var zonaHoraria: String

    var clase: ClaseEvento
    var duracionMin: Int?

    /// Escala de 1 a 5 tal como la persona la declara. No se deriva de nada.
    var intensidad: Int?

    var origen: Origen

    /// No sube al backend (regla 3).
    var nota: String?

    var syncEstado: SyncEstado

    init(
        uuid: UUID = UUID(),
        tsUtc: Date,
        zonaHoraria: String = TimeZone.current.identifier,
        clase: ClaseEvento,
        duracionMin: Int? = nil,
        intensidad: Int? = nil,
        origen: Origen = .manual,
        nota: String? = nil,
        syncEstado: SyncEstado = .pendiente
    ) {
        self.uuid = uuid
        self.tsUtc = tsUtc
        self.zonaHoraria = zonaHoraria
        self.clase = clase
        self.duracionMin = duracionMin
        self.intensidad = intensidad
        self.origen = origen
        self.nota = nota
        self.syncEstado = syncEstado
    }
}
