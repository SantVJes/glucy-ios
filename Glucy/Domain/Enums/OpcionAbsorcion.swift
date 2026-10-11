import Foundation

/// Las tres velocidades de absorción que se ofrecen al ajustar una comida (RF-12b).
///
/// No es un campo de la comida: la comida guarda los minutos, que es lo que usa el COB. Esto
/// solo existe para que la pantalla ofrezca tres opciones y ninguna más.
nonisolated enum OpcionAbsorcion: CaseIterable, Sendable {
    case rapida
    case normal
    case lenta

    var minutos: Int {
        switch self {
        case .rapida: ConfiguracionDominio.absorcionRapidaMin
        case .normal: ConfiguracionDominio.absorcionPorOmisionMin
        case .lenta: ConfiguracionDominio.absorcionLentaMin
        }
    }
}
