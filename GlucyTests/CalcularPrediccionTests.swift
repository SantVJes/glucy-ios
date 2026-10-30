import Foundation
import Testing
@testable import Glucy

/// La predicción en el teléfono: cuándo se calcula, con qué fila y cuándo no se calcula.
///
/// **La prueba que más importa de este archivo es `laFilaSeArmaEnLaUltimaLectura`**, y no
/// porque sea la más complicada. Es el único fallo de este caso de uso que no se nota: armar la
/// fila con la hora del reloj en lugar de con el instante de la lectura devuelve un número
/// plausible, la pantalla lo dibuja y nadie se entera. Medido en el servidor, donde estaba el
/// mismo error: el RMSE pasaba de 11.9 a 125.2 mg/dL.
struct CalcularPrediccionTests {

    private let ahora = Date(timeIntervalSince1970: 1_758_240_000)

    private func lecturas(_ valores: [(Double, Double)], origen: Origen = .sensor) async throws
        -> RepositorioLecturasFalso
    {
        let repositorio = RepositorioLecturasFalso()
        for (mgDl, haceMin) in valores {
            try await repositorio.guardar(LecturaGlucosaDato(
                mgDl: mgDl, tsUtc: ahora.addingTimeInterval(-haceMin * 60), origen: origen
            ))
        }
        return repositorio
    }

    /// Los dobles se construyen **dentro**, cada uno en su propia línea, y no como valor por
    /// omisión de un parámetro: un valor por omisión se evalúa en quien llama, y llamar ahí al
    /// init de un actor hace que el compilador quiera marcarlo `nonisolated`, lo que en un
    /// init síncrono de actor no vale. Las demás pruebas del repositorio lo hacen así, y por
    /// algo. Las comidas y las dosis no se parametrizan porque ninguna prueba de aquí las
    /// necesita: lo que estas pruebas miran es la serie, la base y el modelo.
    private func caso(
        lecturas: RepositorioLecturasFalso,
        perfil: PerfilDato? = nil,
        modelos: [any RepositorioModelo]
    ) -> CalcularPrediccion {
        let comidas = RepositorioComidasFalso()
        let dosis = RepositorioDosisFalso()
        let dePerfil = RepositorioPerfilFalso(perfil)
        return CalcularPrediccion(
            lecturas: lecturas, comidas: comidas, dosis: dosis,
            perfil: dePerfil, modelos: modelos
        )
    }

    // MARK: - La fila

    @Test("La fila se arma en el instante de la última lectura y no en el del reloj")
    func laFilaSeArmaEnLaUltimaLectura() async throws {
        // Serie de cinco minutos que terminó hace ocho: sigue fresca (el umbral son 15) y el
        // modo sigue siendo sensor. Pero el reloj está a ocho minutos de la última lectura, o
        // sea a más de media muestra, así que armando la fila con `ahora` `mg_dl` saldría
        // `NaN` y los rezagos resolverían a la lectura de cinco minutos después de la que les
        // toca. Lo que se comprueba es la fila que recibió el modelo, no el número que devolvió.
        let repositorio = try await lecturas([(100, 68), (110, 63), (120, 58), (130, 53),
                                              (140, 48), (150, 43), (160, 38), (170, 33),
                                              (180, 28), (190, 23), (200, 18), (210, 13),
                                              (220, 8)])
        let modelo = ModeloFalso()
        let resultado = try await caso(lecturas: repositorio, modelos: [modelo])
            .ejecutar(modo: .sensor, ahora: ahora)

        let vector = try #require(await modelo.ultimoVector)
        #expect(vector["mg_dl"] == 220)
        #expect(vector["rezago_5"] == 210)
        #expect(vector["rezago_60"] == 100)
        #expect(!vector.values.contains { $0.isNaN })

        // Y el horizonte se cuenta desde ahí: a 30 minutos de la lectura de hace ocho, o sea
        // a veintidós del reloj. La pantalla enseña la hora por esto.
        let proyeccion = try #require(try resultado.get().first)
        #expect(proyeccion.base.ts == ahora.addingTimeInterval(-8 * 60))
        #expect(proyeccion.base.mgDl == 220)
        #expect(proyeccion.objetivo == ahora.addingTimeInterval(22 * 60))
        #expect(proyeccion.objetivo > ahora)
    }

    @Test("Un pinchazo más nuevo no mueve la base de la fila")
    func unPinchazoNoMueveLaBase() async throws {
        // El juego denso se construye sobre la serie continua: mezclar un punto aislado metería
        // un rezago falso. Es lo que hace `solo_sensor` en el entrenamiento.
        let repositorio = try await lecturas([(120, 20), (125, 15), (130, 10), (135, 5)])
        try await repositorio.guardar(LecturaGlucosaDato(
            mgDl: 211, tsUtc: ahora.addingTimeInterval(-60), origen: .manual
        ))
        let modelo = ModeloFalso()
        _ = try await caso(lecturas: repositorio, modelos: [modelo])
            .ejecutar(modo: .sensor, ahora: ahora)

        let vector = try #require(await modelo.ultimoVector)
        #expect(vector["mg_dl"] == 135)
        #expect(vector["rezago_5"] == 130)
    }

    @Test("Una lectura con fecha futura no se usa como base")
    func unaLecturaFuturaNoEsLaBase() async throws {
        // HealthKit entrega lo que la app del fabricante escribió, y un reloj mal puesto puede
        // dejar una marca adelantada. Con ella como base, la predicción apuntaría a un instante
        // que ya pasó.
        let repositorio = try await lecturas([(120, 10), (130, 5), (300, -20)])
        let modelo = ModeloFalso()
        let resultado = try await caso(lecturas: repositorio, modelos: [modelo])
            .ejecutar(modo: .sensor, ahora: ahora)

        let proyeccion = try #require(try resultado.get().first)
        #expect(proyeccion.base.mgDl == 130)
        #expect(proyeccion.objetivo == ahora.addingTimeInterval(25 * 60))
    }

    @Test("Una lectura marcada como atípica no sirve de base")
    func unaLecturaAtipicaNoEsLaBase() async throws {
        let repositorio = RepositorioLecturasFalso()
        try await repositorio.guardar(LecturaGlucosaDato(
            mgDl: 400, tsUtc: ahora.addingTimeInterval(-60), origen: .sensor, atipica: true
        ))
        let resultado = try await caso(lecturas: repositorio, modelos: [ModeloFalso()])
            .ejecutar(modo: .sensor, ahora: ahora)
        #expect(resultado == .failure(.serieInsuficiente))
    }

    // MARK: - Cuándo no hay predicción

    @Test("RF-10b: en modo sin sensor no hay número, y el motivo es ese")
    func sinSensorNoHayNumero() async throws {
        let repositorio = try await lecturas([(120, 10), (130, 5)])
        let modelo = ModeloFalso()
        let resultado = try await caso(lecturas: repositorio, modelos: [modelo])
            .ejecutar(modo: .sinSensor, ahora: ahora)

        #expect(resultado == .failure(.sinSensor))
        // Y el modelo no se llamó: no es que el número se oculte, es que no se calcula.
        let recibidos = await modelo.recibidos
        #expect(recibidos.isEmpty)
    }

    @Test("Sin ninguna lectura del sensor no se inventa nada")
    func sinLecturasNoHayNumero() async throws {
        let resultado = try await caso(
            lecturas: RepositorioLecturasFalso(), modelos: [ModeloFalso()]
        ).ejecutar(modo: .sensor, ahora: ahora)
        #expect(resultado == .failure(.serieInsuficiente))
    }

    @Test("Sin artefacto cargado no hay número de respaldo")
    func sinModeloNoHayRespaldo() async throws {
        // Una línea base de persistencia —«dentro de 30 min será igual que ahora»— es una
        // herramienta de evaluación. Enseñarla como predicción sería una cifra que nadie
        // validó y sobre la que alguien actuaría.
        let repositorio = try await lecturas([(120, 10), (130, 5)])
        let resultado = try await caso(lecturas: repositorio, modelos: [])
            .ejecutar(modo: .sensor, ahora: ahora)
        guard case .failure(.sinModelo) = resultado else {
            Issue.record("se esperaba `sinModelo` y salió \(resultado)")
            return
        }
    }

    @Test("Un número imposible no se enseña y no se recorta al límite")
    func unNumeroImposibleNoSeEnsena() async throws {
        // Recortarlo a 600 lo haría pasar por una predicción. Es un síntoma, y se dice con su
        // valor para que quien lo vea en una prueba de campo pueda reportarlo.
        let repositorio = try await lecturas([(120, 10), (130, 5)])
        let resultado = try await caso(
            lecturas: repositorio, modelos: [ModeloFalso(devuelve: .success(812))]
        ).ejecutar(modo: .sensor, ahora: ahora)
        #expect(resultado == .failure(.fueraDeRango(valorMgDl: 812)))
    }

    @Test("Si el modelo falla, se dice y no se tumba la pantalla")
    func siElModeloFallaSeDice() async throws {
        let repositorio = try await lecturas([(120, 10), (130, 5)])
        let resultado = try await caso(
            lecturas: repositorio,
            modelos: [ModeloFalso(devuelve: .failure(.salidaInesperada(detalle: "prueba")))]
        ).ejecutar(modo: .sensor, ahora: ahora)
        guard case .failure(.sinModelo) = resultado else {
            Issue.record("se esperaba `sinModelo` y salió \(resultado)")
            return
        }
    }

    // MARK: - Los dos horizontes y el aviso

    @Test("Los dos horizontes salen ordenados y cada uno con su hora")
    func losDosHorizontesSalenOrdenados() async throws {
        let repositorio = try await lecturas([(120, 10), (130, 5)])
        let resultado = try await caso(
            lecturas: repositorio,
            modelos: [
                ModeloFalso(horizonteMin: 60, version: "m2", devuelve: .success(150)),
                ModeloFalso(horizonteMin: 30, version: "m1", devuelve: .success(140)),
            ]
        ).ejecutar(modo: .sensor, ahora: ahora)

        let proyecciones = try resultado.get()
        #expect(proyecciones.map(\.horizonteMin) == [30, 60])
        #expect(proyecciones.map(\.versionModelo) == ["m1", "m2"])
        #expect(proyecciones[0].objetivo == ahora.addingTimeInterval(25 * 60))
        #expect(proyecciones[1].objetivo == ahora.addingTimeInterval(55 * 60))
    }

    @Test("El aviso sale del umbral del perfil y no del de por omisión")
    func elAvisoSaleDelUmbralDelPerfil() async throws {
        // Quien puso su umbral en 85 quiere que se le avise en 85. Con 80 mg/dL predichos, el
        // umbral de por omisión (70) no avisaría.
        let repositorio = try await lecturas([(120, 10), (130, 5)])
        let perfil = PerfilDato(
            fechaNacimiento: ahora.addingTimeInterval(-30 * 365 * 86_400),
            tipoUsuario: .tipo1, umbralHipo: 85
        )
        let resultado = try await caso(
            lecturas: repositorio, perfil: perfil,
            modelos: [ModeloFalso(devuelve: .success(80))]
        ).ejecutar(modo: .sensor, ahora: ahora)

        let proyecciones = try resultado.get()
        #expect(proyecciones.first?.aviso == .bajaPrevista)
        #expect(CalcularPrediccion.aviso(valorMgDl: 80, umbralHipo: 70, umbralHiper: 180) == nil)
    }

    @Test("Entre los dos umbrales no hay aviso")
    func entreLosUmbralesNoHayAviso() {
        #expect(CalcularPrediccion.aviso(valorMgDl: 120, umbralHipo: 70, umbralHiper: 180) == nil)
        #expect(CalcularPrediccion.aviso(valorMgDl: 70, umbralHipo: 70, umbralHiper: 180) == nil)
        #expect(CalcularPrediccion.aviso(valorMgDl: 180, umbralHipo: 70, umbralHiper: 180) == nil)
        #expect(
            CalcularPrediccion.aviso(valorMgDl: 69, umbralHipo: 70, umbralHiper: 180)
                == .bajaPrevista
        )
        #expect(
            CalcularPrediccion.aviso(valorMgDl: 181, umbralHipo: 70, umbralHiper: 180)
                == .altaPrevista
        )
    }

    @Test("El vector llega cuantizado a 32 bits")
    func elVectorLlegaEn32Bits() async throws {
        // Los umbrales de los árboles son de 32 bits y XGBoost compara contra ellos con esa
        // precisión. Mandar doble precisión desvía la predicción hasta 1.57 mg/dL en 450 de
        // 2 000 filas.
        let repositorio = try await lecturas([(120, 10), (130.123_456_789_012_34, 5)])
        let modelo = ModeloFalso()
        _ = try await caso(lecturas: repositorio, modelos: [modelo])
            .ejecutar(modo: .sensor, ahora: ahora)

        let vector = try #require(await modelo.ultimoVector)
        #expect(vector["mg_dl"] == Double(Float(130.123_456_789_012_34)))
        #expect(vector["mg_dl"] != 130.123_456_789_012_34)
    }

    @Test("Los huecos llegan como `NaN` y no rellenos")
    func losHuecosLleganComoNaN() async throws {
        // Dos lecturas: no hay rezago de 30 ni de 60. El árbol sabe para qué lado mandar una
        // fila con un hueco; rellenarlo con un cero o con el último valor desvía hasta
        // 19.8 mg/dL.
        let repositorio = try await lecturas([(120, 5), (130, 0)])
        let modelo = ModeloFalso()
        _ = try await caso(lecturas: repositorio, modelos: [modelo])
            .ejecutar(modo: .sensor, ahora: ahora)

        let vector = try #require(await modelo.ultimoVector)
        #expect(vector["rezago_30"]!.isNaN)
        #expect(vector["rezago_60"]!.isNaN)
        #expect(vector["mg_dl"] == 130)
        // El COB y el IOB sí son cero: no hay nada que absorber ni nada activo, no es un dato
        // que falte.
        #expect(vector["cob"] == 0)
        #expect(vector["iob"] == 0)
    }
}
