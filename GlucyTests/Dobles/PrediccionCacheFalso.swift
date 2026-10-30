import Foundation
@testable import Glucy

/// La caché de predicciones de mentira, en memoria. Se porta como la de verdad: una fila por
/// horizonte, y guardar reemplaza.
actor PrediccionCacheFalso: RepositorioPrediccionCache {
    private(set) var filas: [Int: PrediccionGuardadaDato] = [:]
    private(set) var vecesQueSeGuardo = 0

    init() {}

    func guardar(_ dato: PrediccionGuardadaDato) async throws {
        vecesQueSeGuardo += 1
        filas[dato.horizonteMin] = dato
    }

    func ultima(horizonteMin: Int) async throws -> PrediccionGuardadaDato? {
        filas[horizonteMin]
    }

    func todas() async throws -> [PrediccionGuardadaDato] {
        filas.keys.sorted().compactMap { filas[$0] }
    }

    func eliminarTodo() async throws {
        filas = [:]
    }

    /// Para preparar el caso de «ya había algo guardado».
    func sembrar(_ dato: PrediccionGuardadaDato) {
        filas[dato.horizonteMin] = dato
    }
}
