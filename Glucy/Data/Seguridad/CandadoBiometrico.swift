import Foundation
import LocalAuthentication

/// El candado de la app: Face ID, Touch ID o el código del teléfono.
///
/// `LocalAuthentication` detrás de un protocolo, como HealthKit y Vision: así las pruebas
/// no necesitan un teléfono con Face ID.
nonisolated protocol Candado: Sendable {
    /// `true` si se puede entrar. **Devuelve `true` si la política no se puede evaluar**
    /// (sin hardware, sin código, el servicio no responde).
    func pedirEntrada(motivo: String) async -> Bool
}

/// Lo que se le pregunta al sistema. Va aparte para poder probar la regla del candado, que
/// es lo que importa, sin el sistema delante.
nonisolated protocol EvaluadorDePolitica: Sendable {
    func puedeEvaluar() -> Bool
    /// - Throws: `FalloDeEvaluacion.rechazada` si la persona no pasó o canceló, y cualquier
    ///   otro error si el sistema no pudo ni preguntar.
    func evaluar(motivo: String) async throws -> Bool
}

nonisolated enum FalloDeEvaluacion: Error {
    /// La persona no pasó la biometría ni el código, o cerró la hoja.
    case rechazada
    /// El sistema no pudo preguntar.
    case noDisponible
}

/// El candado de verdad. **Nunca deja a nadie fuera de su propia app.**
///
/// Si el sistema no puede evaluar la política, se entra. Es lo contrario de lo que haría la
/// app de un banco, y es a propósito: a las tres de la mañana, con una hipoglucemia encima,
/// una app que no abre es peor que una app que alguien podría espiar. El dato ya lo cifra el
/// dispositivo; este candado solo estorba a quien levante un teléfono desbloqueado.
nonisolated struct CandadoBiometrico: Candado {
    var evaluador: any EvaluadorDePolitica = EvaluadorDelSistema()

    func pedirEntrada(motivo: String) async -> Bool {
        guard evaluador.puedeEvaluar() else { return true }
        do {
            return try await evaluador.evaluar(motivo: motivo)
        } catch FalloDeEvaluacion.rechazada {
            // Sigue bloqueada, y la pantalla ofrece volver a intentarlo.
            return false
        } catch {
            return true
        }
    }
}

/// `LAContext`, y nada más. Es el único sitio de la app que importa LocalAuthentication.
nonisolated struct EvaluadorDelSistema: EvaluadorDePolitica {
    /// `deviceOwnerAuthentication` y no la variante «con biometría»: esta acepta el código
    /// del teléfono cuando no hay Face ID o cuando falla. Con la otra, quien no tiene
    /// biometría configurada jamás podría abrir su app.
    private static let politica = LAPolicy.deviceOwnerAuthentication

    func puedeEvaluar() -> Bool {
        LAContext().canEvaluatePolicy(Self.politica, error: nil)
    }

    func evaluar(motivo: String) async throws -> Bool {
        do {
            return try await LAContext().evaluatePolicy(Self.politica, localizedReason: motivo)
        } catch let error as LAError {
            switch error.code {
            case .authenticationFailed, .userCancel, .systemCancel, .appCancel, .userFallback:
                throw FalloDeEvaluacion.rechazada
            default:
                throw FalloDeEvaluacion.noDisponible
            }
        }
    }
}
