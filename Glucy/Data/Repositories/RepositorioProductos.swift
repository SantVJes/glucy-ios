import Foundation

/// La caché de lo que ya se le preguntó a Open Food Facts.
///
/// No es dato de la persona y no sube al backend: es la copia local de la respuesta de un
/// tercero, para no volver a preguntar.
nonisolated protocol RepositorioProductos: Sendable {
    func porCodigo(_ codigo: String) async throws -> ProductoCacheDato?

    /// Si el código ya estaba, se reemplaza: dos consultas del mismo producto caen en la
    /// misma fila.
    func guardar(_ dato: ProductoCacheDato) async throws
}
