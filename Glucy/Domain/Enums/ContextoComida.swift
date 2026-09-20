import Foundation

/// Momento de la medición respecto a la comida. Viaja a HealthKit como
/// `HKMetadataKeyBloodGlucoseMealTime` y al backend con su `rawValue` en snake_case.
nonisolated enum ContextoComida: String, Codable, CaseIterable, Sendable {
    case enAyunas = "en_ayunas"
    case antesDeComer = "antes_de_comer"
    case dosHorasDespues = "dos_horas_despues"
    case antesDeDormir = "antes_de_dormir"
    case otro = "otro"
}
