import Foundation

/// Evento de contexto que la persona registra y que afecta la glucosa sin ser comida ni
/// insulina. Nunca se infiere: si no hay registro, no hay dato (D-9, RF-37).
nonisolated enum ClaseEvento: String, Codable, CaseIterable, Sendable {
    case ejercicio = "ejercicio"
    case sueno = "sueno"
    case estres = "estres"
    case enfermedad = "enfermedad"
}
