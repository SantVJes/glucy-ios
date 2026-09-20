import Foundation

/// Bolo o basal. Solo el bolo cuenta como insulina activa: la basal no se acumula en este
/// modelo y la basal temporal no se modela porque no hay bomba en el alcance.
nonisolated enum TipoInsulina: String, Codable, CaseIterable, Sendable {
    case bolo = "bolo"
    case basal = "basal"
}

/// Por qué se aplicó la dosis. Viaja a HealthKit como `HKMetadataKeyInsulinDeliveryReason`.
///
/// La app **registra** el motivo que la persona declara; nunca calcula ni sugiere una dosis
/// de correccion ni de comida (regla 7).
nonisolated enum MotivoDosis: String, Codable, CaseIterable, Sendable {
    case comida = "comida"
    case correccion = "correccion"
    case programada = "programada"
}
