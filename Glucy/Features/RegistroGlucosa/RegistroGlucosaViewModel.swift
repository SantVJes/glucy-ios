import Foundation

/// En qué punto va la vía de la foto.
///
/// Es un estado y no tres banderas sueltas: con banderas se puede llegar a «procesando y
/// además leído», que no significa nada, y la pantalla acaba enseñando dos cosas a la vez.
nonisolated enum EstadoFoto: Equatable {
    /// No hay ninguna foto en curso.
    case ninguno
    case procesando
    /// El OCR propuso un número. Todavía **no** se ha guardado nada.
    case leido(NumeroLeido)
    /// No encontró ningún número: se dice y se ofrece escribirlo (RF-03).
    case sinNumero
    /// Sin permiso de cámara. No es un error: es la misma salida de RF-03.
    case camaraNegada
}

/// El estado de la pantalla de registro manual.
///
/// **No tiene ninguna regla clínica.** Que 900 sea imposible no lo decide este objeto: lo
/// decide `Validacion.validarLectura`, que el caso de uso llama. Aquí solo vive el texto
/// del campo, la fecha elegida, el contexto y el mensaje que hay que enseñar.
///
/// Si algún día aparece aquí una comparación contra 20 o contra 600, la regla quedó
/// duplicada y el paso está mal hecho aunque funcione.
@Observable
final class RegistroGlucosaViewModel {

    /// Es `String` y no `Double` a propósito: con `Double` no se puede distinguir «vacío»
    /// de «cero», y el campo se llenaría solo con un 0 en cuanto se toca.
    var textoValor: String = "" {
        didSet { borrarFalloSiCambio(de: oldValue, a: textoValor) }
    }

    var fecha: Date = Date() {
        didSet { if fallo?.campo == .fecha { fallo = nil } }
    }

    var contexto: ContextoComida?

    private(set) var fallo: FalloRegistro?
    private(set) var guardando = false
    private(set) var ultimaGuardada: LecturaGlucosaDato?

    // MARK: - La vía de la foto

    private(set) var estadoFoto: EstadoFoto = .ninguno

    /// El valor mientras la persona lo corrige. Arranca con el número que propuso el OCR.
    var textoCorreccion: String = ""

    /// Lo que el OCR propuso, guardado mientras la persona decide. Sobrevive a la
    /// corrección porque `valorLeidoOcr` y `confianzaOcr` tienen que quedar guardados aunque
    /// el número final sea otro (RF-05b).
    private(set) var propuestaOcr: NumeroLeido?

    var mostrandoCamara = false

    private let registrar: RegistrarLecturaManual
    private let registrarPorFoto: RegistrarLecturaPorFoto?
    private let ocr: (any ServicioOCR)?

    init(
        registrar: RegistrarLecturaManual,
        registrarPorFoto: RegistrarLecturaPorFoto? = nil,
        ocr: (any ServicioOCR)? = nil
    ) {
        self.registrar = registrar
        self.registrarPorFoto = registrarPorFoto
        self.ocr = ocr
    }

    /// Hay algo escrito. La validación de verdad no se hace tecla por tecla: marcar en rojo
    /// mientras alguien escribe «112» al pasar por «1» es hostil.
    var sePuedeGuardar: Bool {
        !textoValor.trimmingCharacters(in: .whitespaces).isEmpty && !guardando
    }

    func guardar() async {
        // La guarda contra el doble toque: el botón se deshabilita, pero un toque doble
        // rápido llega antes de que la vista se redibuje.
        guard !guardando else { return }

        guard let mgDl = Self.numero(desde: textoValor) else {
            fallo = .valorVacio
            return
        }

        guardando = true
        defer { guardando = false }

        do {
            // Un valor que vino de la foto se guarda **como foto**, aunque se termine de
            // confirmar en esta pantalla: el origen es de dónde salió el dato, no dónde se
            // tocó el botón (regla 4, RF-04). Y con él viajan los tres campos de RF-05b,
            // que es lo único que después permite evaluar si el OCR se equivoca.
            let guardada: LecturaGlucosaDato
            if let propuesta = propuestaOcr, let registrarPorFoto {
                guardada = try await registrarPorFoto.ejecutar(
                    valorConfirmado: mgDl,
                    valorLeidoOcr: propuesta.valor,
                    confianzaOcr: propuesta.confianza,
                    tsUtc: fecha,
                    contexto: contexto
                )
            } else {
                guardada = try await registrar.ejecutar(
                    mgDl: mgDl,
                    tsUtc: fecha,
                    contexto: contexto
                )
            }

            ultimaGuardada = guardada
            fallo = nil
            // El campo se limpia y el teclado se queda abierto para la siguiente.
            textoValor = ""
            contexto = nil
            propuestaOcr = nil
        } catch let falloDeRegistro as FalloRegistro {
            fallo = falloDeRegistro
        } catch {
            fallo = .noSePudoGuardar
        }
    }

    /// Deshace el último guardado. Mejor que preguntar «¿estás seguro?».
    func deshacer() async {
        guard let guardada = ultimaGuardada else { return }
        do {
            try await registrar.deshacer(guardada)
            ultimaGuardada = nil
        } catch {
            fallo = .noSePudoGuardar
        }
    }

    func limpiar() {
        textoValor = ""
        contexto = nil
        fallo = nil
        ultimaGuardada = nil
        propuestaOcr = nil
        fecha = Date()
    }

    /// Quita la franja de confirmación sin deshacer nada.
    func olvidarConfirmacion() {
        ultimaGuardada = nil
    }

    /// El teclado mexicano ofrece coma decimal, y `Double("5,5")` devuelve `nil`. Sin esta
    /// normalización el mensaje de error aparecería con un número perfectamente válido
    /// escrito en pantalla.
    static func numero(desde texto: String) -> Double? {
        let limpio = texto
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ",", with: ".")
        guard !limpio.isEmpty else { return nil }
        return Double(limpio)
    }


    // MARK: - La vía de la foto

    /// Procesa la imagen recién tomada. La foto **vive solo en memoria**: entra como
    /// `Data`, Vision la lee y se suelta. No se escribe en disco, no va al carrete, no se
    /// sube y no se guarda para depurar (regla 6).
    func procesar(imagen: Data) async {
        guard let ocr else { return }
        estadoFoto = .procesando

        do {
            let numeros = try await ocr.numerosEn(imagen: imagen)
            // Quien elige es la regla, no el ViewModel y no la confianza.
            if let glucosa = SeleccionDeNumero.glucosa(entre: numeros) {
                propuestaOcr = glucosa
                textoCorreccion = Self.textoDe(glucosa.valor)
                estadoFoto = .leido(glucosa)
            } else {
                propuestaOcr = nil
                textoCorreccion = ""
                estadoFoto = .sinNumero
            }
        } catch {
            // Que la imagen no se pueda leer tiene la misma salida que no encontrar número:
            // se dice y se ofrece escribirlo. No es una pantalla de error (RF-03).
            propuestaOcr = nil
            textoCorreccion = ""
            estadoFoto = .sinNumero
        }
    }

    /// La persona no dio permiso de cámara. No es un error: se dice en una línea y se
    /// ofrece escribir el número.
    func camaraSinPermiso() {
        propuestaOcr = nil
        textoCorreccion = ""
        estadoFoto = .camaraNegada
    }

    /// La persona aprobó el valor leído, o escribió el suyo.
    ///
    /// **Aquí no se guarda nada.** El valor se lleva a la pantalla de registro, al campo de
    /// «a mano», para que se le pueda poner contexto y hora antes de guardarlo. Guardar
    /// sigue siendo un gesto aparte y explícito, así que la confirmación de D-11 se cumple
    /// de sobra: ahora hay dos (RF-02, caso P-01).
    ///
    /// La propuesta del OCR **no** se borra: sobrevive hasta el guardado para que
    /// `valorLeidoOcr`, `confianzaOcr` y `fueCorregido` queden registrados aunque el número
    /// final sea otro (RF-05b).
    func llevarAlRegistro(valor texto: String) {
        guard let valor = Self.numero(desde: texto) else {
            fallo = .valorVacio
            return
        }

        textoValor = Self.textoDe(valor)
        fallo = nil
        // Solo se cierra la hoja. La propuesta se queda.
        estadoFoto = .ninguno
    }

    /// Descarta lo que vino de la foto y deja el campo vacío. Lo que se guarde después es
    /// manual, porque ya no viene de ninguna lectura del OCR.
    func descartarLoDeLaFoto() {
        propuestaOcr = nil
        textoValor = ""
        estadoFoto = .ninguno
        textoCorreccion = ""
    }

    /// Cierra la vía de la foto sin guardar nada.
    func cerrarFoto() {
        estadoFoto = .ninguno
        propuestaOcr = nil
        textoCorreccion = ""
    }

    /// Sin decimales cuando el número es entero: «112», no «112.0».
    private static func textoDe(_ valor: Double) -> String {
        valor == valor.rounded() ? String(Int(valor)) : String(valor)
    }

    /// El mensaje se borra en cuanto la persona empieza a corregir: un rojo que se queda
    /// puesto mientras ya se escribe el valor bueno hace pensar que la app se trabó.
    private func borrarFalloSiCambio(de anterior: String, a nuevo: String) {
        guard anterior != nuevo, fallo != nil else { return }
        fallo = nil
    }
}
