import Foundation
import Testing
@testable import Glucy

/// El contrato de red con el backend, campo por campo y sin red.
///
/// Es la prueba que vale más de todo el paso. Un nombre de clave equivocado no rompe nada
/// visible: el servidor rechaza el renglón con `extra="forbid"`, lo manda a cuarentena con su
/// motivo, la app lo marca en rojo y nadie entiende por qué. Comprobar el JSON exacto que
/// sale del teléfono es lo que atrapa eso en segundos en lugar de en una tarde.
struct ContratoDeSubidaTests {

    private let ahora = Date(timeIntervalSince1970: 1_793_232_000)

    private func claves(de json: Data) throws -> Set<String> {
        let objeto = try JSONSerialization.jsonObject(with: json)
        let diccionario = try #require(objeto as? [String: Any])
        return Set(diccionario.keys)
    }

    private func texto(_ dato: some Encodable) throws -> String {
        try #require(String(data: try GlucyHTTP.codificador.encode(dato), encoding: .utf8))
    }

    // MARK: - Lecturas

    /// El único campo con nombre distinto a los dos lados. En Swift se llama `contexto` y la
    /// columna es `contexto_comida`; sin la clave explícita el renglón va a cuarentena.
    @Test("El contexto de la comida viaja como contexto_comida, no como contexto")
    func contextoComida() throws {
        let dato = LecturaGlucosaDato(
            mgDl: 112, tsUtc: ahora, zonaHoraria: "America/Monterrey",
            origen: .manual, contexto: .antesDeComer
        )
        let json = try GlucyHTTP.codificador.encode(LecturaSubida(dato))
        #expect(try claves(de: json).contains("contexto_comida"))
        #expect(try claves(de: json).contains("contexto") == false)
        #expect(try texto(LecturaSubida(dato)).contains("\"antes_de_comer\""))
    }

    @Test("Sin contexto, una lectura sube cinco claves con los nombres de las columnas")
    func clavesDeLaLectura() throws {
        let dato = LecturaGlucosaDato(
            mgDl: 112, tsUtc: ahora, zonaHoraria: "America/Monterrey",
            origen: .fotoGlucometro, contexto: nil,
            nota: "privado", valorLeidoOcr: 118, confianzaOcr: 0.4
        )
        let json = try GlucyHTTP.codificador.encode(LecturaSubida(dato))
        #expect(
            try claves(de: json) == ["uuid", "ts_utc", "zona_horaria", "mg_dl", "origen"],
            "el contexto nulo no se escribe, y nada más debe viajar"
        )

        // Y lo que se queda en el teléfono, no está (regla 3 y D-11).
        let salida = try texto(LecturaSubida(dato))
        for prohibido in ["privado", "nota", "confianza", "118", "atipica"] {
            #expect(salida.contains(prohibido) == false, "subió «\(prohibido)»")
        }
    }

    @Test("Los valores de origen son los mismos que el enum del servidor")
    func valoresDeOrigen() throws {
        let esperados = [
            Origen.sensor: "sensor",
            .manual: "manual",
            .fotoGlucometro: "foto_glucometro",
            .barcode: "barcode",
            .ocrEtiqueta: "ocr_etiqueta",
            .healthkit: "healthkit",
        ]
        for (origen, esperado) in esperados {
            let dato = LecturaGlucosaDato(mgDl: 100, tsUtc: ahora, origen: origen)
            #expect(try texto(LecturaSubida(dato)).contains("\"\(esperado)\""))
        }
    }

    // MARK: - La marca de tiempo

    /// Una marca de tiempo sin offset el servidor la manda a cuarentena en lugar de suponer
    /// UTC: suponerlo acertaría casi siempre y desplazaría la serie seis horas el resto.
    @Test("La marca de tiempo sale en ISO 8601 con offset")
    func fechaConOffset() throws {
        let dato = LecturaGlucosaDato(mgDl: 100, tsUtc: ahora, origen: .manual)
        let salida = try texto(LecturaSubida(dato))
        #expect(salida.contains("2026-10-29T"))
        #expect(salida.contains("Z\""), "sin offset el renglón va a cuarentena")
        // Y no como número de segundos, que es lo que haría el codificador por omisión.
        #expect(salida.contains("1793232000") == false)
    }

    // MARK: - Comidas

    @Test("Una comida sube los gramos totales y deja lo del teléfono en el teléfono")
    func clavesDeLaComida() throws {
        let dato = ComidaDato(
            tsUtc: ahora, carbsG: 90, tiempoAbsorcionMin: 180, origen: .barcode,
            descripcion: "dos panes", codigoBarras: "7501055310333",
            nombreProducto: "Pan Bimbo", porcionG: 30, porciones: 3,
            nota: "privado"
        )
        let json = try GlucyHTTP.codificador.encode(ComidaSubida(dato))
        #expect(try claves(de: json) == [
            "uuid", "ts_utc", "zona_horaria", "carbs_g", "origen",
            "tiempo_absorcion_min", "porciones", "codigo_barras",
        ])

        // 90 g son el total de las tres porciones. Si el servidor volviera a multiplicar,
        // los carbohidratos activos saldrían al triple (caso P-11).
        #expect(ComidaSubida(dato).carbsG == 90)
        #expect(ComidaSubida(dato).porciones == 3)

        let salida = try texto(ComidaSubida(dato))
        for prohibido in ["privado", "dos panes", "Pan Bimbo", "porcion_g", "descripcion"] {
            #expect(salida.contains(prohibido) == false, "subió «\(prohibido)»")
        }
    }

    // MARK: - Dosis

    @Test("Una dosis sube seis claves y ningún parámetro de cálculo")
    func clavesDeLaDosis() throws {
        let dato = DosisInsulinaDato(
            tsUtc: ahora, unidades: 4.5, tipo: .bolo, motivo: .comida,
            duracionAccionH: 5, nota: "privado"
        )
        let json = try GlucyHTTP.codificador.encode(DosisSubida(dato))
        #expect(try claves(de: json) == [
            "uuid", "ts_utc", "zona_horaria", "unidades", "tipo", "motivo",
        ])

        // Regla 7: ni relación insulina/carbohidratos ni factor de sensibilidad, nunca.
        let salida = try texto(DosisSubida(dato))
        for prohibido in ["ratio", "sensibilidad", "factor", "privado", "duracion"] {
            #expect(salida.contains(prohibido) == false, "subió «\(prohibido)»")
        }
    }

    @Test("Una dosis sin motivo no inventa uno")
    func dosisSinMotivo() throws {
        let dato = DosisInsulinaDato(tsUtc: ahora, unidades: 10, tipo: .basal)
        let json = try GlucyHTTP.codificador.encode(DosisSubida(dato))
        #expect(try claves(de: json).contains("motivo") == false)
    }

    // MARK: - Perfil

    @Test("Del perfil sube solo el año de nacimiento, no la fecha")
    func perfilSoloElAnio() throws {
        let perfil = PerfilDato(
            nombre: "Ana", apellidos: "Ruiz Soto", pesoKg: 62.5,
            fechaNacimiento: ReglasDePerfil.fechaDeAnio(1990),
            tipoUsuario: .tipo2Insulinodependiente,
            umbralHipo: 80, umbralHiper: 160, duracionAccionInsulinaH: 6,
            tipoInsulinaRapida: "aspart"
        )
        let subido = PerfilSubido(perfil)
        #expect(subido.anioNacimiento == 1990)

        let json = try GlucyHTTP.codificador.encode(subido)
        #expect(try claves(de: json) == [
            "tipo_usuario", "anio_nacimiento", "umbral_hipo", "umbral_hiper",
            "tipo_insulina_rapida", "duracion_accion_insulina",
        ])
        #expect(try texto(subido).contains("\"tipo2_insulinodependiente\""))
    }

    // MARK: - El sobre y la respuesta

    @Test("El sobre del lote es {\"items\": [...]}")
    func elSobre() throws {
        let dato = LecturaGlucosaDato(mgDl: 100, tsUtc: ahora, origen: .manual)
        let json = try GlucyHTTP.codificador.encode(Lote(items: [LecturaSubida(dato)]))
        let objeto = try #require(try JSONSerialization.jsonObject(with: json) as? [String: Any])
        #expect(Set(objeto.keys) == ["items"])
        #expect((objeto["items"] as? [Any])?.count == 1)
    }

    @Test("Las tres listas se leen, y aceptado más duplicado es lo resuelto")
    func lasTresListas() throws {
        let json = """
        {"aceptados":["11111111-1111-1111-1111-111111111111"],
         "duplicados":["22222222-2222-2222-2222-222222222222"],
         "cuarentena":[{"uuid":"33333333-3333-3333-3333-333333333333",
                        "motivo":"mg_dl fuera de 20–600"}]}
        """
        let respuesta = try GlucyHTTP.decodificador.decode(
            RespuestaLote.self, from: Data(json.utf8)
        )
        #expect(respuesta.resueltos.count == 2)
        #expect(respuesta.cuarentena.first?.motivo == "mg_dl fuera de 20–600")
    }

    /// Un renglón tan malo que ni el uuid se pudo leer: la lista lo trae con `uuid` nulo.
    @Test("Un renglón en cuarentena sin uuid legible se decodifica igual")
    func cuarentenaSinUuid() throws {
        let json = """
        {"aceptados":[],"duplicados":[],
         "cuarentena":[{"uuid":null,"motivo":"uuid ilegible"}]}
        """
        let respuesta = try GlucyHTTP.decodificador.decode(
            RespuestaLote.self, from: Data(json.utf8)
        )
        #expect(respuesta.cuarentena.first?.uuid == nil)
        #expect(respuesta.resueltos.isEmpty)
    }

    // MARK: - Los códigos

    @Test("Cada código HTTP se traduce a lo que hace el teléfono")
    func tablaDeCodigos() throws {
        let vacio = Data("{}".utf8)
        #expect(try GlucyHTTP.resultado(codigoHttp: 200, datos: vacio) == vacio)
        // Un 409 se trata como duplicado, no como falla.
        #expect(try GlucyHTTP.resultado(codigoHttp: 409, datos: vacio) == vacio)

        #expect(throws: ErrorBackend.tokenRechazado) {
            try GlucyHTTP.resultado(codigoHttp: 401, datos: vacio)
        }
        #expect(throws: ErrorBackend.servidorFallo(codigoHttp: 503)) {
            try GlucyHTTP.resultado(codigoHttp: 503, datos: vacio)
        }
        #expect(throws: ErrorBackend.servidorFallo(codigoHttp: 418)) {
            try GlucyHTTP.resultado(codigoHttp: 418, datos: vacio)
        }
    }

    @Test("El 400 conserva el detalle del servidor para poder diagnosticarlo")
    func detalleDel400() throws {
        let cuerpo = Data(#"{"detail":"items: campo no permitido «nota»"}"#.utf8)
        do {
            _ = try GlucyHTTP.resultado(codigoHttp: 400, datos: cuerpo)
            Issue.record("un 400 tiene que lanzar")
        } catch ErrorBackend.sobreInvalido(let detalle) {
            #expect(detalle.contains("campo no permitido"))
        }
    }

    // MARK: - Sin configuración

    @Test("Sin URL y sin token no se intenta nada: la app funciona igual")
    func sinConfiguracion() async {
        #expect(ConfiguracionBackend().estaConfigurado == false)
        #expect(ConfiguracionBackend.desdeBundle(Bundle(for: PruebaDeBundle.self)).url == nil)

        let cliente = GlucyHTTP(
            configuracion: ConfiguracionBackend(), almacen: AlmacenFalso(token: "t")
        )
        await #expect(throws: ErrorBackend.sinConfiguracion) {
            _ = try await cliente.subirLecturas([])
        }

        // Con URL pero sin token, lo mismo: no se manda una petición sin autorización.
        let conUrl = GlucyHTTP(
            configuracion: ConfiguracionBackend(url: URL(string: "https://glucy.invalid")),
            almacen: AlmacenFalso()
        )
        await #expect(throws: ErrorBackend.sinConfiguracion) {
            _ = try await conUrl.subirLecturas([])
        }
    }

    @Test("El tope de renglones por lote no pasa de los 500 que acepta el servidor")
    func topeDeLote() {
        #expect(ConfiguracionBackend(renglonesPorLote: 10_000).renglonesPorLote == 500)
        #expect(ConfiguracionBackend(renglonesPorLote: 0).renglonesPorLote == 1)
        #expect(ConfiguracionBackend().renglonesPorLote == 500)
    }
}

/// Solo para tomar el bundle de las pruebas en `desdeBundle`.
private final class PruebaDeBundle {}
