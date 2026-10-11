import Foundation

/// Las comidas registradas por la persona.
nonisolated protocol RepositorioComidas: Sendable {
    /// Guarda y encola en la misma llamada. `false` si ese UUID ya existía (RF-36c).
    @discardableResult
    func guardar(_ dato: ComidaDato) async throws -> Bool

    func porUuid(_ uuid: UUID) async throws -> ComidaDato?

    /// Las de las últimas `horas`, que es lo que el COB necesita. Nunca infiere ninguna
    /// que no esté registrada (D-9, RF-37).
    func recientes(horas: Double, hasta: Date) async throws -> [ComidaDato]

    func contar() async throws -> Int

    /// Para el «Deshacer» de la franja de confirmación. Se lleva también la fila de la
    /// cola: si se quedara, el backend recibiría una comida que en el teléfono ya no existe.
    func eliminar(uuid: UUID) async throws

    /// La última comida registrada con ese código, para ofrecer las mismas porciones.
    /// Es algo que la persona ya dijo, no algo que la app deduzca (RF-37).
    func ultimaConCodigo(_ codigo: String) async throws -> ComidaDato?
}
