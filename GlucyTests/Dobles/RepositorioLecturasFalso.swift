import Foundation
@testable import Glucy

/// Un repositorio de mentira, para probar el caso de uso y el ViewModel sin levantar
/// SwiftData.
///
/// Es un actor porque el protocolo pide `Sendable` y porque así lleva la cuenta de lo que
/// se le pidió sin carreras. Lo que importa de él es justo eso: **cuántas veces se le
/// llamó**, que es como se comprueba que un valor inválido no llegó a tocarlo.
actor RepositorioLecturasFalso: RepositorioLecturas {
    private(set) var guardadas: [LecturaGlucosaDato] = []
    private(set) var eliminadas: [UUID] = []

    /// Para la prueba del doble toque: con un retraso, la segunda llamada llega mientras la
    /// primera sigue en curso, que es lo que pasa de verdad al tocar dos veces seguidas.
    private var retrasoMs: UInt64 = 0

    func conRetraso(ms: UInt64) {
        retrasoMs = ms
    }

    @discardableResult
    func guardar(_ dato: LecturaGlucosaDato) async throws -> Bool {
        if retrasoMs > 0 {
            try? await Task.sleep(for: .milliseconds(retrasoMs))
        }
        guard !guardadas.contains(where: { $0.uuid == dato.uuid }) else { return false }
        guardadas.append(dato)
        return true
    }

    func porUuid(_ uuid: UUID) async throws -> LecturaGlucosaDato? {
        guardadas.first { $0.uuid == uuid }
    }

    func ultima() async throws -> LecturaGlucosaDato? {
        guardadas.max { $0.tsUtc < $1.tsUtc }
    }

    func entre(desde: Date, hasta: Date) async throws -> [LecturaGlucosaDato] {
        guardadas
            .filter { $0.tsUtc >= desde && $0.tsUtc <= hasta }
            .sorted { $0.tsUtc < $1.tsUtc }
    }

    func contar() async throws -> Int {
        guardadas.count
    }

    func eliminar(uuid: UUID) async throws {
        guardadas.removeAll { $0.uuid == uuid }
        eliminadas.append(uuid)
    }
}
