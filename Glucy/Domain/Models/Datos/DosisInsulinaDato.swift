import Foundation

/// Una dosis aplicada, como valor. La app registra lo que la persona dice haberse
/// aplicado; nunca calcula ni sugiere una dosis (regla 7).
nonisolated struct DosisInsulinaDato: Sendable, Equatable, Identifiable {
    var id: UUID { uuid }

    /// Lo genera el teléfono, nunca la base ni el servidor (RF-36c).
    let uuid: UUID
    let tsUtc: Date
    /// Identificador de `TimeZone` (regla 5). Siempre viaja junto al `tsUtc`.
    let zonaHoraria: String
    let unidades: Double
    let tipo: TipoInsulina
    let motivo: MotivoDosis
    let origen: Origen
    let duracionAccionH: Double
    let escritaEnHealthKit: Bool
    /// No sube al backend (regla 3).
    let nota: String?
    let syncEstado: SyncEstado

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
