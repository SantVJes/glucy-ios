import Foundation
import Testing
@testable import Glucy

/// La traducción de lo que contesta Open Food Facts, sobre respuestas **escritas a mano**.
/// Aquí no hay red: la petición de verdad no se ejecuta en ninguna prueba.
struct OpenFoodFactsHTTPTests {

    private func traducir(_ json: String, codigo: String = "3017620422003") throws -> Producto? {
        try OpenFoodFactsHTTP.producto(desde: Data(json.utf8), codigo: codigo)
    }

    /// Prueba 5 · RF-12.
    @Test("5 · RF-12: un producto conocido se traduce a Producto con sus carbohidratos")
    func productoConocido() throws {
        let producto = try #require(try traducir("""
        {"code":"3017620422003","status":1,"product":{
          "product_name":"Nutella","brands":"Ferrero","serving_size":"15 g",
          "nutriments":{"carbohydrates_100g":57.5,"sugars_100g":56.3}}}
        """))

        #expect(producto.codigoBarras == "3017620422003")
        #expect(producto.nombre == "Nutella")
        #expect(producto.marca == "Ferrero")
        #expect(producto.carbsPor100g == 57.5)
        #expect(producto.porcionSugeridaG == 15)

        // La fuente la captura gente voluntaria: el mismo campo llega a veces como texto.
        let comoTexto = try traducir("""
        {"status":1,"product":{"product_name":"Pan","nutriments":{"carbohydrates_100g":"49,2"}}}
        """)
        #expect(comoTexto?.carbsPor100g == 49.2)
        #expect(comoTexto?.marca == nil)
    }

    /// Prueba 7 · RF-13 — «no lo conozco» no es una falla.
    @Test("7 · RF-13: status 0 devuelve nil y no lanza")
    func statusCeroDevuelveNil() throws {
        #expect(try traducir("""
        {"code":"3017620422003","status":0,"status_verbose":"product not found"}
        """) == nil)
    }

    /// Prueba 8 · RF-13 — un producto sin carbohidratos no sirve para lo único que se le
    /// pide.
    @Test("8 · RF-13: un producto sin carbohidratos devuelve nil, igual que si no existiera")
    func sinCarbohidratosDevuelveNil() throws {
        #expect(try traducir("""
        {"status":1,"product":{"product_name":"Agua","nutriments":{"salt_100g":0.01}}}
        """) == nil)
        #expect(try traducir("""
        {"status":1,"product":{"product_name":"Sin tabla"}}
        """) == nil)
        // Más de 100 g en 100 g no es un dato, es un error de captura.
        #expect(try traducir("""
        {"status":1,"product":{"product_name":"Mal","nutriments":{"carbohydrates_100g":750}}}
        """) == nil)
    }

    @Test("Una respuesta que no es JSON lanza respuestaIlegible, no devuelve nil")
    func respuestaIlegible() {
        #expect(throws: ErrorProductos.respuestaIlegible) {
            try traducir("<html>502 Bad Gateway</html>")
        }
    }

    /// `serving_size` es texto libre. Solo se acepta lo que dice gramos; todo lo demás es
    /// `nil`, y `nil` quiere decir que se le pregunta a la persona.
    @Test("RF-37: la porción solo se toma si viene en gramos; nunca se convierte ni se supone")
    func laPorcionSoloEnGramos() {
        #expect(OpenFoodFactsHTTP.gramos(deLaPorcion: "30 g") == 30)
        #expect(OpenFoodFactsHTTP.gramos(deLaPorcion: "30g") == 30)
        #expect(OpenFoodFactsHTTP.gramos(deLaPorcion: "2 galletas (27,5 g)") == 27.5)
        #expect(OpenFoodFactsHTTP.gramos(deLaPorcion: "1 rebanada (28 gramos)") == 28)

        #expect(OpenFoodFactsHTTP.gramos(deLaPorcion: "1 taza (240 ml)") == nil)
        #expect(OpenFoodFactsHTTP.gramos(deLaPorcion: "2 galletas") == nil)
        #expect(OpenFoodFactsHTTP.gramos(deLaPorcion: "") == nil)
        #expect(OpenFoodFactsHTTP.gramos(deLaPorcion: "0 g") == nil)
        #expect(OpenFoodFactsHTTP.gramos(deLaPorcion: "0.5 kg") == nil)
    }

    /// El `User-Agent` es obligatorio y sale de una constante, junto a la URL base.
    @Test("El User-Agent lleva el nombre de la app y un correo de contacto de verdad")
    func agenteDeUsuario() {
        #expect(ConfiguracionOpenFoodFacts.agenteDeUsuario.hasPrefix("Glucy/1.0 ("))
        #expect(ConfiguracionOpenFoodFacts.correoDeContacto.contains("@"))
        #expect(ConfiguracionOpenFoodFacts.tiempoDeEsperaS == 5)
    }
}
