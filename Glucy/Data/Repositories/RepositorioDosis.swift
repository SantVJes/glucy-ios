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

    /// Para el «Deshacer» de la franja de confirmación. Se lleva también la fila de la
    /// cola: si se quedara, el backend recibiría una dosis que en el teléfono ya no existe.
    func eliminar(uuid: UUID) async throws

    /// La última dosis registrada, para proponer el mismo tipo y decir a qué hora fue. Es
    /// algo que la persona ya dijo, no algo que la app deduzca.
    func ultima() async throws -> DosisInsulinaDato?

    func marcarEscritaEnHealthKit(uuid: UUID) async throws
}
