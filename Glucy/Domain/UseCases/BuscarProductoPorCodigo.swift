import Foundation

/// Lo que salió de buscar un código de barras.
///
/// Ninguno de los cuatro es un error para la persona: los tres últimos bajan al siguiente
/// escalón de la cascada (caso P-10).
nonisolated enum ResultadoBusqueda: Sendable, Equatable {
    /// - Parameter ultimaComida: la última vez que la persona registró este mismo código,
    ///   para ofrecerle las mismas porciones.
    case encontrado(Producto, ultimaComida: ComidaDato?)
    /// El dígito verificador no cuadra: se leyó mal y se vuelve a leer, sin salir a la red.
    case codigoIlegible
    /// La fuente contestó que no lo conoce, o lo conoce sin carbohidratos.
    case noEncontrado
    /// No se pudo preguntar.
    case sinConsulta(ErrorProductos)
}

/// Buscar un producto por su código de barras: primero en el teléfono, después en la red.
///
/// **Este caso de uso no crea ninguna comida.** Solo averigua qué producto es; la comida la
/// registra la persona, y el único camino para eso es `RegistrarComida` (RF-37).
nonisolated struct BuscarProductoPorCodigo: Sendable {
    let servicio: any ServicioProductos
    let cache: any RepositorioProductos
    let comidas: any RepositorioComidas

    /// Un «no lo tengo» se vuelve a preguntar pasado un día. Open Food Facts lo llena gente
    /// voluntaria: el producto que hoy no está puede estar mañana, y sin caducidad el
    /// teléfono seguiría contestando que no para siempre.
    static let vigenciaDelNoEncontradoS: TimeInterval = 24 * 3600

    func ejecutar(codigo: String, ahora: Date = Date()) async -> ResultadoBusqueda {
        guard CodigoBarras.esValido(codigo) else { return .codigoIlegible }

        // Si la caché falla se sigue como si no hubiera nada: es una copia, no la fuente.
        if let guardado = try? await cache.porCodigo(codigo) {
            if let producto = guardado.producto {
                return await encontrado(producto)
            }
            if ahora.timeIntervalSince(guardado.consultadoTsUtc) < Self.vigenciaDelNoEncontradoS {
                return .noEncontrado
            }
        }

        do {
            guard let producto = try await servicio.producto(codigo: codigo) else {
                try? await cache.guardar(
                    ProductoCacheDato(noEncontrado: codigo, consultadoTsUtc: ahora)
                )
                return .noEncontrado
            }
            try? await cache.guardar(ProductoCacheDato(producto: producto, consultadoTsUtc: ahora))
            return await encontrado(producto)
        } catch let error as ErrorProductos {
            // «No pude preguntar» **no** se guarda en la caché: no dice nada del producto.
            return .sinConsulta(error)
        } catch {
            return .sinConsulta(.respuestaIlegible)
        }
    }

    private func encontrado(_ producto: Producto) async -> ResultadoBusqueda {
        let ultima = try? await comidas.ultimaConCodigo(producto.codigoBarras)
        return .encontrado(producto, ultimaComida: ultima)
    }
}
