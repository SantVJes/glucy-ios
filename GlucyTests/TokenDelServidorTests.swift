import Foundation
import Testing
@testable import Glucy

/// El token del servidor se pega a mano en Ajustes, y de ahí va al Keychain.
///
/// Es la única forma de que un teléfono de verdad se autentique mientras la fase 2 no traiga
/// el alta y la rotación: el backend no tiene ningún endpoint que emita tokens, los firma
/// `scripts/token-de-prueba.py`. Lo que se prueba aquí es lo que puede fallar en silencio:
/// que el token acabe donde debe, que el campo no se quede con él y que sin almacén la
/// pantalla no ofrezca algo que no funciona.
@MainActor
struct TokenDelServidorTests {

    private let ahora = Date(timeIntervalSince1970: 1_758_240_000)

    @Test("el token pegado va al almacén y el campo se vacía")
    func elTokenVaAlAlmacen() async {
        let almacen = AlmacenFalso()
        let modelo = ajustes(almacen: almacen)

        await modelo.cargar()
        #expect(!modelo.hayToken)

        modelo.textoToken = "  eyJhbGciOiJIUzI1NiJ9.carga.firma  "
        modelo.guardarToken()

        // Con los espacios recortados: un token pegado desde la terminal los trae, y el
        // servidor contestaría 401 sin decir por qué.
        #expect(almacen.token() == "eyJhbGciOiJIUzI1NiJ9.carga.firma")
        #expect(modelo.hayToken)
        // El campo no se queda con el token: la captura que iOS toma al mandar la app al
        // fondo lo enseñaría.
        #expect(modelo.textoToken.isEmpty)
        #expect(modelo.fallo == nil)
    }

    @Test("un campo vacío no borra el token que ya había")
    func elCampoVacioNoBorraNada() async {
        let almacen = AlmacenFalso(token: "el.de.antes")
        let modelo = ajustes(almacen: almacen)

        await modelo.cargar()
        #expect(modelo.hayToken)

        modelo.textoToken = "   "
        modelo.guardarToken()

        #expect(almacen.token() == "el.de.antes")
    }

    @Test("borrarlo lo quita del almacén y la pantalla lo dice")
    func borrarloLoQuita() async {
        let almacen = AlmacenFalso(token: "el.de.antes")
        let modelo = ajustes(almacen: almacen)

        await modelo.cargar()
        modelo.borrarToken()

        #expect(almacen.token() == nil)
        #expect(!modelo.hayToken)
    }

    @Test("sin almacén o sin servidor el campo no se ofrece")
    func sinAlmacenNoSeOfrece() async {
        // Sin dirección de backend no hay a quién autenticarse, así que pedir un token sería
        // pedir algo que no sirve para nada.
        #expect(!ajustes(almacen: AlmacenFalso(), conBackend: false).sePuedeGuardarToken)
        #expect(!ajustes(almacen: nil).sePuedeGuardarToken)
        #expect(ajustes(almacen: AlmacenFalso()).sePuedeGuardarToken)
    }

    // MARK: - Armado

    private func ajustes(
        almacen: AlmacenFalso?, conBackend: Bool = true
    ) -> AjustesViewModel {
        let repoPerfil = RepositorioPerfilFalso(perfil())
        let salud = HealthKitFalso()
        return AjustesViewModel(
            guardar: GuardarAjustes(perfil: repoPerfil),
            pendientes: ConsultarColaPendiente(cola: RepositorioColaFalso()),
            completarAlta: CompletarAlta(perfil: repoPerfil, salud: salud),
            sincronizar: SincronizarLecturasDelSensor(
                servicio: salud, lecturas: RepositorioLecturasFalso(),
                ancla: AnclaHealthKit(dominio: "glucy.pruebas.\(UUID().uuidString)")
            ),
            candado: CandadoFalso(abre: true),
            subirAlBackend: conBackend ? backend(repoPerfil) : nil,
            almacenDeToken: almacen
        )
    }

    private func backend(_ repoPerfil: RepositorioPerfilFalso) -> SincronizarConBackend {
        SincronizarConBackend(
            cola: RepositorioColaFalso(),
            lecturas: RepositorioLecturasFalso(),
            comidas: RepositorioComidasFalso(),
            dosis: RepositorioDosisFalso(),
            perfil: repoPerfil,
            cliente: BackendFalso(),
            red: RedFalsa(hayWifi: true)
        )
    }

    private func perfil() -> PerfilDato {
        PerfilDato(
            fechaNacimiento: ReglasDePerfil.fechaDeAnio(1990),
            tipoUsuario: .tipo1,
            consentimientoTsUtc: ahora,
            sincronizacionActiva: true
        )
    }
}
