import Foundation

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

    private let registrar: RegistrarLecturaManual

    init(registrar: RegistrarLecturaManual) {
        self.registrar = registrar
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
            let guardada = try await registrar.ejecutar(
                mgDl: mgDl,
                tsUtc: fecha,
                contexto: contexto
            )
            ultimaGuardada = guardada
            fallo = nil
            // El campo se limpia y el teclado se queda abierto para la siguiente.
            textoValor = ""
            contexto = nil
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

    /// El mensaje se borra en cuanto la persona empieza a corregir: un rojo que se queda
    /// puesto mientras ya se escribe el valor bueno hace pensar que la app se trabó.
    private func borrarFalloSiCambio(de anterior: String, a nuevo: String) {
        guard anterior != nuevo, fallo != nil else { return }
        fallo = nil
    }
}
