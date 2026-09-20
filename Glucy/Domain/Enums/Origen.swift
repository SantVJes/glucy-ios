import Foundation

/// De dónde salió el dato. Todo registro guarda su origen sin excepción (regla 4): sin él
/// no se puede distinguir una lectura del sensor de un pinchazo, y las reglas de frescura,
/// de tasa de cambio y de interpolación dependen de esa distinción.
///
/// El `rawValue` es el que viaja al backend (Documento 3, snake_case). Se escribe explícito
/// para que renombrar el caso en Swift nunca rompa el contrato con el servidor.
nonisolated enum Origen: String, Codable, CaseIterable, Sendable {
    case sensor = "sensor"
    case manual = "manual"
    case fotoGlucometro = "foto_glucometro"
    case barcode = "barcode"
    case ocrEtiqueta = "ocr_etiqueta"
    case healthkit = "healthkit"
}
