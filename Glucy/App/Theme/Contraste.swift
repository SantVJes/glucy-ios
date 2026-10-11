import Foundation

/// La razón de contraste de WCAG 2.x entre dos colores.
///
/// Vive en el código y no solo en un documento porque es lo que impide que un color nuevo
/// entre sin medirse: las pruebas la usan sobre cada par que de verdad se dibuja junto.
nonisolated enum Contraste {

    /// De 1:1 (el mismo color) a 21:1 (negro sobre blanco). El orden de los argumentos no
    /// importa.
    static func razon(_ a: UInt32, _ b: UInt32) -> Double {
        let (la, lb) = (luminancia(a), luminancia(b))
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    /// Luminancia relativa de sRGB, con la linealización de WCAG.
    static func luminancia(_ hex: UInt32) -> Double {
        func lineal(_ canal: UInt32) -> Double {
            let c = Double(canal) / 255
            return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * lineal((hex >> 16) & 0xFF)
             + 0.7152 * lineal((hex >> 8) & 0xFF)
             + 0.0722 * lineal(hex & 0xFF)
    }
}
