import Foundation

/// Las dosis que la persona dice haberse aplicado. La app registra; no calcula ni sugiere
/// ninguna dosis (regla 7).
nonisolated protocol RepositorioDosis: Sendable {
    /// Guarda y encola en la misma llamada. `false` si ese UUID ya existía (RF-36c).
    @discardableResult
    func guardar(_ dato: DosisInsulinaDato) async throws -> Bool

    func porUuid(_ uuid: UUID) async throws -> DosisInsulinaDato?

    /// Las de las últimas `horas`, que es lo que el IOB necesita.
    func recientes(horas: Double, hasta: Date) async throws -> [DosisInsulinaDato]

    func contar() async throws -> Int
}
