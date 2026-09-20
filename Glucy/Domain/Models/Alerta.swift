import Foundation
import SwiftData

/// Una alerta emitida por la app.
///
/// Guarda el modo en el que se emitió porque en modo sin sensor **no hay alerta
/// anticipada** (RF-10b, caso P-04): sin ese campo no se podría auditar después si la app
/// prometió algo que no podía cumplir.
@Model
nonisolated final class Alerta {
    /// Lo genera el teléfono, nunca la base ni el servidor.
    @Attribute(.unique) var uuid: UUID

    var tsUtc: Date
    /// Identificador de `TimeZone`, por ejemplo `America/Mexico_City` (regla 5).
    var zonaHoraria: String

    /// Valor que la disparó y umbral vigente en ese momento.
    var valorMgDl: Double
    var umbralMgDl: Double

    /// Minutos hacia adelante. `nil` cuando la alerta es sobre el valor actual y no sobre
    /// una predicción.
    var horizonteMin: Int?

    var modo: ModoApp
    var entregada: Bool
    var reconocidaTsUtc: Date?

    var syncEstado: SyncEstado

    init(
        uuid: UUID = UUID(),
        tsUtc: Date,
        zonaHoraria: String = TimeZone.current.identifier,
        valorMgDl: Double,
        umbralMgDl: Double,
        horizonteMin: Int? = nil,
        modo: ModoApp,
        entregada: Bool = false,
        reconocidaTsUtc: Date? = nil,
        syncEstado: SyncEstado = .pendiente
    ) {
        self.uuid = uuid
        self.tsUtc = tsUtc
        self.zonaHoraria = zonaHoraria
        self.valorMgDl = valorMgDl
        self.umbralMgDl = umbralMgDl
        self.horizonteMin = horizonteMin
        self.modo = modo
        self.entregada = entregada
        self.reconocidaTsUtc = reconocidaTsUtc
        self.syncEstado = syncEstado
    }
}
