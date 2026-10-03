import Foundation

/// La unidad en la que la persona ve la glucosa en Salud.
///
/// Adentro de Glucy todo es mg/dL sin excepción: las reglas del paso 1 están escritas en
/// esa unidad. Una lectura en mmol/L se convierte al entrar y nunca se guarda así.
nonisolated enum UnidadGlucosa: String, Codable, CaseIterable, Sendable {
    case mgDl = "mg/dL"
    case mmolL = "mmol/L"

    /// El valor en mg/dL, que es el único que entra a la base.
    func aMgDl(_ valor: Double) -> Double {
        switch self {
        case .mgDl: valor
        case .mmolL: valor * ConfiguracionDominio.factorMmolLAMgDl
        }
    }
}
