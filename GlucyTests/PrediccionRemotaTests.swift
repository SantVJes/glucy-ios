import Foundation
import Testing
@testable import Glucy

/// La traducción de lo que contestan `GET /predict` y `POST /explain`, sobre respuestas
/// **escritas a mano**. Aquí no hay red: ninguna prueba ejecuta una petición de verdad.
///
/// Las respuestas se copiaron de los esquemas de `glucy-backend` (`app/schemas/prediccion.py`
/// y `app/schemas/explicacion.py`), que son la autoridad. Si alguien cambia un nombre de campo
/// allá, estas pruebas son lo que se rompe aquí, y es lo que se quiere: un campo renombrado que
/// se decodifica como `nil` deja la pantalla de factores vacía sin que nada falle.
struct PrediccionRemotaTests {

    // MARK: - GET /predict

    @Test("Una respuesta de /predict en modo sensor se lee campo por campo")
    func prediccionConSensor() throws {
        let json = """
        {"ts_utc":"2026-10-30T00:35:12.481000+00:00",
         "modo":"sensor",
         "valor_actual":148.0,
         "antiguedad_min":3.2,
         "ts_base":"2026-10-30T00:32:00+00:00",
         "valor_base":145.0,
         "puede_alertar_hipoglucemia":true,
         "umbral_hipo":70.0,
         "umbral_hiper":180.0,
         "predicciones":[
           {"horizonte_min":30,
            "ts_objetivo":"2026-10-30T01:02:00+00:00",
            "valor_predicho":142.4,
            "modelo_version":"m1-v0.2.0-simulador",
            "alerta":null,
            "shap":[{"variable":"mg_dl","mg_dl":12.5},{"variable":"rezago_5","mg_dl":-3.1}],
            "factores":[{"nombre":"tu glucosa de ahora","mg_dl":12.5},
                        {"nombre":"cómo venías hace 5 minutos","mg_dl":-3.1}]},
           {"horizonte_min":60,
            "ts_objetivo":"2026-10-30T01:32:00+00:00",
            "valor_predicho":64.0,
            "modelo_version":"m2-v0.2.0-simulador",
            "alerta":"hipoglucemia",
            "shap":[{"variable":"iob","mg_dl":-20.0}],
            "factores":[{"nombre":"la insulina que sigue activa","mg_dl":-20.0}]}],
         "aviso":null}
        """
        let remota = try GlucyHTTP.prediccion(desde: Data(json.utf8))

        #expect(remota.modo == .sensor)
        #expect(remota.valorActual == 148)
        #expect(remota.antiguedadMin == 3.2)
        #expect(remota.valorBase == 145)
        #expect(remota.puedeAlertarHipoglucemia)
        #expect(remota.umbralHipo == 70)
        #expect(remota.umbralHiper == 180)
        #expect(remota.aviso == nil)
        #expect(remota.predicciones.count == 2)

        // `valor_actual` y `valor_base` son dos cosas distintas, y por eso se comprueban las
        // dos: un pinchazo capturado después de la última lectura del sensor mueve el primero
        // y no el segundo. La pantalla enseña el primero como «ahora» y predice desde el
        // segundo, que es donde el servidor armó la fila.
        #expect(remota.valorActual != remota.valorBase)
        let base = try #require(remota.tsBase)
        #expect(remota.tsUtc > base)

        let media = try #require(remota.predicciones.first)
        #expect(media.horizonteMin == 30)
        #expect(media.valorPredicho == 142.4)
        #expect(media.modeloVersion == "m1-v0.2.0-simulador")
        #expect(media.alerta == nil)
        #expect(media.shap.map(\.variable) == ["mg_dl", "rezago_5"])
        #expect(media.shap.map(\.mgDl) == [12.5, -3.1])
        #expect(media.factores.map(\.nombre) == [
            "tu glucosa de ahora", "cómo venías hace 5 minutos",
        ])
        // El horizonte se cuenta desde `ts_base`, no desde `ts_utc`: 00:32 más 30 minutos son
        // 01:02, y no 01:05, que es lo que daría el reloj.
        #expect(media.tsObjetivo == base.addingTimeInterval(30 * 60))

        let hora = try #require(remota.predicciones.last)
        #expect(hora.alerta == .hipoglucemia)
        #expect(hora.tsObjetivo == base.addingTimeInterval(60 * 60))
    }

    @Test("En modo sin sensor no vienen predicciones y sí viene el aviso de RF-10b")
    func prediccionSinSensor() throws {
        let json = """
        {"ts_utc":"2026-10-30T00:35:12.481000+00:00",
         "modo":"sin_sensor",
         "valor_actual":132.0,
         "antiguedad_min":95.0,
         "puede_alertar_hipoglucemia":false,
         "umbral_hipo":70.0,
         "umbral_hiper":180.0,
         "predicciones":[],
         "aviso":"Sin sensor conectado no se puede anticipar una glucosa baja."}
        """
        let remota = try GlucyHTTP.prediccion(desde: Data(json.utf8))

        #expect(remota.modo == .sinSensor)
        #expect(remota.predicciones.isEmpty)
        #expect(remota.puedeAlertarHipoglucemia == false)
        #expect(remota.aviso != nil)
        // Sin sensor no hay fila ni base, y los dos campos llegan ausentes del JSON. Que se
        // decodifiquen como `nil` y no revienten es lo que se comprueba.
        #expect(remota.tsBase == nil)
        #expect(remota.valorBase == nil)
    }

    @Test("Una respuesta que no se puede leer es respuestaIlegible y no un valor a medias")
    func respuestaIlegible() {
        #expect(throws: ErrorBackend.respuestaIlegible) {
            try GlucyHTTP.prediccion(desde: Data("{\"modo\":\"sensor\"}".utf8))
        }
        #expect(throws: ErrorBackend.respuestaIlegible) {
            try GlucyHTTP.prediccion(desde: Data("no es json".utf8))
        }
    }

    @Test("Una fecha sin fracción de segundo y una con ella se leen las dos")
    func lasDosFormasDeFecha() throws {
        let conFraccion = try #require(GlucyHTTP.fecha(desde: "2026-10-30T00:32:00.125000+00:00"))
        let sinFraccion = try #require(GlucyHTTP.fecha(desde: "2026-10-30T00:32:00+00:00"))
        #expect(abs(conFraccion.timeIntervalSince(sinFraccion) - 0.125) < 0.001)

        // La «Z» y el «+00:00» son la misma cosa, y FastAPI usa las dos según el campo.
        let conZeta = try #require(GlucyHTTP.fecha(desde: "2026-10-30T00:32:00Z"))
        #expect(conZeta == sinFraccion)

        // Sin zona se toma como UTC: el servidor de Glucy guarda y responde todo en UTC.
        let sinZona = try #require(GlucyHTTP.fecha(desde: "2026-10-30T00:32:00"))
        #expect(sinZona == sinFraccion)

        #expect(GlucyHTTP.fecha(desde: "ayer") == nil)
        #expect(GlucyHTTP.fecha(desde: "") == nil)

        // Los microsegundos de Python se recortan a milisegundos. Sin recorte,
        // `ISO8601DateFormatter` devuelve `nil` y la respuesta entera se vuelve ilegible.
        #expect(GlucyHTTP.recortarFraccion("2026-10-30T00:32:00.481000+00:00")
            == "2026-10-30T00:32:00.481+00:00")
        #expect(GlucyHTTP.recortarFraccion("2026-10-30T00:32:00.481Z")
            == "2026-10-30T00:32:00.481Z")
        #expect(GlucyHTTP.recortarFraccion("2026-10-30T00:32:00Z") == "2026-10-30T00:32:00Z")
        let recortada = try #require(GlucyHTTP.fecha(desde: "2026-10-30T00:32:00.481999Z"))
        #expect(abs(recortada.timeIntervalSince(sinFraccion) - 0.481) < 0.001)
    }

    @Test("Sin artefacto el servidor manda 503, y ese lote se reintenta")
    func sinArtefactoSeReintenta() {
        // `GET /predict` contesta `503` cuando no hay modelo cargado, y a propósito no manda
        // ningún número de respaldo. Para el teléfono eso es «el servidor está mal, no el
        // dato»: se vuelve a intentar y la pantalla no enseña nada ajeno.
        #expect(throws: ErrorBackend.servidorFallo(codigoHttp: 503)) {
            try GlucyHTTP.resultado(codigoHttp: 503, datos: Data())
        }
        #expect(ErrorBackend.servidorFallo(codigoHttp: 503).seReintenta)
    }

    // MARK: - POST /explain

    /// **La prueba que importa de este archivo.** El sobre de `/explain` es lo único de todo
    /// el sistema que acaba en el prompt de un modelo de lenguaje, así que lo que va dentro se
    /// fija aquí nombre por nombre: ni uno más (regla 3).
    @Test("Regla 3: el sobre de /explain lleva once campos y ninguno identifica a la persona")
    func elSobreNoIdentificaANadie() throws {
        let entrada = ExplicacionPedida(
            valorActual: 148,
            valorPredicho: 142.4,
            horizonteMin: 30,
            modo: .sensor,
            umbralHipo: 70,
            umbralHiper: 180,
            cobG: 30,
            iobUI: 1.2,
            horaLocal: 18,
            shap: [ContribucionRemota(variable: "mg_dl", mgDl: 12.5)],
            asistenteActivo: true
        )
        let datos = try GlucyHTTP.codificador.encode(entrada)
        // El `jsonObject` sale a su propia línea: un `try` dentro de la macro `#require` se
        // le atraviesa al comprobador de tipos sin necesidad.
        let objeto = try JSONSerialization.jsonObject(with: datos)
        let sobre = try #require(objeto as? [String: Any])

        #expect(Set(sobre.keys) == [
            "valor_actual", "valor_predicho", "horizonte_min", "modo",
            "umbral_hipo", "umbral_hiper", "cob_g", "iob_ui", "hora_local",
            "shap", "asistente_activo",
        ])
        // Dicho también por el lado que falla si alguien agrega un campo sin pensarlo.
        for prohibido in [
            "nombre", "apellidos", "peso_kg", "nota", "usuario_uuid", "anio_nacimiento",
            "ubicacion", "historial", "uuid",
        ] {
            #expect(sobre[prohibido] == nil)
        }
        #expect(sobre["modo"] as? String == "sensor")
    }

    @Test("Un sobre con cero o con seis contribuciones no se manda")
    func elSobreSeComprueba() {
        func sobre(contribuciones: Int, horaLocal: Int = 18) -> ExplicacionPedida {
            ExplicacionPedida(
                valorActual: 148, valorPredicho: 142, horizonteMin: 30, modo: .sensor,
                umbralHipo: 70, umbralHiper: 180, cobG: 0, iobUI: 0, horaLocal: horaLocal,
                shap: (0..<contribuciones).map {
                    ContribucionRemota(variable: "v\($0)", mgDl: Double($0))
                },
                asistenteActivo: true
            )
        }

        #expect(sobre(contribuciones: 0).sirveParaMandar == false)
        #expect(sobre(contribuciones: 1).sirveParaMandar)
        #expect(sobre(contribuciones: 5).sirveParaMandar)
        #expect(sobre(contribuciones: 6).sirveParaMandar == false)
        #expect(sobre(contribuciones: 3, horaLocal: 24).sirveParaMandar == false)
        #expect(sobre(contribuciones: 3, horaLocal: -1).sirveParaMandar == false)
        #expect(ExplicacionPedida.contribucionesShap == 5)
    }

    @Test("La explicación dice de dónde salió, y un motivo nuevo no tira la respuesta")
    func laExplicacionDiceSuOrigen() throws {
        let delModelo = try GlucyHTTP.decodificador.decode(
            ExplicacionRemota.self,
            from: Data("""
            {"explicacion":"Vas a bajar en la próxima media hora.",
             "origen":"modelo","motivo":null,"modelo":"qwen3:8b"}
            """.utf8)
        )
        #expect(delModelo.origen == .modelo)
        #expect(delModelo.motivo == nil)
        #expect(delModelo.modelo == "qwen3:8b")

        let deLaPlantilla = try GlucyHTTP.decodificador.decode(
            ExplicacionRemota.self,
            from: Data("""
            {"explicacion":"Estimación a 30 minutos.","origen":"plantilla",
             "motivo":"sin_respuesta"}
            """.utf8)
        )
        #expect(deLaPlantilla.origen == .plantilla)
        #expect(deLaPlantilla.motivo == "sin_respuesta")
        #expect(deLaPlantilla.modelo == nil)

        // El motivo se deja como texto a propósito: un motivo que el servidor agregue mañana
        // no tiene por qué tirar una frase que ya llegó y que la persona podría leer.
        let motivoNuevo = try GlucyHTTP.decodificador.decode(
            ExplicacionRemota.self,
            from: Data("""
            {"explicacion":"Estimación.","origen":"plantilla","motivo":"algo_que_no_existia"}
            """.utf8)
        )
        #expect(motivoNuevo.motivo == "algo_que_no_existia")
    }
}
