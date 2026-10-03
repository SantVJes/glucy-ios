import Foundation

/// Lo que puede salir mal al hablar con Salud.
///
/// Ninguno de estos llega a la interfaz. `SincronizarLecturasDelSensor` traduce cualquier
/// fallo de lectura a cero muestras y modo sin sensor (RF-07, caso P-09), y
/// `EscribirEnHealthKit` deja la lectura guardada en el teléfono aunque Salud la rechace:
/// el teléfono es el dueño del dato (regla 1), Salud es una copia.
nonisolated enum ErrorHealthKit: Error, Equatable {
    /// El dispositivo no tiene Salud.
    case noDisponible
    /// El SDK no reconoce el tipo. No debería pasar en iOS 17, pero se nombra en lugar de
    /// forzar un `!`.
    case tipoNoDisponible
}
