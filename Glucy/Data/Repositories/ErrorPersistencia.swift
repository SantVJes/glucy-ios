import Foundation

/// Lo que puede salir mal al guardar o leer en el teléfono.
///
/// Un duplicado **no** está aquí: guardar dos veces el mismo UUID devuelve `false`, no
/// lanza. HealthKit reentrega las mismas muestras y la persona puede tocar «guardar» dos
/// veces; eso es normal, no una falla (RF-36c).
nonisolated enum ErrorPersistencia: Error, Equatable {
    case noEncontrado(uuid: UUID)
    case contenedorNoDisponible
    case escrituraFallida(motivo: String)
}
