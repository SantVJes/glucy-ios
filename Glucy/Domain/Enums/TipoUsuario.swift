import Foundation

/// Tipo de usuario del perfil. Los dos primeros son el usuario principal del proyecto;
/// los otros dos usan la app sin insulina y por eso nunca ven las pantallas de dosis.
nonisolated enum TipoUsuario: String, Codable, CaseIterable, Sendable {
    case tipo1 = "tipo1"
    case tipo2Insulinodependiente = "tipo2_insulinodependiente"
    case prediabetes = "prediabetes"
    case resistenciaInsulina = "resistencia_insulina"
}
