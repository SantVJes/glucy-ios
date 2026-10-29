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

    private func enviar(ruta: String, cuerpo: Data) async throws -> Data {
        guard let base = configuracion.url, let token = almacen.token() else {
            throw ErrorBackend.sinConfiguracion
        }

        // La ruta va sin diagonal inicial: `appendingPathComponent` la agrega, y con dos
        // la dirección saldría con una doble.
        var peticion = URLRequest(url: base.appendingPathComponent(ruta))
        peticion.httpMethod = "POST"
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
}
