import Foundation
import Testing
@testable import Glucy

/// El candado nunca deja a nadie fuera de su propia app, y la puerta de la app es el
/// consentimiento.
@MainActor
struct CandadoTests {

    private let ahora = Date(timeIntervalSince1970: 1_758_240_000)

    @Test("24 · si la política no se puede evaluar, la app se abre")
    func siAlgoFallaSeEntra() async {
        // Sin hardware, sin código o con el servicio caído.
        #expect(await CandadoBiometrico(evaluador: EvaluadorFalso(respuesta: .noSePuedeEvaluar))
            .pedirEntrada(motivo: "Abrir Glucy"))
        // El sistema dijo que podía y al preguntar no pudo: también se entra.
        #expect(await CandadoBiometrico(evaluador: EvaluadorFalso(respuesta: .fallaAlPreguntar))
            .pedirEntrada(motivo: "Abrir Glucy"))
        #expect(await CandadoBiometrico(evaluador: EvaluadorFalso(respuesta: .pasa))
            .pedirEntrada(motivo: "Abrir Glucy"))
        // Lo único que deja la app cerrada es que la persona no pase o cierre la hoja, y
        // entonces puede volver a intentarlo.
        #expect(await CandadoBiometrico(evaluador: EvaluadorFalso(respuesta: .noPasa))
            .pedirEntrada(motivo: "Abrir Glucy") == false)
    }

    private func raiz(
        perfil: RepositorioPerfilFalso, candado: CandadoFalso
    ) -> RaizViewModel {
        let salud = HealthKitFalso()
        return RaizViewModel(
            consultar: ConsultarEntrada(perfil: perfil),
            candado: candado,
            sincronizar: SincronizarLecturasDelSensor(
                servicio: salud, lecturas: RepositorioLecturasFalso(),
                ancla: AnclaHealthKit(dominio: "glucy.pruebas.\(UUID().uuidString)"), perfil: perfil
            )
        )
    }

    private func perfil(consentido: Bool, conCandado: Bool = false) -> PerfilDato {
        PerfilDato(
            fechaNacimiento: ReglasDePerfil.fechaDeAnio(1990), tipoUsuario: .tipo1,
            consentimientoTsUtc: consentido ? ahora : nil, bloqueoBiometrico: conCandado
        )
    }

    @Test("la puerta es el consentimiento: un perfil sin él lleva al alta, no a las pestañas")
    func laPuertaEsElConsentimiento() async {
        let sinPerfil = raiz(perfil: RepositorioPerfilFalso(), candado: CandadoFalso(abre: true))
        await sinPerfil.arrancar()
        #expect(sinPerfil.pantalla == .alta)

        // Existe, pero no ha consentido.
        let aMedias = raiz(
            perfil: RepositorioPerfilFalso(perfil(consentido: false)), candado: CandadoFalso(abre: true)
        )
        await aMedias.arrancar()
        #expect(aMedias.pantalla == .alta)

        let candado = CandadoFalso(abre: true)
        let dentro = raiz(perfil: RepositorioPerfilFalso(perfil(consentido: true)), candado: candado)
        await dentro.arrancar()
        #expect(dentro.pantalla == .dentro)
        // Apagado por omisión: ni se pregunta.
        #expect(!dentro.bloqueada)
        #expect(await candado.vecesPedido == 0)
    }

    @Test("con el candado encendido se pide al abrir y al volver pasado un rato, no antes")
    func elCandadoSePideCuandoToca() async {
        let candado = CandadoFalso(abre: true)
        let modelo = raiz(
            perfil: RepositorioPerfilFalso(perfil(consentido: true, conCandado: true)), candado: candado
        )
        await modelo.arrancar()
        #expect(modelo.pantalla == .dentro)
        #expect(!modelo.bloqueada)
        #expect(await candado.vecesPedido == 1)

        // Salir diez segundos y volver no lo vuelve a pedir.
        modelo.salioASegundoPlano(ahora: ahora)
        await modelo.volvio(ahora: ahora.addingTimeInterval(10))
        #expect(await candado.vecesPedido == 1)

        // Pasado el rato de gracia, sí.
        modelo.salioASegundoPlano(ahora: ahora)
        await modelo.volvio(ahora: ahora.addingTimeInterval(ConfiguracionDominio.graciaDelCandadoS + 1))
        #expect(await candado.vecesPedido == 2)
        #expect(!modelo.bloqueada)

        // Si la persona no pasa, se queda bloqueada sobre las pestañas y puede reintentar.
        let cerrado = CandadoFalso(abre: false)
        let bloqueado = raiz(
            perfil: RepositorioPerfilFalso(perfil(consentido: true, conCandado: true)), candado: cerrado
        )
        await bloqueado.arrancar()
        #expect(bloqueado.pantalla == .dentro)
        #expect(bloqueado.bloqueada)
        await bloqueado.pedirEntrada()
        #expect(await cerrado.vecesPedido == 2)
    }
}
