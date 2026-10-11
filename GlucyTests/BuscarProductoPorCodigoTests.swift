import Foundation
import Testing
@testable import Glucy

/// La búsqueda del producto y la cascada que sigue cuando no se resuelve. **Todo contra el
/// doble**: Open Food Facts no se consulta ni una vez.
@MainActor
struct BuscarProductoPorCodigoTests {

    private let ahora = Date(timeIntervalSince1970: 1_758_240_000)
    private let codigo = "3017620422003"

    private var galletas: Producto {
        Producto(
            codigoBarras: codigo, nombre: "Galletas María", marca: "Gamesa",
            carbsPor100g: 75, porcionSugeridaG: 30
        )
    }

    private func montar(
        conocidos: [Producto] = []
    ) throws -> (ContenedorDependencias, ProductosFalso) {
        let servicio = ProductosFalso(conocidos: conocidos)
        let dependencias = ContenedorDependencias(
            contenedor: try ContenedorGlucy.crear(enMemoria: true),
            servicioProductos: servicio
        )
        return (dependencias, servicio)
    }

    private func pantalla(_ dependencias: ContenedorDependencias) -> RegistroComidaViewModel {
        RegistroComidaViewModel(
            registrar: dependencias.registrarComida,
            buscar: dependencias.buscarProducto,
            ocr: OCRFalso()
        )
    }

    /// Prueba 2 · RF-12 — un código mal leído no gasta una de las 15 consultas del minuto.
    @Test("2 · RF-12: un código con el verificador mal se rechaza y no consulta")
    func codigoMalLeidoNoConsulta() async throws {
        let (dependencias, servicio) = try montar(conocidos: [galletas])

        let resultado = await dependencias.buscarProducto.ejecutar(codigo: "3017620422004", ahora: ahora)

        #expect(resultado == .codigoIlegible)
        #expect(await servicio.codigosConsultados.isEmpty)
    }

    /// Prueba 5 · RF-12 — de punta a punta, con el doble.
    @Test("5 · RF-12: un código conocido devuelve su producto")
    func codigoConocido() async throws {
        let (dependencias, servicio) = try montar(conocidos: [galletas])

        let resultado = await dependencias.buscarProducto.ejecutar(codigo: codigo, ahora: ahora)

        #expect(resultado == .encontrado(galletas, ultimaComida: nil))
        #expect(await servicio.codigosConsultados == [codigo])
    }

    /// Prueba 6 · RF-12.
    @Test("6 · RF-12: el segundo escaneo del mismo código no llama al servicio")
    func elSegundoEscaneoSaleDeLaCache() async throws {
        let (dependencias, servicio) = try montar(conocidos: [galletas])

        _ = await dependencias.buscarProducto.ejecutar(codigo: codigo, ahora: ahora)
        let segundo = await dependencias.buscarProducto.ejecutar(codigo: codigo, ahora: ahora)

        #expect(segundo == .encontrado(galletas, ultimaComida: nil))
        #expect(await servicio.codigosConsultados.count == 1, "la segunda vez salió a la red")

        // Y sale de la caché aunque después ya no haya red.
        await servicio.fallar(con: .sinRed)
        let sinRed = await dependencias.buscarProducto.ejecutar(codigo: codigo, ahora: ahora)
        #expect(sinRed == .encontrado(galletas, ultimaComida: nil))
    }

    /// Prueba 7 · RF-13 — «no lo conozco» tampoco se vuelve a preguntar enseguida, pero sí
    /// al día siguiente: lo que hoy no está puede estar mañana.
    @Test("7 · RF-13: el «no lo tengo» se cachea un día y después se vuelve a preguntar")
    func elNoEncontradoSeCacheaYCaduca() async throws {
        let (dependencias, servicio) = try montar()

        #expect(await dependencias.buscarProducto.ejecutar(codigo: codigo, ahora: ahora) == .noEncontrado)
        #expect(await dependencias.buscarProducto.ejecutar(codigo: codigo, ahora: ahora) == .noEncontrado)
        #expect(await servicio.codigosConsultados.count == 1)

        // Alguien lo dio de alta en la fuente; pasado un día el teléfono se entera.
        await servicio.conocer(galletas)
        let manana = ahora.addingTimeInterval(BuscarProductoPorCodigo.vigenciaDelNoEncontradoS + 60)
        let resultado = await dependencias.buscarProducto.ejecutar(codigo: codigo, ahora: manana)

        #expect(resultado == .encontrado(galletas, ultimaComida: nil))
        #expect(await servicio.codigosConsultados.count == 2)
    }

    /// «No pude preguntar» no dice nada del producto, así que no se guarda: al volver la
    /// red se pregunta de nuevo.
    @Test("P-10: un fallo de red no se cachea como «no lo tengo»")
    func elFalloDeRedNoSeCachea() async throws {
        let (dependencias, servicio) = try montar(conocidos: [galletas])
        await servicio.fallar(con: .fuenteFallo(codigoHttp: 503))

        let caido = await dependencias.buscarProducto.ejecutar(codigo: codigo, ahora: ahora)
        #expect(caido == .sinConsulta(.fuenteFallo(codigoHttp: 503)))
        #expect(try await dependencias.productos.porCodigo(codigo) == nil)
    }

    /// Prueba 9 · **P-10** — Open Food Facts caído. No hay callejón sin salida: se dice en
    /// una línea y el siguiente escalón, la foto de la etiqueta, queda a la vista.
    @Test("9 · P-10: sin red, el flujo llega a la foto de la etiqueta")
    func sinRedLlegaALaEtiqueta() async throws {
        let (dependencias, servicio) = try montar(conocidos: [galletas])
        await servicio.fallar(con: .sinRed)
        let modelo = pantalla(dependencias)
        modelo.abrirEscaner()

        await modelo.escaneado(codigo: codigo)

        #expect(modelo.ofreceFotoDeEtiqueta)
        #expect(modelo.aviso == RegistroComidaViewModel.Textos.sinConsulta)
        #expect(modelo.mostrandoEscaner == false)
        #expect(modelo.fallo == nil, "quedarse sin red no es un error")
        // Y nada se guardó por el camino.
        #expect(try await dependencias.comidas.contar() == 0)
    }

    /// Prueba 10 · P-10.
    @Test("10 · P-10: el tiempo agotado a los 5 s lleva al mismo sitio que sinRed")
    func tiempoAgotadoLlevaAlMismoSitio() async throws {
        #expect(ConfiguracionOpenFoodFacts.tiempoDeEsperaS == 5)

        let (dependencias, servicio) = try montar(conocidos: [galletas])
        await servicio.fallar(con: .tiempoAgotado)
        let modelo = pantalla(dependencias)
        modelo.abrirEscaner()

        await modelo.escaneado(codigo: codigo)

        #expect(modelo.ofreceFotoDeEtiqueta)
        #expect(modelo.aviso == RegistroComidaViewModel.Textos.sinConsulta)
        #expect(modelo.mostrandoEscaner == false)
    }

    /// RF-13 — el producto no existe: mismo escalón, otro texto.
    @Test("RF-13: un código que la base no conoce lleva a la foto de la etiqueta")
    func noEncontradoLlevaALaEtiqueta() async throws {
        let (dependencias, _) = try montar()
        let modelo = pantalla(dependencias)

        await modelo.escaneado(codigo: codigo)

        #expect(modelo.ofreceFotoDeEtiqueta)
        #expect(modelo.aviso == RegistroComidaViewModel.Textos.noEncontrado)
    }

    /// Un código mal leído deja el escáner abierto para volver a leer.
    @Test("RF-12: un código mal leído no cierra el escáner")
    func codigoMalLeidoNoCierraElEscaner() async throws {
        let (dependencias, _) = try montar()
        let modelo = pantalla(dependencias)
        modelo.abrirEscaner()

        await modelo.escaneado(codigo: "3017620422004")

        #expect(modelo.mostrandoEscaner)
        #expect(modelo.avisoDelEscaner == RegistroComidaViewModel.Textos.codigoIlegible)
        #expect(modelo.ofreceFotoDeEtiqueta == false)
    }
}
