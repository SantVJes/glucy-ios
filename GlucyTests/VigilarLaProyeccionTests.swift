import Foundation
import Testing
@testable import Glucy

/// Una etiqueta corta de cada resultado, para compararla con `==` sin mirar el UUID de la
/// alerta, que es distinto en cada pasada. Reusa la de `ResultadoDelAviso`.
extension ResultadoDeLaVigilancia {
    var etiqueta: String {
        switch self {
        case let .decidido(aviso): aviso.etiqueta
        case .sinPrediccion: "sinPrediccion"
        case .noSePudoRegistrar: "noSePudoRegistrar"
        }
    }

    var motivo: SinProyeccion? {
        switch self {
        case let .sinPrediccion(motivo): motivo
        default: nil
        }
    }
}

/// El aviso cuando no hay ninguna pantalla dibujada.
///
/// **La prueba que más importa de este archivo es `enSegundoPlanoNoSePideElPermiso`.** iOS no
/// puede presentar el diálogo del permiso con la app en segundo plano, y preguntar ahí gasta la
/// única vez que se puede preguntar: negado, no se vuelve a ofrecer nunca. Un fallo así no se
/// ve en ninguna pantalla —la app sigue funcionando— y deja a la persona sin el aviso para el
/// que existe el producto.
struct VigilarLaProyeccionTests {

    private let ahora = Date(timeIntervalSince1970: 1_758_240_000)

    /// Trece lecturas de cinco en cinco minutos, que es serie de sobra para el juego denso:
    /// el rezago más largo es de 60 minutos.
    private func serie() async throws -> RepositorioLecturasFalso {
        let repositorio = RepositorioLecturasFalso()
        for paso in 0..<13 {
            let haceMin = Double(60 - paso * 5)
            try await repositorio.guardar(LecturaGlucosaDato(
                mgDl: 100 + Double(paso) * 4,
                tsUtc: ahora.addingTimeInterval(-haceMin * 60),
                origen: .sensor
            ))
        }
        return repositorio
    }

    /// Los dobles se construyen cada uno en su línea y nunca como valor por omisión de un
    /// parámetro: un valor por omisión se evalúa en quien llama, y llamar ahí al init de un
    /// `actor` hace que el compilador quiera marcarlo `nonisolated`, lo que en un init síncrono
    /// de actor no vale.
    private func caso(
        lecturas: RepositorioLecturasFalso,
        alertas: RepositorioAlertasFalso,
        avisos: AvisosFalsos,
        devuelve: Double,
        perfil: PerfilDato? = nil
    ) -> VigilarLaProyeccion {
        let comidas = RepositorioComidasFalso()
        let dosis = RepositorioDosisFalso()
        let dePerfil = RepositorioPerfilFalso(perfil)
        let modelo = ModeloFalso(
            horizonteMin: 30, version: "m1-v0.2.0-prueba", devuelve: .success(devuelve)
        )
        let predecir = CalcularPrediccion(
            lecturas: lecturas, comidas: comidas, dosis: dosis,
            perfil: dePerfil, modelos: [modelo]
        )
        let avisar = AvisarDeLaProyeccion(alertas: alertas, avisos: avisos)
        return VigilarLaProyeccion(predecir: predecir, avisar: avisar, perfil: dePerfil)
    }

    private func estado(_ modo: ModoApp) -> EstadoModo {
        EstadoModo(modo: modo, antiguedadMin: 2)
    }

    // MARK: - Lo que importa

    @Test("En segundo plano no se pide el permiso: se registra y se dice")
    func enSegundoPlanoNoSePideElPermiso() async throws {
        let lecturas = try await serie()
        let alertas = RepositorioAlertasFalso()
        let avisos = AvisosFalsos(
            permiso: .sinPreguntar, respondeAlPedir: true, falloAlEntregar: nil
        )
        let vigilar = caso(
            lecturas: lecturas, alertas: alertas, avisos: avisos, devuelve: 58
        )

        let resultado = await vigilar.ejecutar(estado: estado(.sensor), ahora: ahora)

        // Aunque el doble habría dicho sí, no se le preguntó.
        #expect(await avisos.vecesQueSePidioPermiso == 0)
        #expect(resultado.etiqueta == "registradaSinPermiso")
        // Y la alerta sí quedó anotada: es lo que distingue «no se avisó» de «se avisó y no
        // llegó», y lo que permite medir después el tiempo de anticipación.
        #expect(await alertas.guardadas.count == 1)
        #expect(await avisos.entregados.isEmpty)
    }

    // MARK: - El camino normal

    @Test("Una baja prevista en modo sensor avisa sin que haya pantalla")
    func unaBajaPrevistaAvisaSinPantalla() async throws {
        let lecturas = try await serie()
        let alertas = RepositorioAlertasFalso()
        let avisos = AvisosFalsos(
            permiso: .concedido, respondeAlPedir: true, falloAlEntregar: nil
        )
        let vigilar = caso(
            lecturas: lecturas, alertas: alertas, avisos: avisos, devuelve: 58
        )

        let resultado = await vigilar.ejecutar(estado: estado(.sensor), ahora: ahora)

        #expect(resultado.etiqueta == "avisado")
        let entregado = try #require(await avisos.ultimoEntregado)
        #expect(entregado.vibra)
        #expect(entregado.cuerpo.contains("58 mg/dL"))
    }

    @Test("Una estimación dentro del rango no avisa de nada")
    func dentroDelRangoNoAvisa() async throws {
        let lecturas = try await serie()
        let alertas = RepositorioAlertasFalso()
        let avisos = AvisosFalsos(
            permiso: .concedido, respondeAlPedir: true, falloAlEntregar: nil
        )
        let vigilar = caso(
            lecturas: lecturas, alertas: alertas, avisos: avisos, devuelve: 130
        )

        let resultado = await vigilar.ejecutar(estado: estado(.sensor), ahora: ahora)

        #expect(resultado.etiqueta == "nadaQueAvisar")
        #expect(await alertas.guardadas.isEmpty)
        #expect(await avisos.entregados.isEmpty)
    }

    @Test("El umbral que decide es el del perfil, también en segundo plano")
    func elUmbralEsElDelPerfil() async throws {
        let lecturas = try await serie()
        let alertas = RepositorioAlertasFalso()
        let avisos = AvisosFalsos(
            permiso: .concedido, respondeAlPedir: true, falloAlEntregar: nil
        )
        // 75 está por encima del umbral de por omisión, 70, y por debajo del de esta persona.
        let suyo = PerfilDato(
            fechaNacimiento: ahora.addingTimeInterval(-30 * 365 * 86_400),
            tipoUsuario: .tipo1, umbralHipo: 80
        )
        let vigilar = caso(
            lecturas: lecturas, alertas: alertas, avisos: avisos, devuelve: 75, perfil: suyo
        )

        let resultado = await vigilar.ejecutar(estado: estado(.sensor), ahora: ahora)

        #expect(resultado.etiqueta == "avisado")
        let alerta = try #require(await alertas.guardadas.first)
        #expect(alerta.umbralMgDl == 80)
    }

    // MARK: - Cuando no hay nada que vigilar

    @Test("RF-10b: en modo sin sensor no se predice ni se avisa")
    func sinSensorNoSeAnticipa() async throws {
        let lecturas = try await serie()
        let alertas = RepositorioAlertasFalso()
        let avisos = AvisosFalsos(
            permiso: .concedido, respondeAlPedir: true, falloAlEntregar: nil
        )
        let vigilar = caso(
            lecturas: lecturas, alertas: alertas, avisos: avisos, devuelve: 58
        )

        let resultado = await vigilar.ejecutar(estado: estado(.sinSensor), ahora: ahora)

        let motivo = try #require(resultado.motivo)
        #expect(motivo == SinProyeccion.sinSensor)
        #expect(await avisos.entregados.isEmpty)
        #expect(await alertas.guardadas.isEmpty)
    }

    @Test("Sin artefacto no hay predicción y se dice el motivo")
    func sinArtefactoNoHayPrediccion() async throws {
        let lecturas = try await serie()
        let alertas = RepositorioAlertasFalso()
        let avisos = AvisosFalsos(
            permiso: .concedido, respondeAlPedir: true, falloAlEntregar: nil
        )
        let comidas = RepositorioComidasFalso()
        let dosis = RepositorioDosisFalso()
        let dePerfil = RepositorioPerfilFalso(nil)
        let predecir = CalcularPrediccion(
            lecturas: lecturas, comidas: comidas, dosis: dosis, perfil: dePerfil, modelos: []
        )
        let avisar = AvisarDeLaProyeccion(alertas: alertas, avisos: avisos)
        let vigilar = VigilarLaProyeccion(
            predecir: predecir, avisar: avisar, perfil: dePerfil
        )

        let resultado = await vigilar.ejecutar(estado: estado(.sensor), ahora: ahora)

        #expect(resultado.etiqueta == "sinPrediccion")
        let motivo = try #require(resultado.motivo)
        let esperado = SinProyeccion.sinModelo(detalle: "no se cargó ningún artefacto")
        #expect(motivo == esperado)
    }
}
