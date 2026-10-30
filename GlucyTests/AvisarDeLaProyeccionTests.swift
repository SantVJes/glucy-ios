import Foundation
import Testing
@testable import Glucy

/// Una etiqueta corta de cada resultado, para poder compararla con `==` sin tener que mirar
/// el UUID de la alerta, que es distinto en cada pasada.
extension ResultadoDelAviso {
    var etiqueta: String {
        switch self {
        case .avisado: "avisado"
        case .registradaSinPermiso: "registradaSinPermiso"
        case .nadaQueAvisar: "nadaQueAvisar"
        case .sinSensorNoSeAnticipa: "sinSensorNoSeAnticipa"
        case .yaSeAviso: "yaSeAviso"
        }
    }

    var alerta: AlertaDato? {
        switch self {
        case let .avisado(alerta), let .registradaSinPermiso(alerta), let .yaSeAviso(alerta):
            alerta
        case .nadaQueAvisar, .sinSensorNoSeAnticipa:
            nil
        }
    }
}

/// El aviso de hipoglucemia prevista: cuándo sale, cuándo no, y qué dice.
///
/// La prueba que más importa de este archivo es `elAvisoNoDaNingunaIndicacion`: es la regla 7
/// —la frontera con un dispositivo médico regulado— comprobada sobre el único texto de la app
/// que llega a la pantalla de bloqueo sin que nadie lo lea antes.
struct AvisarDeLaProyeccionTests {

    private let ahora = Date(timeIntervalSince1970: 1_758_240_000)

    private func proyeccion(
        _ valorMgDl: Double, horizonteMin: Int, aviso: AvisoPrevisto?
    ) -> Proyeccion {
        Proyeccion(
            horizonteMin: horizonteMin,
            valorMgDl: valorMgDl,
            objetivo: ahora.addingTimeInterval(Double(horizonteMin) * 60),
            base: Proyeccion.Base(ts: ahora, mgDl: 110),
            versionModelo: "m1-v0.2.0-prueba",
            aviso: aviso
        )
    }

    // MARK: - Cuándo sale y cuándo no

    @Test("Una baja prevista se registra, se entrega y guarda el umbral del perfil")
    func unaBajaPrevistaAvisa() async throws {
        let registro = RepositorioAlertasFalso()
        let avisos = AvisosFalsos(
            permiso: .concedido, respondeAlPedir: true, falloAlEntregar: nil
        )
        let caso = AvisarDeLaProyeccion(alertas: registro, avisos: avisos)

        let resultado = try await caso.ejecutar(
            proyecciones: [proyeccion(64, horizonteMin: 30, aviso: .bajaPrevista)],
            modo: .sensor,
            umbralHipo: 80,
            ahora: ahora
        )
        #expect(resultado.etiqueta == "avisado")

        let alerta = try #require(resultado.alerta)
        #expect(alerta.valorMgDl == 64)
        // El umbral que se guarda es el del perfil, 80, y no el de por omisión: quien lo movió
        // quiere que se le avise en 80, y sin guardarlo no se podría explicar después por qué
        // se avisó de un 75.
        #expect(alerta.umbralMgDl == 80)
        #expect(alerta.horizonteMin == 30)
        #expect(alerta.modo == .sensor)
        #expect(alerta.esBaja)

        let guardadas = await registro.guardadas
        #expect(guardadas.count == 1)
        #expect(guardadas.first?.entregada == true)

        let entregados = await avisos.entregados
        #expect(entregados.count == 1)
        // El identificador del aviso es el de la alerta: así el sistema reemplaza y no apila.
        #expect(entregados.first?.identificador == alerta.uuid.uuidString)
        #expect(entregados.first?.vibra == true)
    }

    /// Caso P-04 y regla 8.
    @Test("P-04: en modo sin sensor no se avisa ni se registra nada")
    func sinSensorNoSeAvisa() async throws {
        let registro = RepositorioAlertasFalso()
        let avisos = AvisosFalsos(
            permiso: .concedido, respondeAlPedir: true, falloAlEntregar: nil
        )

        let resultado = try await AvisarDeLaProyeccion(alertas: registro, avisos: avisos)
            .ejecutar(
                proyecciones: [proyeccion(50, horizonteMin: 30, aviso: .bajaPrevista)],
                modo: .sinSensor,
                umbralHipo: 70,
                ahora: ahora
            )

        #expect(resultado == .sinSensorNoSeAnticipa)
        let guardadas = await registro.guardadas
        let entregados = await avisos.entregados
        #expect(guardadas.isEmpty)
        #expect(entregados.isEmpty)
    }

    @Test("Una alta prevista no manda notificación: se queda en la pantalla")
    func unaAltaPrevistaNoNotifica() async throws {
        let registro = RepositorioAlertasFalso()
        let avisos = AvisosFalsos(
            permiso: .concedido, respondeAlPedir: true, falloAlEntregar: nil
        )

        let resultado = try await AvisarDeLaProyeccion(alertas: registro, avisos: avisos)
            .ejecutar(
                proyecciones: [proyeccion(260, horizonteMin: 30, aviso: .altaPrevista)],
                modo: .sensor,
                umbralHipo: 70,
                ahora: ahora
            )

        #expect(resultado == .nadaQueAvisar)
        let entregados = await avisos.entregados
        #expect(entregados.isEmpty)
    }

    @Test("Entre los umbrales no hay nada que avisar")
    func entreLosUmbralesNoAvisa() async throws {
        let registro = RepositorioAlertasFalso()
        let avisos = AvisosFalsos(
            permiso: .concedido, respondeAlPedir: true, falloAlEntregar: nil
        )

        let resultado = try await AvisarDeLaProyeccion(alertas: registro, avisos: avisos)
            .ejecutar(
                proyecciones: [
                    proyeccion(120, horizonteMin: 30, aviso: nil),
                    proyeccion(130, horizonteMin: 60, aviso: nil),
                ],
                modo: .sensor,
                umbralHipo: 70,
                ahora: ahora
            )

        #expect(resultado == .nadaQueAvisar)
    }

    @Test("Si las dos avisan, la que sale es la más cercana")
    func ganaLaMasCercana() async throws {
        let registro = RepositorioAlertasFalso()
        let avisos = AvisosFalsos(
            permiso: .concedido, respondeAlPedir: true, falloAlEntregar: nil
        )

        let resultado = try await AvisarDeLaProyeccion(alertas: registro, avisos: avisos)
            .ejecutar(
                proyecciones: [
                    proyeccion(66, horizonteMin: 30, aviso: .bajaPrevista),
                    proyeccion(55, horizonteMin: 60, aviso: .bajaPrevista),
                ],
                modo: .sensor,
                umbralHipo: 70,
                ahora: ahora
            )

        // La de 60 minutos es más baja, y da igual: la que deja menos tiempo para reaccionar
        // es la de 30.
        let alerta = try #require(resultado.alerta)
        #expect(alerta.horizonteMin == 30)
        #expect(alerta.valorMgDl == 66)
    }

    // MARK: - No repetirse

    @Test("El mismo descenso no vuelve a avisar un minuto después")
    func noSeRepiteCadaMinuto() async throws {
        let registro = RepositorioAlertasFalso()
        let avisos = AvisosFalsos(
            permiso: .concedido, respondeAlPedir: true, falloAlEntregar: nil
        )
        let caso = AvisarDeLaProyeccion(alertas: registro, avisos: avisos)

        _ = try await caso.ejecutar(
            proyecciones: [proyeccion(64, horizonteMin: 30, aviso: .bajaPrevista)],
            modo: .sensor, umbralHipo: 70, ahora: ahora
        )
        // La pantalla se recalcula cada minuto. Sin esta regla, el mismo descenso avisaría
        // sesenta veces por hora y la persona apagaría las notificaciones.
        let segundo = try await caso.ejecutar(
            proyecciones: [proyeccion(63, horizonteMin: 30, aviso: .bajaPrevista)],
            modo: .sensor, umbralHipo: 70, ahora: ahora.addingTimeInterval(60)
        )

        #expect(segundo.etiqueta == "yaSeAviso")
        let guardadas = await registro.guardadas
        let entregados = await avisos.entregados
        #expect(guardadas.count == 1)
        #expect(entregados.count == 1)
    }

    @Test("Pasada la espera, el mismo descenso vuelve a avisar")
    func pasadaLaEsperaVuelveAAvisar() async throws {
        let registro = RepositorioAlertasFalso()
        let avisos = AvisosFalsos(
            permiso: .concedido, respondeAlPedir: true, falloAlEntregar: nil
        )
        let caso = AvisarDeLaProyeccion(alertas: registro, avisos: avisos)

        _ = try await caso.ejecutar(
            proyecciones: [proyeccion(64, horizonteMin: 30, aviso: .bajaPrevista)],
            modo: .sensor, umbralHipo: 70, ahora: ahora
        )
        let despues = ahora.addingTimeInterval(ConfiguracionDominio.esperaEntreAvisosMin * 60)
        let segundo = try await caso.ejecutar(
            proyecciones: [proyeccion(64, horizonteMin: 30, aviso: .bajaPrevista)],
            modo: .sensor, umbralHipo: 70, ahora: despues
        )

        #expect(segundo.etiqueta == "avisado")
        let entregados = await avisos.entregados
        #expect(entregados.count == 2)
    }

    @Test("Si la estimación empeora de verdad, se vuelve a avisar sin esperar")
    func siEmpeoraAvisaAntes() async throws {
        let registro = RepositorioAlertasFalso()
        let avisos = AvisosFalsos(
            permiso: .concedido, respondeAlPedir: true, falloAlEntregar: nil
        )
        let caso = AvisarDeLaProyeccion(alertas: registro, avisos: avisos)

        _ = try await caso.ejecutar(
            proyecciones: [proyeccion(68, horizonteMin: 30, aviso: .bajaPrevista)],
            modo: .sensor, umbralHipo: 70, ahora: ahora
        )
        // De 68 a 50 son 18 mg/dL, más que el umbral de 15: es información nueva y vale
        // interrumpir otra vez, aunque hayan pasado dos minutos.
        let segundo = try await caso.ejecutar(
            proyecciones: [proyeccion(50, horizonteMin: 30, aviso: .bajaPrevista)],
            modo: .sensor, umbralHipo: 70, ahora: ahora.addingTimeInterval(120)
        )

        #expect(segundo.etiqueta == "avisado")
        let entregados = await avisos.entregados
        #expect(entregados.count == 2)
    }

    @Test("La regla de repetirse está escrita en un solo lugar y se puede leer sola")
    func laReglaDeRepetirse() {
        let anterior = AlertaDato(
            tsUtc: ahora, valorMgDl: 68, umbralMgDl: 70, horizonteMin: 30, modo: .sensor
        )
        let unMinuto = ahora.addingTimeInterval(60)

        #expect(
            AvisarDeLaProyeccion.vuelveAAvisar(
                anterior: anterior, valorMgDl: 66, ahora: unMinuto
            ) == false
        )
        #expect(
            AvisarDeLaProyeccion.vuelveAAvisar(
                anterior: anterior, valorMgDl: 53, ahora: unMinuto
            )
        )
        // Justo en el borde de la espera sí avisa: el borde se incluye, como en el resto del
        // dominio.
        let enElBorde = ahora.addingTimeInterval(ConfiguracionDominio.esperaEntreAvisosMin * 60)
        #expect(
            AvisarDeLaProyeccion.vuelveAAvisar(
                anterior: anterior, valorMgDl: 68, ahora: enElBorde
            )
        )
        // Una estimación que mejoró no vuelve a avisar.
        #expect(
            AvisarDeLaProyeccion.vuelveAAvisar(
                anterior: anterior, valorMgDl: 90, ahora: unMinuto
            ) == false
        )
    }

    // MARK: - El permiso

    @Test("Sin permiso la alerta se registra igual, y el resultado lo dice")
    func sinPermisoSeRegistraIgual() async throws {
        let registro = RepositorioAlertasFalso()
        let avisos = AvisosFalsos(
            permiso: .negado, respondeAlPedir: false, falloAlEntregar: nil
        )

        let resultado = try await AvisarDeLaProyeccion(alertas: registro, avisos: avisos)
            .ejecutar(
                proyecciones: [proyeccion(64, horizonteMin: 30, aviso: .bajaPrevista)],
                modo: .sensor, umbralHipo: 70, ahora: ahora
            )

        #expect(resultado.etiqueta == "registradaSinPermiso")
        // El registro se queda: es lo que permite medir después el tiempo de anticipación, y
        // lo que distingue «no se avisó» de «se avisó y no llegó».
        let guardadas = await registro.guardadas
        #expect(guardadas.count == 1)
        #expect(guardadas.first?.entregada == false)

        let entregados = await avisos.entregados
        #expect(entregados.isEmpty)
        // Negado no se vuelve a preguntar: iOS no enseñaría el diálogo otra vez.
        let veces = await avisos.vecesQueSePidioPermiso
        #expect(veces == 0)
    }

    @Test("El permiso se pide con la alerta en la mano, no al abrir la app")
    func elPermisoSePideConLaAlertaEnLaMano() async throws {
        let registro = RepositorioAlertasFalso()
        let avisos = AvisosFalsos(
            permiso: .sinPreguntar, respondeAlPedir: true, falloAlEntregar: nil
        )

        let resultado = try await AvisarDeLaProyeccion(alertas: registro, avisos: avisos)
            .ejecutar(
                proyecciones: [proyeccion(64, horizonteMin: 30, aviso: .bajaPrevista)],
                modo: .sensor, umbralHipo: 70, ahora: ahora
            )

        #expect(resultado.etiqueta == "avisado")
        let veces = await avisos.vecesQueSePidioPermiso
        let entregados = await avisos.entregados
        #expect(veces == 1)
        #expect(entregados.count == 1)
    }

    @Test("Si el sistema no acepta el aviso, la alerta no se pierde")
    func siElSistemaFallaLaAlertaNoSePierde() async throws {
        let registro = RepositorioAlertasFalso()
        let avisos = AvisosFalsos(
            permiso: .concedido, respondeAlPedir: true,
            falloAlEntregar: .elSistemaNoLoAcepto(detalle: "prueba")
        )

        let resultado = try await AvisarDeLaProyeccion(alertas: registro, avisos: avisos)
            .ejecutar(
                proyecciones: [proyeccion(64, horizonteMin: 30, aviso: .bajaPrevista)],
                modo: .sensor, umbralHipo: 70, ahora: ahora
            )

        #expect(resultado.etiqueta == "registradaSinPermiso")
        let guardadas = await registro.guardadas
        #expect(guardadas.count == 1)
        #expect(guardadas.first?.entregada == false)
    }

    // MARK: - Qué dice el aviso

    /// **Regla 7.** Es la frontera con un dispositivo médico regulado, y este texto es el
    /// único de la app que llega a la pantalla de bloqueo sin que nadie lo lea antes.
    @Test("Regla 7: el aviso dice qué va a pasar y no qué hacer")
    func elAvisoNoDaNingunaIndicacion() {
        let alerta = AlertaDato(
            tsUtc: ahora, valorMgDl: 63.6, umbralMgDl: 70, horizonteMin: 30, modo: .sensor
        )
        let objetivo = ahora.addingTimeInterval(30 * 60)
        let aviso = AvisarDeLaProyeccion.aviso(de: alerta, objetivo: objetivo)
        let texto = (aviso.titulo + " " + aviso.cuerpo).lowercased()

        // La cifra va redondeada y con su unidad, y la hora es la que apunta.
        #expect(aviso.cuerpo.contains("64 mg/dL"))
        #expect(aviso.cuerpo.contains(AvisarDeLaProyeccion.hora(objetivo)))
        #expect(aviso.cuerpo.contains("estimación"))

        // Nada de dosis, nada de gramos, nada de tomar, inyectarse ni corregir.
        let prohibidos = [
            "unidades", "dosis", "inyect", "aplíca", "gramo", "toma ", "come ",
            "corrige", "corregir", "ajusta", "trata", "medicamento", "insulina",
            "jugo", "azúcar", "glucagón", "carbohidrato",
        ]
        for prohibido in prohibidos {
            #expect(texto.contains(prohibido) == false)
        }

        // Medir no es tratarse, y es lo único que la app puede pedir.
        #expect(texto.contains("medirte"))
    }

    @Test("El aviso vibra, porque alguien dormido no lee una pantalla")
    func elAvisoVibra() {
        let alerta = AlertaDato(
            tsUtc: ahora, valorMgDl: 60, umbralMgDl: 70, horizonteMin: 30, modo: .sensor
        )
        let aviso = AvisarDeLaProyeccion.aviso(de: alerta, objetivo: ahora)
        #expect(aviso.vibra)
        // El color no es el único portador de la información: el aviso lleva palabra y cifra,
        // y la vibración llega a quien no ve la pantalla.
        #expect(aviso.titulo.isEmpty == false)
    }
}
