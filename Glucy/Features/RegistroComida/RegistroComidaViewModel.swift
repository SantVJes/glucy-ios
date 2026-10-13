import Foundation

/// El estado de la pantalla de registro de comida.
///
/// **No tiene ninguna regla clínica y no crea ninguna comida.** La cuenta de los
/// carbohidratos la hace `Carbohidratos.deProducto`, qué se puede guardar lo decide
/// `Validacion.validarComida` a través de `RegistrarComida`, y cuál número de la etiqueta
/// son los carbohidratos lo decide `SeleccionDeCarbohidratos`. Aquí solo vive lo que hay
/// escrito en los campos y el texto que hay que enseñar.
@Observable
final class RegistroComidaViewModel {

    /// De dónde sale el número de carbohidratos. Es también el origen con que se guarda:
    /// de dónde salió el dato, no dónde se tocó el botón (regla 4, RF-04).
    enum Via: Equatable {
        /// La persona escribe los gramos. Es el escalón que nunca falla.
        case manual
        /// Open Food Facts conoce el producto: los carbohidratos vienen por 100 g.
        case producto(Producto)
        /// Se leyeron de la foto de la tabla nutrimental, también por 100 g.
        case etiqueta
    }

    /// Los textos de la cascada, palabra por palabra. Ninguno dice «error»: quedarse sin red
    /// es una condición normal y la app sigue completa (caso P-10).
    enum Textos {
        static let codigoIlegible = "No alcancé a leer el código. Acércate un poco más."
        static let noEncontrado = "Este código no está en la base. "
            + "Toma una foto de la etiqueta nutrimental."
        static let sinConsulta = "No pude consultar ahora. "
            + "Toma una foto de la etiqueta nutrimental."
        static let etiquetaIlegible = "No alcancé a leer los carbohidratos. Puedes escribirlos tú."
        static let sinCamara = "Sin cámara no puedo leer la etiqueta. "
            + "Escribe tú los carbohidratos."
    }

    private(set) var via: Via = .manual

    /// Son `String` y no `Double` por lo mismo que en la glucosa: con `Double` no se
    /// distingue «vacío» de «cero», y aquí vacío quiere decir «todavía no me lo dices».
    var textoCarbs = "" { didSet { borrarFalloSiCambio(de: oldValue, a: textoCarbs) } }
    var textoCarbsPor100g = "" { didSet { borrarFalloSiCambio(de: oldValue, a: textoCarbsPor100g) } }

    /// Los gramos de una porción. **Nace vacío salvo que la fuente los haya dado en gramos
    /// o la persona los haya dicho antes para este mismo producto.** No hay ningún camino
    /// por el que aquí aparezca un 100 que nadie escribió.
    var textoPorcionG = "" { didSet { borrarFalloSiCambio(de: oldValue, a: textoPorcionG) } }
    var textoPorciones = "1" { didSet { borrarFalloSiCambio(de: oldValue, a: textoPorciones) } }

    private(set) var fecha = Date()
    private var fechaElegida = false

    /// 180 minutos sin preguntar. Los tres chips viven detrás de «Ajustar» (RF-12b).
    var absorcion: OpcionAbsorcion = .normal
    var ajustandoAbsorcion = false

    /// La línea que dice por qué se bajó de escalón.
    private(set) var aviso: String?
    /// El escaneo no resolvió el producto y el siguiente escalón es la foto de la etiqueta.
    private(set) var ofreceFotoDeEtiqueta = false

    var mostrandoEscaner = false
    var mostrandoCamara = false
    private(set) var buscando = false
    private(set) var leyendoEtiqueta = false
    private(set) var avisoDelEscaner: String?
    /// Sin cámara o sin permiso: el código se puede escribir.
    private(set) var escanerSinCamara = false

    private(set) var fallo: FalloRegistro?
    private(set) var guardando = false
    private(set) var ultimaGuardada: ComidaDato?

    /// El último código que se escaneó bien. Se guarda con la comida aunque el número haya
    /// salido de la etiqueta: sirve para ofrecer las mismas porciones la próxima vez.
    private var codigoEscaneado: String?

    private let registrar: RegistrarComida
    private let buscar: BuscarProductoPorCodigo
    private let ocr: any ServicioOCR

    init(registrar: RegistrarComida, buscar: BuscarProductoPorCodigo, ocr: any ServicioOCR) {
        self.registrar = registrar
        self.buscar = buscar
        self.ocr = ocr
    }

    // MARK: - Lo que se enseña

    /// Los carbohidratos que se van a guardar, o `nil` si todavía falta algún dato. Nunca
    /// un número a medias: sin los gramos de la porción no hay cifra.
    var carbohidratos: Double? {
        switch via {
        case .manual:
            return Self.numero(desde: textoCarbs)
        case .producto(let producto):
            return Carbohidratos.deProducto(
                carbsPor100g: producto.carbsPor100g,
                porcionG: Self.numero(desde: textoPorcionG),
                porciones: Self.numero(desde: textoPorciones)
            )
        case .etiqueta:
            return Carbohidratos.deProducto(
                carbsPor100g: Self.numero(desde: textoCarbsPor100g),
                porcionG: Self.numero(desde: textoPorcionG),
                porciones: Self.numero(desde: textoPorciones)
            )
        }
    }

    /// Los carbohidratos por 100 g de la vía en curso, si los hay.
    private var carbsPor100g: Double? {
        switch via {
        case .manual: nil
        case .producto(let producto): producto.carbsPor100g
        case .etiqueta: Self.numero(desde: textoCarbsPor100g)
        }
    }

    /// Los tres factores a la vista: «30 g por porción × 2 porciones · 75 g por 100 g».
    var desglose: String? {
        guard carbohidratos != nil,
              let por100g = carbsPor100g,
              let porcionG = Self.numero(desde: textoPorcionG),
              let porciones = Self.numero(desde: textoPorciones) else { return nil }
        let palabra = porciones == 1 ? "porción" : "porciones"
        return "\(Self.texto(porcionG)) g por porción × \(Self.texto(porciones)) \(palabra)"
            + " · \(Self.texto(por100g)) g por 100 g"
    }

    var faltaLaPorcion: Bool {
        via != .manual && Self.numero(desde: textoPorcionG) == nil
    }

    var sePuedeGuardar: Bool {
        carbohidratos != nil && !guardando
    }

    // MARK: - Código de barras

    func abrirEscaner() {
        avisoDelEscaner = nil
        escanerSinCamara = false
        mostrandoEscaner = true
    }

    func escanerNoTieneCamara() {
        escanerSinCamara = true
    }

    /// Llega un código, del escáner o escrito. Baja por la cascada hasta donde haga falta.
    func escaneado(codigo: String) async {
        // El escáner entrega el mismo código muchas veces por segundo.
        guard !buscando else { return }
        buscando = true
        defer { buscando = false }

        let limpio = codigo.trimmingCharacters(in: .whitespaces)

        switch await buscar.ejecutar(codigo: limpio) {
        case .codigoIlegible:
            // El escáner se queda abierto: se vuelve a leer sin haber salido a la red.
            avisoDelEscaner = Textos.codigoIlegible

        case .encontrado(let producto, let ultimaComida):
            codigoEscaneado = producto.codigoBarras
            via = .producto(producto)
            // Lo que la persona dijo la última vez de este producto va antes que lo que
            // publica la fuente: ya lo corrigió una vez.
            textoPorcionG = (ultimaComida?.porcionG ?? producto.porcionSugeridaG)
                .map(Self.texto) ?? ""
            textoPorciones = Self.texto(ultimaComida?.porciones ?? 1)
            aviso = nil
            ofreceFotoDeEtiqueta = false
            fallo = nil
            mostrandoEscaner = false

        case .noEncontrado:
            bajarALaEtiqueta(codigo: limpio, diciendo: Textos.noEncontrado)

        case .sinConsulta:
            bajarALaEtiqueta(codigo: limpio, diciendo: Textos.sinConsulta)
        }
    }

    private func bajarALaEtiqueta(codigo: String, diciendo texto: String) {
        codigoEscaneado = codigo
        via = .manual
        aviso = texto
        ofreceFotoDeEtiqueta = true
        mostrandoEscaner = false
    }

    // MARK: - Foto de la etiqueta

    /// La foto **vive solo en memoria**: entra como `Data`, Vision la lee y se suelta
    /// (regla 6). Lo que salga se enseña y se confirma; aquí no se guarda nada (D-11).
    func procesar(etiqueta imagen: Data) async {
        leyendoEtiqueta = true
        defer { leyendoEtiqueta = false }

        let renglones = (try? await ocr.textosEn(imagen: imagen)) ?? []
        ofreceFotoDeEtiqueta = false

        guard let gramos = SeleccionDeCarbohidratos.gramos(entre: renglones) else {
            // No es una pantalla de error: es el campo de gramos, con el teclado abierto.
            via = .manual
            aviso = Textos.etiquetaIlegible
            return
        }

        via = .etiqueta
        textoCarbsPor100g = Self.texto(gramos)
        // La etiqueta no dice cuánto se comió la persona: la porción se pregunta.
        textoPorcionG = ""
        textoPorciones = "1"
        aviso = nil
        fallo = nil
    }

    func sinCamaraParaLaEtiqueta() {
        ofreceFotoDeEtiqueta = false
        via = .manual
        aviso = Textos.sinCamara
    }

    // MARK: - A mano

    /// Suelta el producto o la etiqueta. Lo que se guarde después es manual, porque ya no
    /// viene de ninguno de los dos.
    func escribirAMano() {
        via = .manual
        codigoEscaneado = nil
        aviso = nil
        ofreceFotoDeEtiqueta = false
        fallo = nil
    }

    // MARK: - Fecha

    func elegir(fecha nueva: Date) {
        fecha = nueva
        fechaElegida = true
        if fallo?.campo == .fecha { fallo = nil }
    }

    /// La pestaña puede llevar horas abierta: si nadie tocó la hora, se pone la de ahora.
    func ponerLaHoraDeAhora() {
        guard !fechaElegida else { return }
        fecha = Date()
    }

    // MARK: - Guardar

    func guardar() async {
        guard !guardando else { return }

        guard let carbs = carbohidratos else {
            if via == .manual || (via == .etiqueta && Self.numero(desde: textoCarbsPor100g) == nil) {
                fallo = .carbohidratosVacios
            } else {
                fallo = faltaLaPorcion ? .porcionSinGramos : .porcionesNoPositivas
            }
            return
        }

        guardando = true
        defer { guardando = false }

        do {
            let guardada: ComidaDato
            switch via {
            case .manual:
                guardada = try await registrar.ejecutar(
                    carbsG: carbs,
                    tsUtc: fecha,
                    origen: .manual,
                    tiempoAbsorcionMin: absorcion.minutos
                )
            case .producto(let producto):
                guardada = try await registrar.ejecutar(
                    carbsG: carbs,
                    tsUtc: fecha,
                    origen: .barcode,
                    tiempoAbsorcionMin: absorcion.minutos,
                    codigoBarras: producto.codigoBarras,
                    nombreProducto: producto.nombre,
                    porcionG: Self.numero(desde: textoPorcionG),
                    porciones: Self.numero(desde: textoPorciones) ?? 1
                )
            case .etiqueta:
                guardada = try await registrar.ejecutar(
                    carbsG: carbs,
                    tsUtc: fecha,
                    origen: .ocrEtiqueta,
                    tiempoAbsorcionMin: absorcion.minutos,
                    codigoBarras: codigoEscaneado,
                    porcionG: Self.numero(desde: textoPorcionG),
                    porciones: Self.numero(desde: textoPorciones) ?? 1
                )
            }

            ultimaGuardada = guardada
            limpiarCampos()
        } catch let falloDeRegistro as FalloRegistro {
            fallo = falloDeRegistro
        } catch {
            fallo = .comidaNoSePudoGuardar
        }
    }

    func deshacer() async {
        guard let guardada = ultimaGuardada else { return }
        do {
            try await registrar.deshacer(guardada)
            ultimaGuardada = nil
        } catch {
            fallo = .comidaNoSePudoGuardar
        }
    }

    /// Quita la franja de confirmación sin deshacer nada.
    func olvidarConfirmacion() {
        ultimaGuardada = nil
    }

    private func limpiarCampos() {
        via = .manual
        textoCarbs = ""
        textoCarbsPor100g = ""
        textoPorcionG = ""
        textoPorciones = "1"
        // La siguiente comida vuelve a los 180 minutos sin preguntar: una cena lenta no
        // convierte en lenta la colación de después.
        absorcion = .normal
        ajustandoAbsorcion = false
        aviso = nil
        ofreceFotoDeEtiqueta = false
        codigoEscaneado = nil
        fallo = nil
        fechaElegida = false
        fecha = Date()
    }

    // MARK: - Texto y número

    static func numero(desde texto: String) -> Double? {
        RegistroGlucosaViewModel.numero(desde: texto)
    }

    /// Hasta un decimal y sin «.0»: «45», «7.5».
    static func texto(_ valor: Double) -> String {
        let redondeado = (valor * 10).rounded() / 10
        return redondeado == redondeado.rounded()
            ? String(Int(redondeado))
            : String(redondeado)
    }

    /// «3 horas», «30 minutos».
    static func duracion(minutos: Int) -> String {
        guard minutos >= 60, minutos.isMultiple(of: 60) else { return "\(minutos) minutos" }
        let horas = minutos / 60
        return horas == 1 ? "1 hora" : "\(horas) horas"
    }

    private func borrarFalloSiCambio(de anterior: String, a nuevo: String) {
        guard anterior != nuevo, fallo != nil else { return }
        fallo = nil
    }
}
