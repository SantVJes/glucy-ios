import Foundation

/// Lo que hace falta para hablar con Open Food Facts, en un solo lugar. Ni la dirección ni
/// el correo se escriben en ningún otro archivo.
nonisolated enum ConfiguracionOpenFoodFacts {
    static let urlBase = "https://world.openfoodfacts.org"

    /// Solo lo que la app usa: la respuesta completa de un producto pesa cientos de kB.
    static let campos = "code,product_name,brands,nutriments,serving_size"

    /// El repositorio es público, así que este correo queda indexado: es uno de contacto
    /// del proyecto, no el personal de nadie.
    static let correoDeContacto = "PENDIENTE"

    /// Obligatorio. Una petición sin `User-Agent` propio puede quedar bloqueada.
    static let agenteDeUsuario = "Glucy/1.0 (\(correoDeContacto))"

    /// Cinco segundos y no los sesenta del sistema: nadie de pie en una cocina espera a que
    /// cargue una bolsa de pan, y la foto de la etiqueta está ahí mismo.
    static let tiempoDeEsperaS: TimeInterval = 5
}

/// Open Food Facts de verdad.
///
/// La consulta sale **del teléfono de cada persona**, nunca del servidor en nombre de todas:
/// el límite es de 15 por minuto y por IP.
nonisolated struct OpenFoodFactsHTTP: ServicioProductos {
    private let sesion: URLSession

    init() {
        let configuracion = URLSessionConfiguration.ephemeral
        configuracion.timeoutIntervalForRequest = ConfiguracionOpenFoodFacts.tiempoDeEsperaS
        // También el total: sin esto, una respuesta que llega a goteo puede tardar mucho
        // más de cinco segundos sin que ningún tramo se pase del límite.
        configuracion.timeoutIntervalForResource = ConfiguracionOpenFoodFacts.tiempoDeEsperaS
        sesion = URLSession(configuration: configuracion)
    }

    func producto(codigo: String) async throws -> Producto? {
        // El código va en la ruta. Llega ya validado, pero aquí se vuelve a exigir que sean
        // solo dígitos: es lo que impide que algo raro termine dentro de la dirección.
        guard !codigo.isEmpty, codigo.allSatisfy({ $0.isASCII && $0.isNumber }),
              var componentes = URLComponents(string: ConfiguracionOpenFoodFacts.urlBase) else {
            return nil
        }
        componentes.path = "/api/v2/product/\(codigo).json"
        componentes.queryItems = [
            URLQueryItem(name: "fields", value: ConfiguracionOpenFoodFacts.campos)
        ]
        guard let url = componentes.url else { return nil }

        var peticion = URLRequest(url: url)
        peticion.timeoutInterval = ConfiguracionOpenFoodFacts.tiempoDeEsperaS
        peticion.setValue(
            ConfiguracionOpenFoodFacts.agenteDeUsuario, forHTTPHeaderField: "User-Agent"
        )

        let datos: Data
        let respuesta: URLResponse
        do {
            (datos, respuesta) = try await sesion.data(for: peticion)
        } catch let error as URLError where error.code == .timedOut {
            throw ErrorProductos.tiempoAgotado
        } catch {
            throw ErrorProductos.sinRed
        }

        guard let http = respuesta as? HTTPURLResponse else {
            throw ErrorProductos.respuestaIlegible
        }
        switch http.statusCode {
        case 200:
            return try Self.producto(desde: datos, codigo: codigo)
        case 404:
            // Así contesta la fuente cuando no conoce el código.
            return nil
        default:
            throw ErrorProductos.fuenteFallo(codigoHttp: http.statusCode)
        }
    }

    /// Traduce la respuesta. Vive aparte de la petición para poder probarse con un JSON
    /// escrito a mano, sin salir a la red.
    static func producto(desde datos: Data, codigo: String) throws -> Producto? {
        guard let respuesta = try? JSONDecoder().decode(Respuesta.self, from: datos) else {
            throw ErrorProductos.respuestaIlegible
        }
        guard respuesta.status?.valor != 0, let producto = respuesta.product else { return nil }

        // Sin carbohidratos el producto no sirve para lo único que se le pide, así que es
        // lo mismo que no tenerlo (RF-13). Y más de 100 g en 100 g no es un dato: es un
        // error de quien lo capturó.
        guard let carbs = producto.nutriments?.carbohidratosPor100g?.valor,
              (0...100).contains(carbs) else { return nil }

        let marca = producto.brands?.trimmingCharacters(in: .whitespaces)
        let nombre = producto.productName?.trimmingCharacters(in: .whitespaces)

        return Producto(
            codigoBarras: codigo,
            nombre: [nombre, marca].compactMap { $0 }.first { !$0.isEmpty }
                ?? "Producto sin nombre",
            marca: marca.flatMap { $0.isEmpty ? nil : $0 },
            carbsPor100g: carbs,
            porcionSugeridaG: producto.servingSize.flatMap(gramos(deLaPorcion:))
        )
    }

    /// Los gramos que dice un `serving_size`, o `nil` si no los dice en gramos.
    ///
    /// El campo es texto libre: «30 g», «1 taza (240 ml)», «2 galletas», vacío. Solo se
    /// acepta un número seguido de gramos. Todo lo demás es `nil`, y `nil` quiere decir que
    /// se le pregunta a la persona: **nunca se convierte, se estima ni se supone**.
    static func gramos(deLaPorcion texto: String) -> Double? {
        let patron = /(\d+(?:[.,]\d+)?)\s*(?:g|gr|grs|gramos)\b/.ignoresCase()
        guard let hallado = texto.firstMatch(of: patron),
              let gramos = Double(hallado.1.replacingOccurrences(of: ",", with: ".")),
              gramos > 0 else { return nil }
        return gramos
    }
}

// MARK: - La forma de la respuesta

private nonisolated struct Respuesta: Decodable {
    let status: NumeroFlexible?
    let product: ProductoPublicado?
}

private nonisolated struct ProductoPublicado: Decodable {
    let productName: String?
    let brands: String?
    let servingSize: String?
    let nutriments: Nutrimentos?

    enum CodingKeys: String, CodingKey {
        case productName = "product_name"
        case brands
        case servingSize = "serving_size"
        case nutriments
    }
}

private nonisolated struct Nutrimentos: Decodable {
    let carbohidratosPor100g: NumeroFlexible?

    enum CodingKeys: String, CodingKey {
        case carbohidratosPor100g = "carbohydrates_100g"
    }
}

/// La fuente la captura gente voluntaria y el mismo campo llega a veces como número y a
/// veces como texto.
private nonisolated struct NumeroFlexible: Decodable {
    let valor: Double?

    init(from decoder: any Decoder) throws {
        let contenedor = try decoder.singleValueContainer()
        if let numero = try? contenedor.decode(Double.self) {
            valor = numero
        } else if let texto = try? contenedor.decode(String.self) {
            valor = Double(texto.replacingOccurrences(of: ",", with: "."))
        } else {
            valor = nil
        }
    }
}
