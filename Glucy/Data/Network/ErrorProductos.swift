import Foundation

/// Por qué no se pudo preguntar por un producto.
///
/// Ninguno de estos llega a la pantalla como error: sin conexión es una condición normal, y
/// los cuatro bajan al siguiente escalón, la foto de la etiqueta (caso P-10).
nonisolated enum ErrorProductos: Error, Equatable {
    case sinRed
    case tiempoAgotado
    case respuestaIlegible
    case fuenteFallo(codigoHttp: Int)
}
