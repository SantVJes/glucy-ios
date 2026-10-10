import CoreGraphics
import Foundation
import Testing
@testable import Glucy

/// El registro de una comida. Aquí se comprueba lo que no se negocia: **nunca se supone una
/// porción de 100 g**, el tiempo de absorción no se pregunta, y nada se guarda sin pasar
/// por `RegistrarComida`.
@MainActor
struct RegistrarComidaTests {

    private let ahora = Date(timeIntervalSince1970: 1_758_240_000)
    private let codigo = "3017620422003"

    private func producto(porcionG: Double?) -> Producto {
        Producto(
            codigoBarras: codigo, nombre: "Galletas María", marca: "Gamesa",
            carbsPor100g: 75, porcionSugeridaG: porcionG
        )
    }

    private func montar(
        conocidos: [Producto] = [], ocr: OCRFalso = OCRFalso()
    ) throws -> (RegistroComidaViewModel, ContenedorDependencias) {
        let dependencias = ContenedorDependencias(
            contenedor: try ContenedorGlucy.crear(enMemoria: true),
            servicioProductos: ProductosFalso(conocidos: conocidos)
        )
        let modelo = RegistroComidaViewModel(
            registrar: dependencias.registrarComida,
            buscar: dependencias.buscarProducto,
            ocr: ocr
        )
        return (modelo, dependencias)
    }

    private func unica(_ dependencias: ContenedorDependencias) async throws -> ComidaDato {
        let comidas = try await dependencias.comidas.recientes(
            horas: 24, hasta: Date().addingTimeInterval(60)
        )
        #expect(comidas.count == 1)
        return try #require(comidas.first)
    }

    /// Prueba 15 · RF-12 — la cuenta, con sus tres factores.
    @Test("15 · RF-12: 75 g por 100 g, porción de 30 g, 2 porciones = 45 g")
    func laCuentaDeLaPorcion() async throws {
        #expect(Carbohidratos.deProducto(carbsPor100g: 75, porcionG: 30, porciones: 2) == 45)

        // Y de punta a punta: escanear, decir que fueron dos y guardar.
        let (modelo, dependencias) = try montar(conocidos: [producto(porcionG: 30)])
        await modelo.escaneado(codigo: codigo)

        #expect(modelo.textoPorcionG == "30")     // la que dio la fuente, visible y editable
        #expect(modelo.carbohidratos == 22.5)     // una porción, que es lo que hay escrito
        modelo.textoPorciones = "2"
        #expect(modelo.carbohidratos == 45)
        #expect(modelo.desglose == "30 g por porción × 2 porciones · 75 g por 100 g")

        await modelo.guardar()

        let guardada = try await unica(dependencias)
        #expect(guardada.carbsG == 45)
        #expect(guardada.porcionG == 30)
        #expect(guardada.porciones == 2)
        #expect(guardada.codigoBarras == codigo)
        #expect(guardada.nombreProducto == "Galletas María")
        #expect(guardada.confirmadaPorUsuario)
    }

    /// Prueba 16 · RF-37 — la trampa que puede hacer daño. Si la porción de verdad son 30 g,
    /// suponer 100 triplica los carbohidratos, y eso entra al COB y a la predicción.
    @Test("16 · RF-37: sin porción en gramos no se puede guardar; nunca se supone 100 g")
    func sinPorcionNoSeGuarda() async throws {
        // La regla: sin porción no hay cifra. Ni 75, que sería haber supuesto 100 g.
        #expect(Carbohidratos.deProducto(carbsPor100g: 75, porcionG: nil, porciones: 1) == nil)
        #expect(Carbohidratos.deProducto(carbsPor100g: 75, porcionG: 0, porciones: 1) == nil)

        // La pantalla: la fuente no dio los gramos, así que el campo sale vacío.
        let (modelo, dependencias) = try montar(conocidos: [producto(porcionG: nil)])
        await modelo.escaneado(codigo: codigo)

        #expect(modelo.textoPorcionG.isEmpty)
        #expect(modelo.faltaLaPorcion)
        #expect(modelo.carbohidratos == nil)
        #expect(modelo.sePuedeGuardar == false)

        // Aunque alguien llame a guardar con el botón deshabilitado, no se guarda.
        await modelo.guardar()
        #expect(modelo.fallo == .porcionSinGramos)
        #expect(try await dependencias.comidas.contar() == 0)

        // Y el caso de uso tampoco lo deja pasar, lo llame quien lo llame.
        await #expect(throws: FalloRegistro.porcionSinGramos) {
            try await dependencias.registrarComida.ejecutar(
                carbsG: 75, tsUtc: ahora, origen: .barcode,
                codigoBarras: codigo, porcionG: nil, ahora: ahora
            )
        }
        #expect(try await dependencias.comidas.contar() == 0)

        // En cuanto la persona la dice, sí.
        modelo.textoPorcionG = "30"
        #expect(modelo.carbohidratos == 22.5)
        await modelo.guardar()
        #expect(try await unica(dependencias).carbsG == 22.5)
    }

    /// La segunda vez que se escanea el mismo producto se ofrece lo que la persona dijo la
    /// primera. Es algo que ella dijo, no algo que la app suponga.
    @Test("RF-12: al repetir un producto se ofrecen la porción y las porciones de la última vez")
    func seOfreceLoDeLaUltimaVez() async throws {
        let (modelo, _) = try montar(conocidos: [producto(porcionG: nil)])
        await modelo.escaneado(codigo: codigo)
        modelo.textoPorcionG = "28"
        modelo.textoPorciones = "1.5"
        await modelo.guardar()

        await modelo.escaneado(codigo: codigo)

        #expect(modelo.textoPorcionG == "28")
        #expect(modelo.textoPorciones == "1.5")
    }

    /// Prueba 17 · RF-12b — no se pregunta: quien no toca nada guarda 180.
    @Test("17 · RF-12b: una comida sin tocar la absorción se guarda con 180")
    func sinTocarLaAbsorcionSon180() async throws {
        let (modelo, dependencias) = try montar()

        // Los tres chips viven detrás de «Ajustar»: sin tocarlo, no están a la vista.
        #expect(modelo.ajustandoAbsorcion == false)
        #expect(modelo.absorcion == .normal)

        modelo.textoCarbs = "60"
        await modelo.guardar()

        let guardada = try await unica(dependencias)
        #expect(guardada.tiempoAbsorcionMin == 180)
        #expect(guardada.tiempoAbsorcionMin == ConfiguracionDominio.absorcionPorOmisionMin)
        #expect(guardada.origen == .manual)
        #expect(guardada.carbsG == 60)
    }

    /// Prueba 18 · RF-12b — los minutos quedan en la comida, no solo en el perfil.
    @Test("18 · RF-12b: con «Lenta» se guarda con 300, y queda en la comida")
    func conLentaSon300() async throws {
        #expect(OpcionAbsorcion.allCases.map(\.minutos) == [30, 180, 300])

        let (modelo, dependencias) = try montar()
        modelo.textoCarbs = "80"
        modelo.ajustandoAbsorcion = true
        modelo.absorcion = .lenta
        await modelo.guardar()

        #expect(try await unica(dependencias).tiempoAbsorcionMin == 300)

        // La siguiente vuelve a los 180 sin preguntar.
        #expect(modelo.absorcion == .normal)
        #expect(modelo.ajustandoAbsorcion == false)
    }

    /// Prueba 19 · RF-05.
    @Test("19 · RF-05: 350 g de carbohidratos no se guarda")
    func trescientosCincuentaNoSeGuarda() async throws {
        let (modelo, dependencias) = try montar()

        await #expect(throws: FalloRegistro.carbohidratosFueraDeRango) {
            try await dependencias.registrarComida.ejecutar(
                carbsG: 350, tsUtc: ahora, origen: .manual, ahora: ahora
            )
        }
        await #expect(throws: FalloRegistro.carbohidratosFueraDeRango) {
            try await dependencias.registrarComida.ejecutar(
                carbsG: -1, tsUtc: ahora, origen: .manual, ahora: ahora
            )
        }

        // Desde la pantalla, lo mismo, y con el motivo a la vista.
        modelo.textoCarbs = "350"
        await modelo.guardar()
        #expect(modelo.fallo == .carbohidratosFueraDeRango)
        #expect(modelo.ultimaGuardada == nil)

        #expect(try await dependencias.comidas.contar() == 0)
        #expect(try await dependencias.cola.contarPendientes() == 0)

        // Los extremos sí entran.
        _ = try await dependencias.registrarComida.ejecutar(
            carbsG: 300, tsUtc: ahora, origen: .manual, ahora: ahora
        )
        #expect(try await dependencias.comidas.contar() == 1)
    }

    /// Prueba 20 · RF-12.
    @Test("20 · RF-12: porciones en 0 no se guarda")
    func ceroPorcionesNoSeGuarda() async throws {
        #expect(Validacion.validarComida(
            carbsG: 45, tiempoAbsorcionMin: 180, porciones: 0, tsUtc: ahora, ahora: ahora
        ) == .porcionesNoPositivas)

        let (modelo, dependencias) = try montar(conocidos: [producto(porcionG: 30)])

        await #expect(throws: FalloRegistro.porcionesNoPositivas) {
            try await dependencias.registrarComida.ejecutar(
                carbsG: 0, tsUtc: ahora, origen: .barcode,
                codigoBarras: codigo, porcionG: 30, porciones: 0, ahora: ahora
            )
        }

        await modelo.escaneado(codigo: codigo)
        modelo.textoPorciones = "0"
        #expect(modelo.sePuedeGuardar == false)
        await modelo.guardar()
        #expect(modelo.fallo == .porcionesNoPositivas)

        #expect(try await dependencias.comidas.contar() == 0)
    }

    /// Prueba 21 · RF-05 — y con esto una comida futura ya no puede llegar al COB con
    /// minutos negativos.
    @Test("21 · RF-05: una hora futura no se guarda")
    func horaFuturaNoSeGuarda() async throws {
        let (modelo, dependencias) = try montar()

        await #expect(throws: FalloRegistro.horaFutura) {
            try await dependencias.registrarComida.ejecutar(
                carbsG: 60, tsUtc: ahora.addingTimeInterval(60), origen: .manual, ahora: ahora
            )
        }

        modelo.textoCarbs = "60"
        modelo.elegir(fecha: Date().addingTimeInterval(3600))
        await modelo.guardar()
        #expect(modelo.fallo == .horaFutura)

        #expect(try await dependencias.comidas.contar() == 0)
    }

    /// Una absorción que no es ninguna de las que la app ofrece tampoco entra.
    @Test("RF-12b: una absorción fuera de 30–300 minutos no se guarda")
    func absorcionFueraDeRango() async throws {
        let (_, dependencias) = try montar()

        for minutos in [0, 29, 301] {
            await #expect(throws: FalloRegistro.comidaNoSePudoGuardar) {
                try await dependencias.registrarComida.ejecutar(
                    carbsG: 60, tsUtc: ahora, origen: .manual,
                    tiempoAbsorcionMin: minutos, ahora: ahora
                )
            }
        }
        #expect(try await dependencias.comidas.contar() == 0)
    }

    /// Prueba 22 · RF-04 — el origen es de dónde salió el número, no dónde se tocó el botón.
    @Test("22 · RF-04: lo guardado por código lleva origen barcode; por etiqueta, ocrEtiqueta")
    func cadaViaConSuOrigen() async throws {
        // Por código de barras.
        let (porCodigo, dependenciasCodigo) = try montar(conocidos: [producto(porcionG: 30)])
        await porCodigo.escaneado(codigo: codigo)
        await porCodigo.guardar()
        #expect(try await unica(dependenciasCodigo).origen == .barcode)

        // Por la foto de la etiqueta: el producto no está, se lee la tabla.
        let ocr = OCRFalso()
        await ocr.responder(renglones: [
            TextoLeido(texto: "Hidratos de carbono 75 g", confianza: 0.4,
                       caja: CGRect(x: 0.1, y: 0.5, width: 0.6, height: 0.05)),
            TextoLeido(texto: "Azúcares 30 g", confianza: 0.9,
                       caja: CGRect(x: 0.1, y: 0.4, width: 0.4, height: 0.05))
        ])
        let (porEtiqueta, dependenciasEtiqueta) = try montar(ocr: ocr)
        await porEtiqueta.escaneado(codigo: codigo)
        #expect(porEtiqueta.ofreceFotoDeEtiqueta)

        await porEtiqueta.procesar(etiqueta: Data([0x00]))

        // Leer la etiqueta no guarda nada: el número se enseña y se confirma (D-11).
        #expect(porEtiqueta.via == .etiqueta)
        #expect(porEtiqueta.textoCarbsPor100g == "75")
        #expect(try await dependenciasEtiqueta.comidas.contar() == 0)
        // Y la porción se pregunta: la etiqueta no dice cuánto se comió la persona.
        #expect(porEtiqueta.sePuedeGuardar == false)

        porEtiqueta.textoPorcionG = "40"
        await porEtiqueta.guardar()

        let deEtiqueta = try await unica(dependenciasEtiqueta)
        #expect(deEtiqueta.origen == .ocrEtiqueta)
        #expect(deEtiqueta.carbsG == 30)
        #expect(deEtiqueta.codigoBarras == codigo)

        // Y si se suelta lo leído y se escribe a mano, es manual.
        let (aMano, dependenciasAMano) = try montar(conocidos: [producto(porcionG: 30)])
        await aMano.escaneado(codigo: codigo)
        aMano.escribirAMano()
        aMano.textoCarbs = "20"
        await aMano.guardar()
        let manual = try await unica(dependenciasAMano)
        #expect(manual.origen == .manual)
        #expect(manual.codigoBarras == nil)
    }

    /// Prueba 14, la otra mitad · RF-13 — la etiqueta tampoco se leyó: no es una pantalla de
    /// error, es el campo de gramos.
    @Test("14 · RF-13: si la etiqueta no se lee, queda el campo manual y se dice en una línea")
    func etiquetaIlegibleLlevaAlCampoManual() async throws {
        let ocr = OCRFalso()
        await ocr.responder(renglones: [
            TextoLeido(texto: "Ingredientes: harina de trigo", confianza: 0.9,
                       caja: CGRect(x: 0.1, y: 0.5, width: 0.6, height: 0.05))
        ])
        let (modelo, dependencias) = try montar(ocr: ocr)

        await modelo.procesar(etiqueta: Data([0x00]))

        #expect(modelo.via == .manual)
        #expect(modelo.aviso == RegistroComidaViewModel.Textos.etiquetaIlegible)
        #expect(modelo.fallo == nil)

        // Y con el OCR caído, exactamente lo mismo.
        await ocr.fallar()
        await modelo.procesar(etiqueta: Data([0x00]))
        #expect(modelo.via == .manual)
        #expect(modelo.aviso == RegistroComidaViewModel.Textos.etiquetaIlegible)

        // El último escalón nunca falla: se escribe y se guarda.
        modelo.textoCarbs = "35"
        await modelo.guardar()
        #expect(try await unica(dependencias).origen == .manual)
    }

    /// Prueba 23 · RF-36b.
    @Test("23 · RF-36b: «Deshacer» borra la comida y la cola queda sin ese registro")
    func deshacerBorraLaComidaYSuFilaDeLaCola() async throws {
        let (modelo, dependencias) = try montar()
        modelo.textoCarbs = "60"
        await modelo.guardar()

        #expect(modelo.ultimaGuardada != nil)
        #expect(try await dependencias.comidas.contar() == 1)
        #expect(try await dependencias.cola.contarPendientes() == 1)

        await modelo.deshacer()

        #expect(modelo.ultimaGuardada == nil)
        #expect(try await dependencias.comidas.contar() == 0)
        #expect(try await dependencias.cola.contarPendientes() == 0)
    }

    /// Prueba 25, lo que sí se puede ejecutar · RF-37 — ningún paso de la cascada escribe
    /// una comida. Solo «Guardar». (La otra mitad es el `grep` del pull request.)
    @Test("25 · RF-37: escanear, buscar y leer la etiqueta no crean ninguna comida")
    func nadaSeGuardaSinTocarGuardar() async throws {
        let ocr = OCRFalso()
        await ocr.responder(renglones: [
            TextoLeido(texto: "Carbohidratos 50 g", confianza: 0.99,
                       caja: CGRect(x: 0.1, y: 0.5, width: 0.6, height: 0.05))
        ])
        let (modelo, dependencias) = try montar(conocidos: [producto(porcionG: 30)], ocr: ocr)

        await modelo.escaneado(codigo: codigo)
        modelo.textoPorciones = "2"
        await modelo.procesar(etiqueta: Data([0x00]))
        modelo.textoPorcionG = "30"
        modelo.escribirAMano()
        modelo.textoCarbs = "45"

        #expect(try await dependencias.comidas.contar() == 0)
        #expect(try await dependencias.cola.contarPendientes() == 0)
        #expect(modelo.ultimaGuardada == nil)
    }
}
