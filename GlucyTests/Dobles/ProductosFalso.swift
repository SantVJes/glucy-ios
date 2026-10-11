import Foundation
@testable import Glucy

/// Una base de productos de mentira. **Ninguna prueba consulta Open Food Facts de verdad**:
/// el límite es de 15 consultas por minuto y por IP, y una prueba que depende de internet
/// falla por razones que no son el código.
///
/// Devuelve lo que la prueba le diga, incluido fallar, y lleva la cuenta de qué se le
/// preguntó: así se comprueba que un código mal leído o ya cacheado no salió a la red.
actor ProductosFalso: ServicioProductos {
    private var conocidos: [String: Producto] = [:]
    private var fallo: ErrorProductos?
    private(set) var codigosConsultados: [String] = []

    init(conocidos: [Producto] = []) {
        for producto in conocidos {
            self.conocidos[producto.codigoBarras] = producto
        }
    }

    func conocer(_ producto: Producto) {
        conocidos[producto.codigoBarras] = producto
    }

    func fallar(con error: ErrorProductos) {
        fallo = error
    }

    func producto(codigo: String) async throws -> Producto? {
        codigosConsultados.append(codigo)
        if let fallo { throw fallo }
        return conocidos[codigo]
    }
}
