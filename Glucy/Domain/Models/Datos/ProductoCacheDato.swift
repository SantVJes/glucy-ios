import Foundation

/// Una fila de la caché de productos, como valor.
///
/// Guarda tanto lo que la fuente sí conoce como su «no lo tengo»: las dos respuestas evitan
/// repetir la consulta.
nonisolated struct ProductoCacheDato: Sendable, Equatable {
    let codigoBarras: String
    /// `false` cuando la fuente contestó que no conoce el código o que no trae
    /// carbohidratos. Entonces `nombre` y `carbsPor100g` no significan nada, y por eso el
    /// producto se pide con `producto`, que devuelve `nil`.
    let encontrado: Bool
    let nombre: String
    let marca: String?
    let carbsPor100g: Double
    let porcionSugeridaG: Double?
    let consultadoTsUtc: Date
    /// Identificador de `TimeZone` (regla 5).
    let zonaHoraria: String

    /// Lo que la fuente sí conoce.
    init(producto: Producto, consultadoTsUtc: Date) {
        codigoBarras = producto.codigoBarras
        encontrado = true
        nombre = producto.nombre
        marca = producto.marca
        carbsPor100g = producto.carbsPor100g
        porcionSugeridaG = producto.porcionSugeridaG
        self.consultadoTsUtc = consultadoTsUtc
        zonaHoraria = TimeZone.current.identifier
    }

    /// El «no lo tengo».
    init(noEncontrado codigo: String, consultadoTsUtc: Date) {
        codigoBarras = codigo
        encontrado = false
        nombre = ""
        marca = nil
        carbsPor100g = 0
        porcionSugeridaG = nil
        self.consultadoTsUtc = consultadoTsUtc
        zonaHoraria = TimeZone.current.identifier
    }

    init(
        codigoBarras: String,
        encontrado: Bool,
        nombre: String,
        marca: String?,
        carbsPor100g: Double,
        porcionSugeridaG: Double?,
        consultadoTsUtc: Date,
        zonaHoraria: String
    ) {
        self.codigoBarras = codigoBarras
        self.encontrado = encontrado
        self.nombre = nombre
        self.marca = marca
        self.carbsPor100g = carbsPor100g
        self.porcionSugeridaG = porcionSugeridaG
        self.consultadoTsUtc = consultadoTsUtc
        self.zonaHoraria = zonaHoraria
    }

    var producto: Producto? {
        guard encontrado else { return nil }
        return Producto(
            codigoBarras: codigoBarras,
            nombre: nombre,
            marca: marca,
            carbsPor100g: carbsPor100g,
            porcionSugeridaG: porcionSugeridaG
        )
    }
}
