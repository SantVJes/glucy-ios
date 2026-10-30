import Foundation
import Testing
@testable import Glucy

/// Para leer el caso `.llego` sin repetir un `guard case` en cada prueba.
extension ResultadoDelServidor {
    var aportes: [FactoresYExplicacion]? {
        if case let .llego(aportes) = self { aportes } else { nil }
    }
}

/// Los factores y la explicación: qué se le manda al servidor, qué se guarda y qué se enseña.
///
/// Dos pruebas de aquí son las que importan: `elSobreLlevaElNumeroDelTelefono`, porque la
/// frase tiene que explicar el número que la pantalla enseña y no otro, y
/// `unFactorSinTraducirNoSeEnsena`, porque la app no traduce nombres de características y un
/// «rezago_45» en la pantalla sería el síntoma de que alguien copió el diccionario en Swift.
struct PedirFactoresYExplicacionTests {

    private let base = Date(timeIntervalSince1970: 1_758_240_000)

    private func proyeccion(
        _ valorMgDl: Double, horizonteMin: Int, baseMgDl: Double = 145
    ) -> Proyeccion {
        Proyeccion(
            horizonteMin: horizonteMin,
            valorMgDl: valorMgDl,
            objetivo: base.addingTimeInterval(Double(horizonteMin) * 60),
            base: Proyeccion.Base(ts: base, mgDl: baseMgDl),
            versionModelo: "m1-v0.2.0-simulador",
            aviso: nil
        )
    }

    private func horizonte(
        _ horizonteMin: Int,
        valorPredicho: Double,
        factores: [(String, Double)] = [("tu glucosa de ahora", 12.5)],
        shap: [(String, Double)] = [("mg_dl", 12.5), ("rezago_5", -3.1)]
    ) -> HorizonteRemoto {
        HorizonteRemoto(
            horizonteMin: horizonteMin,
            tsObjetivo: base.addingTimeInterval(Double(horizonteMin) * 60),
            valorPredicho: valorPredicho,
            modeloVersion: "m1-v0.2.0-simulador",
            alerta: nil,
            shap: shap.map { ContribucionRemota(variable: $0.0, mgDl: $0.1) },
            factores: factores.map { FactorRemoto(nombre: $0.0, mgDl: $0.1) }
        )
    }

    private func remota(
        _ predicciones: [HorizonteRemoto], tsBase: Date?, aviso: String? = nil
    ) -> PrediccionRemota {
        PrediccionRemota(
            tsUtc: base.addingTimeInterval(120),
            modo: .sensor,
            valorActual: 148,
            antiguedadMin: 2,
            tsBase: tsBase,
            valorBase: 145,
            puedeAlertarHipoglucemia: true,
            umbralHipo: 70,
            umbralHiper: 180,
            predicciones: predicciones,
            aviso: aviso
        )
    }

    private func explicacion(
        _ texto: String, origen: OrigenExplicacion = .modelo
    ) -> ExplicacionRemota {
        ExplicacionRemota(explicacion: texto, origen: origen, motivo: nil, modelo: "qwen3:8b")
    }

    // MARK: - El camino normal

    @Test("Llegan los factores y la frase, y quedan guardados")
    func lleganYSeGuardan() async throws {
        let backend = BackendFalso()
        await backend.responder(prediccion: .success(remota(
            [horizonte(30, valorPredicho: 142.4), horizonte(60, valorPredicho: 137.3)],
            tsBase: base
        )))
        await backend.responder(explicacion: .success(
            explicacion("Vas a bajar un poco en la próxima media hora.")
        ))
        let cache = PrediccionCacheFalso()

        let resultado = await PedirFactoresYExplicacion(backend: backend, cache: cache)
            .ejecutar(
                proyecciones: [proyeccion(142, horizonteMin: 30), proyeccion(137, horizonteMin: 60)],
                modo: .sensor, umbralHipo: 70, umbralHiper: 180, cobG: 30, iobUI: 1.2
            )

        let aportes = try #require(resultado.aportes)
        #expect(aportes.count == 2)
        #expect(aportes[0].horizonteMin == 30)
        #expect(aportes[0].explicacion == "Vas a bajar un poco en la próxima media hora.")
        #expect(aportes[0].deLaPlantilla == false)
        #expect(aportes[0].paraLaPantalla.map(\.nombre) == ["tu glucosa de ahora"])
        // La frase se pide una sola vez: para el horizonte que la pantalla enseña. Pedir las
        // dos duplicaría una llamada de tres segundos por una frase que nadie va a leer.
        #expect(aportes[1].explicacion == nil)
        let pedidas = await backend.explicacionesPedidas
        #expect(pedidas.count == 1)

        // Lo guardado es el número del teléfono, el de los dos horizontes.
        let guardadas = try await cache.todas()
        #expect(guardadas.count == 2)
        #expect(guardadas.first?.valorMgDl == 142)
        #expect(guardadas.first?.versionModelo == "m1-v0.2.0-simulador")
        #expect(guardadas.first?.explicacion != nil)
    }

    /// La prueba que más importa de este archivo, con la de abajo.
    @Test("El sobre de /explain lleva el número del teléfono y no el del servidor")
    func elSobreLlevaElNumeroDelTelefono() async throws {
        let backend = BackendFalso()
        // El servidor dice 142.4; el teléfono calculó 139.
        await backend.responder(prediccion: .success(
            remota([horizonte(30, valorPredicho: 142.4)], tsBase: base)
        ))
        await backend.responder(explicacion: .success(explicacion("Una frase.")))

        _ = await PedirFactoresYExplicacion(backend: backend, cache: nil).ejecutar(
            proyecciones: [proyeccion(139, horizonteMin: 30, baseMgDl: 145)],
            modo: .sensor, umbralHipo: 70, umbralHiper: 180, cobG: 30, iobUI: 1.2
        )

        let pedidas = await backend.explicacionesPedidas
        let sobre = try #require(pedidas.first)
        // La frase tiene que explicar el número que la pantalla enseña (C-16), no el del
        // servidor: si viaja el ajeno, la explicación habla de una cifra que nadie ve.
        #expect(sobre.valorPredicho == 139)
        #expect(sobre.valorActual == 145)
        #expect(sobre.horizonteMin == 30)
        #expect(sobre.cobG == 30)
        #expect(sobre.iobUI == 1.2)
        #expect(sobre.umbralHipo == 70)
        #expect(sobre.shap.count == 2)
        #expect(sobre.asistenteActivo)
    }

    @Test("Con el asistente apagado el sobre lo dice, y la frase se pide igual")
    func elAsistenteApagadoViajaEnElSobre() async throws {
        let backend = BackendFalso()
        await backend.responder(prediccion: .success(
            remota([horizonte(30, valorPredicho: 142)], tsBase: base)
        ))
        await backend.responder(explicacion: .success(explicacion("Una frase.")))

        let resultado = await PedirFactoresYExplicacion(backend: backend, cache: nil).ejecutar(
            proyecciones: [proyeccion(142, horizonteMin: 30)],
            modo: .sensor, umbralHipo: 70, umbralHiper: 180, cobG: 0, iobUI: 0,
            asistenteActivo: false
        )

        // Se pide igual: apagado no quiere decir sin frase, quiere decir que la arma el
        // servidor con la plantilla determinista y sin llamar a ningún modelo de lenguaje.
        let pedidas = await backend.explicacionesPedidas
        let sobre = try #require(pedidas.first)
        #expect(sobre.asistenteActivo == false)
        let aportes = try #require(resultado.aportes)
        #expect(aportes[0].explicacion == "Una frase.")
    }

    @Test("Nunca se mandan más de cinco contribuciones")
    func nuncaMasDeCinco() throws {
        let siete = (0..<7).map { ContribucionRemota(variable: "v\($0)", mgDl: Double($0)) }
        let sobre = try #require(PedirFactoresYExplicacion.sobre(
            proyeccion: proyeccion(142, horizonteMin: 30),
            shap: siete,
            umbralHipo: 70, umbralHiper: 180, cobG: 0, iobUI: 0, asistenteActivo: true
        ))
        #expect(sobre.shap.count == ExplicacionPedida.contribucionesShap)
        #expect(sobre.sirveParaMandar)

        // Y sin contribuciones no se arma sobre: el servidor lo rechazaría con un 400, que no
        // se reintenta, y la explicación se perdería sin que nada lo dijera.
        #expect(PedirFactoresYExplicacion.sobre(
            proyeccion: proyeccion(142, horizonteMin: 30),
            shap: [],
            umbralHipo: 70, umbralHiper: 180, cobG: 0, iobUI: 0, asistenteActivo: true
        ) == nil)
    }

    // MARK: - Lo que no se enseña

    /// La otra prueba que importa.
    @Test("Un factor que llegó sin traducir no se enseña, y no se inventa una traducción")
    func unFactorSinTraducirNoSeEnsena() async throws {
        let backend = BackendFalso()
        await backend.responder(prediccion: .success(remota(
            [horizonte(30, valorPredicho: 142, factores: [
                ("tu glucosa de ahora", 12.5),
                ("rezago_45", -3.0),
                // `iob` no lleva guion bajo y es nombre de columna igual: se comprueba contra
                // la lista de características, que es el contrato con el pipeline.
                ("iob", -8.0),
                ("", 1.0),
            ])],
            tsBase: base
        )))
        await backend.responder(explicacion: .success(explicacion("Una frase.")))

        let resultado = await PedirFactoresYExplicacion(backend: backend, cache: nil).ejecutar(
            proyecciones: [proyeccion(142, horizonteMin: 30)],
            modo: .sensor, umbralHipo: 70, umbralHiper: 180, cobG: 0, iobUI: 0
        )

        let aportes = try #require(resultado.aportes)
        // Los cuatro llegaron; solo uno se puede enseñar. Los otros son nombres de columna
        // del modelo, y eso es un error del servidor, no algo que la app deba traducir.
        #expect(aportes[0].factores.count == 4)
        #expect(aportes[0].paraLaPantalla.map(\.nombre) == ["tu glucosa de ahora"])
    }

    // MARK: - Los dos caminos

    @Test("Un desacuerdo de más de 1 mg/dL se registra; el redondeo no")
    func elDesacuerdoSeRegistra() {
        let propia = proyeccion(142, horizonteMin: 30)

        // Mismo instante base y tres mg/dL de diferencia: eso no es redondeo.
        #expect(PedirFactoresYExplicacion.desacuerdo(
            propio: propia, delServidor: 145, tsBaseDelServidor: base
        ) == 3)

        // Medio mg/dL es el redondeo de cuantizar la entrada a 32 bits en el teléfono y no en
        // el servidor. No se registra.
        #expect(PedirFactoresYExplicacion.desacuerdo(
            propio: propia, delServidor: 142.5, tsBaseDelServidor: base
        ) == nil)

        // Instantes distintos: cada camino partió de otra lectura, así que la diferencia no
        // dice nada de la implementación y compararlos sería inventar un problema.
        #expect(PedirFactoresYExplicacion.desacuerdo(
            propio: propia,
            delServidor: 200,
            tsBaseDelServidor: base.addingTimeInterval(300)
        ) == nil)

        // Sin instante del servidor tampoco hay comparación posible.
        #expect(PedirFactoresYExplicacion.desacuerdo(
            propio: propia, delServidor: 200, tsBaseDelServidor: nil
        ) == nil)

        // En el borde de los treinta segundos todavía se comparan.
        #expect(PedirFactoresYExplicacion.desacuerdo(
            propio: propia,
            delServidor: 145,
            tsBaseDelServidor: base.addingTimeInterval(
                ConfiguracionDominio.mismoInstanteBaseSeg
            )
        ) == 3)
    }

    // MARK: - Cuando no hay nadie del otro lado

    @Test("Sin backend configurado no se pide nada y la app sigue completa")
    func sinBackend() async {
        let cache = PrediccionCacheFalso()
        let resultado = await PedirFactoresYExplicacion(backend: nil, cache: cache).ejecutar(
            proyecciones: [proyeccion(142, horizonteMin: 30)],
            modo: .sensor, umbralHipo: 70, umbralHiper: 180, cobG: 0, iobUI: 0
        )

        #expect(resultado == .sinBackend)
        let veces = await cache.vecesQueSeGuardo
        #expect(veces == 0)
    }

    @Test("Si el servidor no contesta, se dice el motivo y no se enseña nada ajeno")
    func siNoContesta() async {
        let backend = BackendFalso()
        await backend.responder(prediccion: .failure(.sinRed))

        let resultado = await PedirFactoresYExplicacion(backend: backend, cache: nil).ejecutar(
            proyecciones: [proyeccion(142, horizonteMin: 30)],
            modo: .sensor, umbralHipo: 70, umbralHiper: 180, cobG: 0, iobUI: 0
        )

        if case let .noLlego(motivo) = resultado {
            #expect(motivo.isEmpty == false)
        } else {
            #expect(resultado.aportes == nil)
        }
    }

    @Test("En modo sin sensor el servidor contesta sin predicciones, y eso no es un error")
    func sinSensorElServidorNoPredice() async {
        let backend = BackendFalso()
        await backend.responder(prediccion: .success(remota(
            [], tsBase: nil, aviso: "Sin sensor conectado no se puede anticipar una baja."
        )))

        let resultado = await PedirFactoresYExplicacion(backend: backend, cache: nil).ejecutar(
            proyecciones: [proyeccion(142, horizonteMin: 30)],
            modo: .sensor, umbralHipo: 70, umbralHiper: 180, cobG: 0, iobUI: 0
        )

        #expect(resultado == .noLlego(
            motivo: "Sin sensor conectado no se puede anticipar una baja."
        ))
    }

    @Test("Si la frase no llega, los factores sí se guardan")
    func siLaFraseNoLlegaLosFactoresSi() async throws {
        let backend = BackendFalso()
        await backend.responder(prediccion: .success(
            remota([horizonte(30, valorPredicho: 142)], tsBase: base)
        ))
        await backend.responder(explicacion: .failure(.servidorFallo(codigoHttp: 500)))
        let cache = PrediccionCacheFalso()

        let resultado = await PedirFactoresYExplicacion(backend: backend, cache: cache).ejecutar(
            proyecciones: [proyeccion(142, horizonteMin: 30)],
            modo: .sensor, umbralHipo: 70, umbralHiper: 180, cobG: 0, iobUI: 0
        )

        let aportes = try #require(resultado.aportes)
        #expect(aportes[0].explicacion == nil)
        #expect(aportes[0].paraLaPantalla.isEmpty == false)
        let guardadas = try await cache.todas()
        #expect(guardadas.count == 1)
    }

    // MARK: - Lo guardado

    @Test("Lo guardado se puede volver a leer sin red")
    func loGuardadoSeLee() async throws {
        let cache = PrediccionCacheFalso()
        await cache.sembrar(PrediccionGuardadaDato(
            tsUtc: base,
            horizonteMin: 30,
            valorMgDl: 142,
            modo: .sensor,
            versionModelo: "m1-v0.2.0-simulador",
            explicacion: "La de la vez pasada.",
            factores: [FactorDeLaPrediccion(nombre: "tu glucosa de ahora", mgDl: 12.5)],
            shap: [ContribucionDeLaPrediccion(variable: "mg_dl", mgDl: 12.5)]
        ))

        let leido = await PedirFactoresYExplicacion(backend: nil, cache: cache)
            .loQueHayGuardado(horizonteMin: 30)
        let guardado = try #require(leido)
        #expect(guardado.explicacion == "La de la vez pasada.")
        #expect(guardado.paraLaPantalla.count == 1)
        // De lo guardado no se sabe si los dos caminos partieron del mismo instante, así que
        // no se afirma ningún desacuerdo.
        #expect(guardado.desacuerdoMgDl == nil)

        // Un horizonte del que no hay nada guardado no devuelve nada.
        let nada = await PedirFactoresYExplicacion(backend: nil, cache: cache)
            .loQueHayGuardado(horizonteMin: 60)
        #expect(nada == nil)
    }

    @Test("El JSON de los factores y las contribuciones va y vuelve igual")
    func elJsonVaYVuelve() throws {
        let factores = [
            FactorDeLaPrediccion(nombre: "tu glucosa de ahora", mgDl: 12.5),
            FactorDeLaPrediccion(nombre: "la insulina que sigue activa", mgDl: -20),
        ]
        let shap = [ContribucionDeLaPrediccion(variable: "mg_dl", mgDl: 12.5)]

        let json = try #require(FactoresSerializados.json(factores: factores, shap: shap))
        let devuelto = try #require(FactoresSerializados.desde(json: json))
        #expect(devuelto.comoFactores == factores)
        #expect(devuelto.shap == shap)

        // Sin nada que guardar no se escribe un JSON vacío en la fila.
        #expect(FactoresSerializados.json(factores: [], shap: []) == nil)
        #expect(FactoresSerializados.desde(json: nil) == nil)
        #expect(FactoresSerializados.desde(json: "no es json") == nil)
    }
}
