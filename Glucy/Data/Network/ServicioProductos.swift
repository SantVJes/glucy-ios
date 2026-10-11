import Foundation

/// Lo que Open Food Facts contestó, ya traducido a lo que la app necesita.
nonisolated struct Producto: Sendable, Equatable {
    let codigoBarras: String
    let nombre: String
    let marca: String?
    /// Carbohidratos por 100 g, como los publica la fuente.
    let carbsPor100g: Double
    /// Los gramos de una porción, **solo si la fuente los dio en gramos**. Si no, `nil`, y
    /// se le preguntan a la persona: nunca se supone que una porción son 100 g.
    let porcionSugeridaG: Double?
}

/// La base de productos, detrás de un protocolo.
///
/// Mismo motivo que HealthKit y Vision, y uno más: las pruebas no pueden pegarle al servicio
/// de verdad. El límite es de 15 consultas por minuto y por IP, y una prueba que depende de
/// internet falla por razones que no son el código.
nonisolated protocol ServicioProductos: Sendable {
    /// `nil` cuando la fuente contesta que no conoce el código, o lo conoce y no trae
    /// carbohidratos. Lanza cuando no se pudo preguntar (sin red, tiempo agotado, 5xx).
    ///
    /// La diferencia importa: «no lo conozco» y «no pude preguntar» llevan al mismo sitio
    /// para la persona —la foto de la etiqueta— pero uno se puede cachear y el otro no.
    func producto(codigo: String) async throws -> Producto?
}
