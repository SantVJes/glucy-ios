import Foundation

/// Modo en el que la app tiene derecho a estar. No es una preferencia del usuario: lo
/// decide `DecisionModo` a partir de la frescura de la última lectura del sensor (RF-06c).
///
/// En `sinSensor` la app declara en pantalla que no puede anticipar hipoglucemias
/// (RF-10b, caso P-04).
nonisolated enum ModoApp: String, Codable, CaseIterable, Sendable {
    case sensor = "sensor"
    case sinSensor = "sin_sensor"
}
