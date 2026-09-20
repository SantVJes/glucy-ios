import Foundation
import Testing
@testable import Glucy

/// El ViewModel de la pantalla de registro.
///
/// Se prueba con el repositorio falso, sin levantar SwiftData. Va en `@MainActor` porque
/// es `@Observable` y lo consume una vista.
@MainActor
struct RegistroGlucosaViewModelTests {

    private func modeloYRepositorio() -> (RegistroGlucosaViewModel, RepositorioLecturasFalso) {
        let repositorio = RepositorioLecturasFalso()
        let modelo = RegistroGlucosaViewModel(
            registrar: RegistrarLecturaManual(repositorio: repositorio)
        )
        return (modelo, repositorio)
    }

    /// Prueba 9 · RF-01 — el teclado mexicano ofrece coma, y `Double("5,5")` devuelve nil.
    /// Sin normalizar, el mensaje de error saldría con un número perfectamente válido
    /// escrito en pantalla.
    @Test("9 · RF-01: «5,5» con coma se interpreta igual que «5.5»")
    func laComaDecimalSeEntiende() async throws {
        #expect(RegistroGlucosaViewModel.numero(desde: "5,5") == 5.5)
        #expect(RegistroGlucosaViewModel.numero(desde: "5.5") == 5.5)
        #expect(RegistroGlucosaViewModel.numero(desde: " 112 ") == 112)
        #expect(RegistroGlucosaViewModel.numero(desde: "") == nil)
        #expect(RegistroGlucosaViewModel.numero(desde: "ciento doce") == nil)

        // Y de punta a punta: 112,5 escrito con coma se guarda como 112.5.
        let (modelo, repositorio) = modeloYRepositorio()
        modelo.textoValor = "112,5"
        await modelo.guardar()

        #expect(modelo.fallo == nil)
        #expect(await repositorio.guardadas.first?.mgDl == 112.5)
    }

    /// Prueba 10 · RF-05 — un campo vacío no llega al repositorio, y se pide el número sin
    /// decir «error» ni «inválido».
    @Test("10 · RF-05: un campo vacío no llama al repositorio y pide el número")
    func campoVacioNoGuarda() async throws {
        let (modelo, repositorio) = modeloYRepositorio()

        modelo.textoValor = "   "
        await modelo.guardar()

        #expect(modelo.fallo == .valorVacio)
        #expect(modelo.fallo?.mensaje == "Escribe el número que te marcó el medidor.")
        #expect(modelo.fallo?.campo == .valor)
        #expect(await repositorio.guardadas.isEmpty)
        #expect(modelo.ultimaGuardada == nil)
    }

    /// Prueba 11 · RF-05 — un rojo que se queda puesto mientras ya se escribe el valor
    /// bueno hace pensar que la app se trabó.
    @Test("11 · RF-05: el mensaje de error se borra al cambiar el valor")
    func elErrorSeBorraAlCorregir() async throws {
        let (modelo, _) = modeloYRepositorio()

        modelo.textoValor = "900"
        await modelo.guardar()
        #expect(modelo.fallo == .fueraDeRango)

        // En cuanto se toca el campo, el mensaje se va.
        modelo.textoValor = "90"
        #expect(modelo.fallo == nil)

        // Y lo mismo con la fecha cuando el fallo era de la fecha.
        modelo.fecha = Date().addingTimeInterval(3600)
        modelo.textoValor = "112"
        await modelo.guardar()
        #expect(modelo.fallo == .horaFutura)

        modelo.fecha = Date().addingTimeInterval(-60)
        #expect(modelo.fallo == nil)
    }

    /// Prueba 12 — dos toques seguidos llegan antes de que la vista se redibuje, así que la
    /// guarda tiene que estar en el ViewModel y no solo en el botón deshabilitado.
    @Test("12 · RF-01: dos toques seguidos en «Guardar» no guardan dos veces")
    func dosToquesNoGuardanDosVeces() async throws {
        let (modelo, repositorio) = modeloYRepositorio()
        // Con retraso, el segundo toque cae mientras el primero sigue en curso.
        await repositorio.conRetraso(ms: 120)

        modelo.textoValor = "112"

        let primero = Task { await modelo.guardar() }
        await Task.yield()          // el primero arranca y se queda esperando al repositorio
        await modelo.guardar()      // este es el segundo toque
        await primero.value

        #expect(await repositorio.guardadas.count == 1)
    }

    /// Después de guardar, el campo se limpia y queda la confirmación con «Deshacer».
    @Test("RF-01: al guardar se limpia el campo y queda la confirmación")
    func alGuardarSeLimpiaElCampo() async throws {
        let (modelo, repositorio) = modeloYRepositorio()

        modelo.textoValor = "112"
        modelo.contexto = .enAyunas
        await modelo.guardar()

        #expect(modelo.fallo == nil)
        #expect(modelo.textoValor.isEmpty)
        #expect(modelo.contexto == nil)
        #expect(modelo.ultimaGuardada?.mgDl == 112)
        #expect(modelo.ultimaGuardada?.contexto == .enAyunas)
        #expect(await repositorio.guardadas.count == 1)

        // Y «Deshacer» la quita del repositorio.
        await modelo.deshacer()
        #expect(modelo.ultimaGuardada == nil)
        #expect(await repositorio.guardadas.isEmpty)
    }

    /// El botón solo se habilita cuando hay algo escrito: la validación de verdad no se
    /// hace tecla por tecla, porque marcar en rojo mientras alguien escribe «112» al pasar
    /// por «1» es hostil.
    @Test("RF-05: el botón se habilita en cuanto hay algo escrito, no antes")
    func elBotonSeHabilitaConTexto() {
        let (modelo, _) = modeloYRepositorio()

        #expect(modelo.sePuedeGuardar == false)
        modelo.textoValor = "1"
        #expect(modelo.sePuedeGuardar)
        #expect(modelo.fallo == nil)      // escribir no valida ni marca nada
        modelo.textoValor = "  "
        #expect(modelo.sePuedeGuardar == false)
    }
}
