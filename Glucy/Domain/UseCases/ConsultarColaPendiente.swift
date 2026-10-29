import Foundation

/// Los dos números de la cola que enseña la pantalla de Ajustes: lo que espera turno y lo
/// que quedó rechazado.
nonisolated struct ConsultarColaPendiente: Sendable {
    let cola: any RepositorioCola

    /// `nil` si la cola no se pudo leer. No se enseña un cero que nadie contó.
    func ejecutar() async -> Int? {
        try? await cola.contarPendientes()
    }

    /// Cuántos quedaron rechazados por el servidor. Se cuentan aparte de los pendientes
    /// porque no esperan turno: no se van a reintentar solos, y hay que poder verlos
    /// (RF-22).
    func conError() async -> Int? {
        try? await cola.contarConError()
    }
}
