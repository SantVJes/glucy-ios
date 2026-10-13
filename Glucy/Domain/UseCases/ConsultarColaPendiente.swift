import Foundation

/// Cuántos registros esperan turno para subir. Es el contador de la pantalla de Ajustes.
///
/// En la fase 1 no hay servidor: la cola se llena y no se vacía, y la pantalla lo dice.
nonisolated struct ConsultarColaPendiente: Sendable {
    let cola: any RepositorioCola

    /// `nil` si la cola no se pudo leer. No se enseña un cero que nadie contó.
    func ejecutar() async -> Int? {
        try? await cola.contarPendientes()
    }
}
