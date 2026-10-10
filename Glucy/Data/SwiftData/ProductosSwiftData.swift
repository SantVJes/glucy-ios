import Foundation
import SwiftData

/// La caché de productos sobre SwiftData.
@ModelActor
actor ProductosSwiftData: RepositorioProductos {

    func porCodigo(_ codigo: String) throws -> ProductoCacheDato? {
        try fila(codigo)?.dato
    }

    func guardar(_ dato: ProductoCacheDato) throws {
        if let existente = try fila(dato.codigoBarras) {
            existente.encontrado = dato.encontrado
            existente.nombre = dato.nombre
            existente.marca = dato.marca
            existente.carbsPor100g = dato.carbsPor100g
            existente.porcionSugeridaG = dato.porcionSugeridaG
            existente.consultadoTsUtc = dato.consultadoTsUtc
            existente.zonaHoraria = dato.zonaHoraria
        } else {
            // Sin encolar: la caché nace `local` y no sube (grupo C).
            modelContext.insert(ProductoCache(
                codigoBarras: dato.codigoBarras,
                nombre: dato.nombre,
                marca: dato.marca,
                carbsPor100g: dato.carbsPor100g,
                porcionSugeridaG: dato.porcionSugeridaG,
                encontrado: dato.encontrado,
                consultadoTsUtc: dato.consultadoTsUtc,
                zonaHoraria: dato.zonaHoraria
            ))
        }
        try modelContext.save()
    }

    private func fila(_ codigo: String) throws -> ProductoCache? {
        var descriptor = FetchDescriptor<ProductoCache>(
            predicate: #Predicate { $0.codigoBarras == codigo }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }
}

extension ProductoCache {
    var dato: ProductoCacheDato {
        ProductoCacheDato(
            codigoBarras: codigoBarras,
            encontrado: encontrado,
            nombre: nombre,
            marca: marca,
            carbsPor100g: carbsPor100g,
            porcionSugeridaG: porcionSugeridaG,
            consultadoTsUtc: consultadoTsUtc,
            zonaHoraria: zonaHoraria
        )
    }
}
