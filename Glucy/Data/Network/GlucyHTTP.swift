import Foundation

/// El backend de Glucy de verdad, por HTTP.
///
/// Tres cosas que no son obvias y están aquí a propósito:
///
/// 1. **Las fechas se codifican con offset obligatorio.** Una marca de tiempo sin offset el
///    servidor la manda a cuarentena en lugar de suponer UTC: suponerlo acertaría casi
///    siempre y desplazaría la serie seis horas el resto de las veces, sin que nada fallara
///    (decisión 2.10 del paso 1 del backend).
/// 2. **El token se lee en cada petición**, no al construir el cliente: si se renueva a
///    media sincronización, el lote siguiente ya sale con el nuevo.
/// 3. **El cuerpo de un error no se enseña nunca.** Se guarda su texto en la cola para poder
///    diagnosticar, pero lo que la persona ve es una frase de la app.
nonisolated struct GlucyHTTP: ClienteBackend {
    private let configuracion: ConfiguracionBackend
    private let almacen: any AlmacenDeToken
    private let sesion: URLSession

    init(
        configuracion: ConfiguracionBackend,
        almacen: any AlmacenDeToken = Llavero(),
        sesion: URLSession? = nil
    ) {
        self.configuracion = configuracion
        self.almacen = almacen
        if let sesion {
            self.sesion = sesion
        } else {
            let ajustes = URLSessionConfiguration.ephemeral
            ajustes.timeoutIntervalForRequest = configuracion.timeoutSegundos
            ajustes.timeoutIntervalForResource = configuracion.timeoutSegundos
            // Aquí **no** se pone `allowsExpensiveNetworkAccess = false`, aunque suene a lo
            // que pide la regla del wifi. Esa bandera bloquea los datos móviles en la capa
            // del sistema, y entonces «sincronizar ahora» —que es justo lo único que tiene
            // permiso de usarlos (caso P-08)— no funcionaría. La regla la decide
            // `DecisionSincronizacion` antes de llegar aquí, que es donde se puede
            // distinguir una ventana automática de un botón que la persona tocó.
            self.sesion = URLSession(configuration: ajustes)
        }
    }

    // MARK: - Los cuatro envíos

    func subirLecturas(_ items: [LecturaSubida]) async throws -> RespuestaLote {
        try await lote(ruta: "readings", items: items)
    }

    func subirComidas(_ items: [ComidaSubida]) async throws -> RespuestaLote {
        try await lote(ruta: "meals", items: items)
    }

    func subirDosis(_ items: [DosisSubida]) async throws -> RespuestaLote {
        try await lote(ruta: "insulin", items: items)
    }

    func subirPerfil(_ perfil: PerfilSubido) async throws {
        let cuerpo = try Self.codificador.encode(perfil)
        _ = try await enviar(ruta: "perfil", cuerpo: cuerpo)
    }

    // MARK: - Los factores y la explicación

    func pedirPrediccion() async throws -> PrediccionRemota {
        let datos = try await enviar(ruta: "predict", metodo: "GET", cuerpo: nil)
        return try Self.prediccion(desde: datos)
    }

    func pedirExplicacion(_ entrada: ExplicacionPedida) async throws -> ExplicacionRemota {
        // Se comprueba aquí y no se manda: un `400` no se reintenta, así que un sobre que el
        // servidor va a rechazar sería una explicación perdida sin nada que la explique.
        guard entrada.sirveParaMandar else {
            throw ErrorBackend.sobreInvalido(
                detalle: "el sobre de /explain lleva \(entrada.shap.count) contribuciones y "
                    + "hora_local \(entrada.horaLocal)"
            )
        }
        let cuerpo = try Self.codificador.encode(entrada)
        let datos = try await enviar(ruta: "explain", cuerpo: cuerpo)
        do {
            return try Self.decodificador.decode(ExplicacionRemota.self, from: datos)
        } catch {
            throw ErrorBackend.respuestaIlegible
        }
    }

    /// La traducción de lo que contesta `GET /predict`, aparte y pura para poder probarla
    /// sobre respuestas escritas a mano, sin red y sin servidor.
    static func prediccion(desde datos: Data) throws -> PrediccionRemota {
        do {
            return try decodificadorConFechas.decode(PrediccionRemota.self, from: datos)
        } catch {
            throw ErrorBackend.respuestaIlegible
        }
    }

    // MARK: - El trabajo común

    private func lote<Renglon: Encodable & Sendable>(
        ruta: String, items: [Renglon]
    ) async throws -> RespuestaLote {
        let cuerpo = try Self.codificador.encode(Lote(items: items))
        let datos = try await enviar(ruta: ruta, cuerpo: cuerpo)
        do {
            return try Self.decodificador.decode(RespuestaLote.self, from: datos)
        } catch {
            throw ErrorBackend.respuestaIlegible
        }
    }

    private func enviar(
        ruta: String, metodo: String = "POST", cuerpo: Data?
    ) async throws -> Data {
        guard let base = configuracion.url, let token = almacen.token() else {
            throw ErrorBackend.sinConfiguracion
        }

        // La ruta va sin diagonal inicial: `appendingPathComponent` la agrega, y con dos
        // la dirección saldría con una doble.
        var peticion = URLRequest(url: base.appendingPathComponent(ruta))
        peticion.httpMethod = metodo
        peticion.httpBody = cuerpo
        peticion.timeoutInterval = configuracion.timeoutSegundos
        peticion.setValue("application/json", forHTTPHeaderField: "Content-Type")
        peticion.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let datos: Data
        let respuesta: URLResponse
        do {
            (datos, respuesta) = try await sesion.data(for: peticion)
        } catch {
            // Sin red, modo avión o tiempo agotado: el lote se queda en la cola. En modo
            // avión esto es lo normal y no una falla (caso P-07).
            throw ErrorBackend.sinRed
        }

        guard let http = respuesta as? HTTPURLResponse else {
            throw ErrorBackend.respuestaIlegible
        }

        return try Self.resultado(codigoHttp: http.statusCode, datos: datos)
    }

    /// Qué hace el teléfono con cada código. Es una función aparte y pura para poder
    /// probarla sin red: la tabla de errores del contrato es justo lo que no se puede
    /// equivocar, y una prueba que necesite servidor no se corre en cada cambio.
    static func resultado(codigoHttp: Int, datos: Data) throws -> Data {
        switch codigoHttp {
        case 200...299:
            return datos
        case 400:
            throw ErrorBackend.sobreInvalido(detalle: detalle(de: datos))
        case 401:
            throw ErrorBackend.tokenRechazado
        case 409:
            // El servidor no lo usa en los lotes —un uuid repetido es duplicado, no
            // conflicto— pero si llegara, se trata como duplicado y no como falla.
            return datos
        default:
            throw ErrorBackend.servidorFallo(codigoHttp: codigoHttp)
        }
    }

    /// El `detail` de FastAPI, recortado. Va a la cola para poder diagnosticar, nunca a la
    /// pantalla.
    private static func detalle(de datos: Data) -> String {
        guard let texto = String(data: datos, encoding: .utf8), !texto.isEmpty else {
            return "sin detalle"
        }
        return String(texto.prefix(500))
    }

    // MARK: - Codificación

    /// ISO 8601 con offset. `JSONEncoder.DateEncodingStrategy.iso8601` también lo pone, pero
    /// escribirlo así deja claro cuál es el requisito y no deja que un cambio de valor por
    /// omisión de la plataforma rompa el contrato en silencio.
    ///
    /// `Date.ISO8601FormatStyle` y no `ISO8601DateFormatter`: el primero es una `struct`
    /// `Sendable` y el segundo una clase, que como `static let` no pasa la concurrencia
    /// estricta de Swift 6.
    static let formatoDeFecha = Date.ISO8601FormatStyle(
        includingFractionalSeconds: true, timeZone: .gmt
    )

    /// Instancia nueva en cada uso. `JSONEncoder` es una clase con estado mutable: como
    /// `static let` compartida entre tareas sería justo la carrera que la concurrencia
    /// estricta existe para encontrar.
    static var codificador: JSONEncoder {
        let codificador = JSONEncoder()
        codificador.dateEncodingStrategy = .custom { fecha, codificadorDeFecha in
            var contenedor = codificadorDeFecha.singleValueContainer()
            try contenedor.encode(fecha.formatted(formatoDeFecha))
        }
        return codificador
    }

    static var decodificador: JSONDecoder { JSONDecoder() }

    /// El decodificador de las respuestas que traen fechas, que son las de `/predict`.
    ///
    /// Se prueban las dos formas porque FastAPI escribe la fracción de segundo solo cuando el
    /// valor la tiene: `ts_objetivo` sale de una suma y suele llegar en punto, mientras
    /// `ts_utc` trae microsegundos. Un decodificador que exija una sola forma falla en la
    /// mitad de los campos y la respuesta entera se vuelve ilegible.
    static var decodificadorConFechas: JSONDecoder {
        let decodificador = JSONDecoder()
        decodificador.dateDecodingStrategy = .custom { desdeElJson in
            let texto = try desdeElJson.singleValueContainer().decode(String.self)
            guard let leida = fecha(desde: texto) else {
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(
                        codingPath: desdeElJson.codingPath,
                        debugDescription: "no es una fecha ISO 8601: \(texto)"
                    )
                )
            }
            return leida
        }
        return decodificador
    }

    /// ISO 8601 con offset, con fracción de segundo o sin ella.
    ///
    /// Si el texto no trae zona se toma como UTC, y eso **no** contradice la regla de no
    /// suponerla: aquí se está leyendo al servidor de Glucy, que guarda y responde todo en UTC
    /// y rechaza una marca sin zona en la entrada. Suponerla al subir sería distinto, porque
    /// del otro lado hay un teléfono que puede estar en cualquier parte.
    static func fecha(desde texto: String) -> Date? {
        let recortado = recortarFraccion(texto)

        let conFraccion = ISO8601DateFormatter()
        conFraccion.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let leida = conFraccion.date(from: recortado) { return leida }

        let sinFraccion = ISO8601DateFormatter()
        sinFraccion.formatOptions = [.withInternetDateTime]
        if let leida = sinFraccion.date(from: recortado) { return leida }

        // Sin zona: se reintenta como UTC, una sola vez. La «Z» que se agrega es lo que
        // corta la recursión.
        guard let ultimo = recortado.last, ultimo != "Z", !recortado.contains("+") else {
            return nil
        }
        return fecha(desde: recortado + "Z")
    }

    /// Recorta la fracción de segundo a tres dígitos.
    ///
    /// Python escribe seis —microsegundos— y `ISO8601DateFormatter` con `.withFractionalSeconds`
    /// **no los acepta**: devuelve `nil`, no un valor aproximado. Sin este recorte la respuesta
    /// entera de `/predict` se volvería ilegible por tres ceros de más, y la pantalla de
    /// factores se quedaría vacía sin que nada fallara. Lo que se pierde son microsegundos de
    /// una marca de tiempo que la app enseña al minuto.
    static func recortarFraccion(_ texto: String) -> String {
        guard let punto = texto.firstIndex(of: ".") else { return texto }
        let desdeElPunto = texto[texto.index(after: punto)...]
        let digitos = desdeElPunto.prefix { $0.isNumber }
        guard digitos.count > 3 else { return texto }
        let resto = desdeElPunto.dropFirst(digitos.count)
        return String(texto[..<punto]) + "." + String(digitos.prefix(3)) + String(resto)
    }
}
