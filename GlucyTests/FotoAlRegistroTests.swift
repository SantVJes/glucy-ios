import CoreGraphics
import Foundation
import Testing
@testable import Glucy

/// Lo que pasa entre la foto y el guardado, ahora que confirmar el número **no** guarda.
///
/// El valor leído se lleva a la pantalla de registro para poder ponerle hora y contexto, y
/// se guarda desde ahí. Lo que hay que proteger es que siga siendo una lectura **de foto**:
/// el origen es de dónde salió el dato, no dónde se tocó el botón.
@MainActor
struct FotoAlRegistroTests {

    /// Levanta la pantalla con un OCR que va a «leer» ese número, y recorre el camino de
    /// verdad: procesar la imagen deja la propuesta puesta, igual que con la cámara.
    private func pantallaQueLee(
        _ numeros: [NumeroLeido]
    ) async -> (RegistroGlucosaViewModel, RepositorioLecturasFalso) {
        let repositorio = RepositorioLecturasFalso()
        let modelo = RegistroGlucosaViewModel(
            registrar: RegistrarLecturaManual(repositorio: repositorio),
            registrarPorFoto: RegistrarLecturaPorFoto(repositorio: repositorio),
            ocr: OCRFalso(respuesta: numeros)
        )
        await modelo.procesar(imagen: Data([0x00]))
        return (modelo, repositorio)
    }

    private func leido(_ valor: Double, confianza: Double = 0.91) -> NumeroLeido {
        NumeroLeido(
            valor: valor,
            confianza: confianza,
            caja: CGRect(x: 0.1, y: 0.4, width: 0.3, height: 0.25)
        )
    }

    /// P-01 · D-11 — confirmar el número leído **no** guarda: lo deja en el campo. Sin un
    /// segundo gesto explícito, el repositorio sigue vacío.
    @Test("P-01: confirmar el valor leído no guarda nada; lo lleva al campo")
    func confirmarNoGuarda() async throws {
        let (modelo, repositorio) = await pantallaQueLee([leido(112)])

        // El OCR leyó y la hoja está esperando confirmación: todavía no hay nada guardado.
        #expect(modelo.estadoFoto == .leido(leido(112)))
        #expect(await repositorio.guardadas.isEmpty)

        modelo.llevarAlRegistro(valor: modelo.textoCorreccion)

        #expect(modelo.textoValor == "112")
        #expect(modelo.estadoFoto == .ninguno)
        #expect(await repositorio.guardadas.isEmpty, "confirmar no debe guardar")
        #expect(modelo.ultimaGuardada == nil)
    }

    /// RF-04 y RF-05b — al guardar desde la pantalla de registro, la lectura sigue siendo
    /// de foto y conserva los tres campos. Si esto se rompiera, una lectura del OCR quedaría
    /// registrada como tecleada a mano y nadie podría evaluar después si el OCR se equivoca.
    @Test("RF-04 y RF-05b: lo que vino de la foto se guarda como foto, con sus tres campos")
    func loDeLaFotoSeGuardaComoFoto() async throws {
        let (modelo, repositorio) = await pantallaQueLee([leido(112, confianza: 0.91)])

        modelo.llevarAlRegistro(valor: modelo.textoCorreccion)
        // La persona le pone contexto, que es justo para lo que sirve este rodeo.
        modelo.contexto = .enAyunas
        await modelo.guardar()

        let guardada = try #require(await repositorio.guardadas.first)
        #expect(guardada.origen == .fotoGlucometro)
        #expect(guardada.mgDl == 112)
        #expect(guardada.valorLeidoOcr == 112)
        #expect(guardada.confianzaOcr == 0.91)
        #expect(guardada.fueCorregido == false)
        #expect(guardada.contexto == .enAyunas)
    }

    /// RF-05b — corregir el número **en la pantalla de registro**, no en la hoja, también
    /// cuenta como corrección.
    @Test("RF-05b: si se cambia el número ya en el campo, queda como corregido")
    func cambiarloEnElCampoCuentaComoCorreccion() async throws {
        let (modelo, repositorio) = await pantallaQueLee([leido(112)])

        modelo.llevarAlRegistro(valor: modelo.textoCorreccion)
        modelo.textoValor = "121"          // lo corrige aquí, no en la hoja
        await modelo.guardar()

        let guardada = try #require(await repositorio.guardadas.first)
        #expect(guardada.mgDl == 121)
        #expect(guardada.valorLeidoOcr == 112)
        #expect(guardada.fueCorregido)
        #expect(guardada.origen == .fotoGlucometro)
    }

    /// Quitar la lectura de la foto la desliga: lo que se escriba después es manual.
    @Test("RF-04: al quitar lo de la foto, lo siguiente se guarda como manual")
    func alQuitarLaFotoVuelveAManual() async throws {
        let (modelo, repositorio) = await pantallaQueLee([leido(112)])
        modelo.llevarAlRegistro(valor: modelo.textoCorreccion)

        modelo.descartarLoDeLaFoto()
        #expect(modelo.textoValor.isEmpty)
        #expect(modelo.propuestaOcr == nil)

        modelo.textoValor = "98"
        await modelo.guardar()

        let guardada = try #require(await repositorio.guardadas.first)
        #expect(guardada.origen == .manual)
        #expect(guardada.valorLeidoOcr == nil)
        #expect(guardada.fueCorregido == false)
    }

    /// Y después de guardar, la propuesta se olvida: la siguiente lectura no hereda la
    /// confianza de la anterior.
    @Test("RF-05b: la propuesta no sobrevive al guardado")
    func laPropuestaNoSeHereda() async throws {
        let (modelo, repositorio) = await pantallaQueLee([leido(112)])
        modelo.llevarAlRegistro(valor: modelo.textoCorreccion)
        await modelo.guardar()

        #expect(modelo.propuestaOcr == nil)

        modelo.textoValor = "140"
        await modelo.guardar()

        let segunda = try #require(await repositorio.guardadas.last)
        #expect(segunda.mgDl == 140)
        #expect(segunda.origen == .manual)
        #expect(segunda.confianzaOcr == nil)
    }
}
