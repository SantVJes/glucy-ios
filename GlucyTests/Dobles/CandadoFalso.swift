import Foundation
@testable import Glucy

/// Un candado de mentira para las pantallas: abre o no abre, según se le diga, y lleva la
/// cuenta de cuántas veces se le pidió.
actor CandadoFalso: Candado {
    private let abre: Bool
    private(set) var vecesPedido = 0

    init(abre: Bool) {
        self.abre = abre
    }

    func pedirEntrada(motivo: String) async -> Bool {
        vecesPedido += 1
        return abre
    }
}

/// El sistema de mentira, para probar la regla de `CandadoBiometrico` sin un teléfono con
/// Face ID.
struct EvaluadorFalso: EvaluadorDePolitica {
    enum Respuesta: Sendable {
        /// No hay hardware, no hay código o el servicio no responde.
        case noSePuedeEvaluar
        case pasa
        /// La persona falló o cerró la hoja.
        case noPasa
        /// El sistema dijo que podía y al preguntar no pudo.
        case fallaAlPreguntar
    }

    let respuesta: Respuesta

    func puedeEvaluar() -> Bool {
        if case .noSePuedeEvaluar = respuesta { return false }
        return true
    }

    func evaluar(motivo: String) async throws -> Bool {
        switch respuesta {
        case .pasa, .noSePuedeEvaluar: true
        case .noPasa: throw FalloDeEvaluacion.rechazada
        case .fallaAlPreguntar: throw FalloDeEvaluacion.noDisponible
        }
    }
}
