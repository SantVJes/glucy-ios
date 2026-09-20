import Foundation

/// Estado de un registro frente al backend. Existe desde el primer día aunque no haya
/// servidor hasta la fase 2: los acuerdos que permiten conectar un backend meses después
/// hay que tomarlos ahora, no cuando ya hay datos guardados sin ellos.
///
/// - `local`: no viaja nunca (lo que identifica a la persona, regla 3).
/// - `pendiente`: nace aquí todo lo que sí viaja.
/// - `error`: no se descarta en silencio; se reintenta y se puede mostrar.
nonisolated enum SyncEstado: String, Codable, CaseIterable, Sendable {
    case local = "local"
    case pendiente = "pendiente"
    case enviado = "enviado"
    case confirmado = "confirmado"
    case error = "error"
}
