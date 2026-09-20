import Foundation

/// Cuándo se vacía la cola hacia el backend (RF-35, RF-36).
nonisolated enum DecisionSincronizacion {

    /// Solo con wifi, por lotes y lo más antiguo primero. Nunca con datos móviles salvo
    /// que la persona toque «sincronizar ahora» (caso P-08).
    ///
    /// Se gana batería y plan de datos, y se pierde inmediatez en una función que no es de
    /// emergencia: la app completa ya funciona sin servidor.
    static func debeSincronizar(
        hayWifi: Bool,
        pendientes: Int,
        forzadoPorUsuario: Bool = false
    ) -> Bool {
        guard pendientes > 0 else { return false }
        return hayWifi || forzadoPorUsuario
    }
}
