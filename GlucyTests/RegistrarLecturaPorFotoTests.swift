import CoreGraphics
import Foundation
import Testing
@testable import Glucy

/// El registro por foto. Aquí se comprueba lo que no se negocia: **nada se guarda sin que
/// la persona confirme el valor**, con la confianza que sea (D-11, RF-02, caso P-01).
struct RegistrarLecturaPorFotoTests {

    private let ahora = Date(timeIntervalSince1970: 1_758_240_000)

    private func caso() -> (RegistrarLecturaPorFoto, RepositorioLecturasFalso) {
        let repositorio = RepositorioLecturasFalso()
        return (RegistrarLecturaPorFoto(repositorio: repositorio), repositorio)
    }

    /// Prueba 1 · **P-01**, D-11 — la garantía no es un `if`: es que **no existe otro
    /// camino**. `ejecutar` solo acepta `valorConfirmado`, así que no hay forma de pedirle
    /// que guarde lo que el OCR leyó sin que alguien lo apruebe.
    @Test("1 · P-01: leer con el OCR no guarda nada; solo guarda la confirmación")
    func leerNoGuarda() async throws {
        let ocr = OCRFalso(respuesta: [
            NumeroLeido(valor: 112, confianza: 0.97,
                        caja: CGRect(x: 0.1, y: 0.4, width: 0.3, height: 0.2))
        ])
        let (caso, repositorio) = caso()

        // Todo el camino del OCR, de principio a fin, sin pasar por la confirmación.
        let numeros = try await ocr.numerosEn(imagen: Data([0x00]))
        let elegido = SeleccionDeNumero.glucosa(entre: numeros)

        #expect(elegido?.valor == 112)
        // El repositorio no se tocó: leer no es guardar.
        #expect(await repositorio.guardadas.isEmpty)

        // Solo después de confirmar aparece la fila.
        _ = try await caso.ejecutar(
            valorConfirmado: 112, valorLeidoOcr: 112, confianzaOcr: 0.97,
            tsUtc: ahora, contexto: nil, ahora: ahora
        )
        #expect(await repositorio.guardadas.count == 1)
    }

    /// Prueba 2 · RF-02 — «sin importar la confianza» quiere decir que no hay atajo: con
    /// 0.99 el camino es exactamente el mismo.
    @Test("2 · RF-02: con 0.99 de confianza tampoco se guarda solo")
    func conMuchaConfianzaTampocoSeGuardaSolo() async throws {
        let ocr = OCRFalso(respuesta: [
            NumeroLeido(valor: 112, confianza: 0.99,
                        caja: CGRect(x: 0.1, y: 0.4, width: 0.3, height: 0.2))
        ])
        let (_, repositorio) = caso()

        _ = try await ocr.numerosEn(imagen: Data([0x00]))
        #expect(await repositorio.guardadas.isEmpty)

        // Y la confianza que se guarda es esa, pero no cambió nada del flujo.
        let (casoDeUso, repositorioDos) = caso()
        let guardada = try await casoDeUso.ejecutar(
            valorConfirmado: 112, valorLeidoOcr: 112, confianzaOcr: 0.99,
            tsUtc: ahora, contexto: nil, ahora: ahora
        )
        #expect(guardada.confianzaOcr == 0.99)
        #expect(await repositorioDos.guardadas.count == 1)
    }

    /// Prueba 3 · RF-05b — los tres campos nuevos quedan guardados.
    @Test("3 · RF-05b: se guarda valorLeidoOcr, confianzaOcr y fueCorregido")
    func seGuardanLosTresCampos() async throws {
        let (caso, repositorio) = caso()

        let guardada = try await caso.ejecutar(
            valorConfirmado: 121, valorLeidoOcr: 112, confianzaOcr: 0.83,
            tsUtc: ahora, contexto: .antesDeComer, ahora: ahora
        )

        #expect(guardada.mgDl == 121)            // el dato clínico es el confirmado
        #expect(guardada.valorLeidoOcr == 112)
        #expect(guardada.confianzaOcr == 0.83)
        #expect(guardada.fueCorregido)

        let enElRepositorio = try #require(await repositorio.guardadas.first)
        #expect(enElRepositorio.valorLeidoOcr == 112)
        #expect(enElRepositorio.confianzaOcr == 0.83)
        #expect(enElRepositorio.fueCorregido)
    }

    /// Prueba 4 · RF-05b — confirmar sin cambiar no es corregir.
    @Test("4 · RF-05b: confirmar sin cambiar deja fueCorregido en false")
    func confirmarSinCambiarNoEsCorregir() async throws {
        let (caso, _) = caso()

        let guardada = try await caso.ejecutar(
            valorConfirmado: 112, valorLeidoOcr: 112, confianzaOcr: 0.9,
            tsUtc: ahora, contexto: nil, ahora: ahora
        )

        #expect(guardada.fueCorregido == false)
        #expect(guardada.mgDl == 112)

        // Y escribir el número desde cero, cuando el OCR no leyó nada, tampoco es una
        // corrección: no había nada que corregir (RF-03).
        let escritoDesdeCero = try await caso.ejecutar(
            valorConfirmado: 98, valorLeidoOcr: nil, confianzaOcr: nil,
            tsUtc: ahora, contexto: nil, ahora: ahora
        )
        #expect(escritoDesdeCero.fueCorregido == false)
        #expect(escritoDesdeCero.valorLeidoOcr == nil)
    }

    /// Prueba 5 · RF-05b — el caso que importa para evaluar después si la confianza
    /// predice los errores.
    @Test("5 · RF-05b: corregir 112 a 121 deja fueCorregido en true y mgDl en 121")
    func corregirQuedaRegistrado() async throws {
        let (caso, _) = caso()

        let guardada = try await caso.ejecutar(
            valorConfirmado: 121, valorLeidoOcr: 112, confianzaOcr: 0.5,
            tsUtc: ahora, contexto: nil, ahora: ahora
        )

        #expect(guardada.mgDl == 121)
        #expect(guardada.valorLeidoOcr == 112)
        #expect(guardada.fueCorregido)
    }

    /// Prueba 6 · RF-04 — el origen lo pone el caso de uso, no quien lo llama.
    @Test("6 · RF-04: lo guardado lleva origen fotoGlucometro")
    func siempreOrigenFoto() async throws {
        let (caso, repositorio) = caso()

        let guardada = try await caso.ejecutar(
            valorConfirmado: 112, valorLeidoOcr: 112, confianzaOcr: 0.9,
            tsUtc: ahora, contexto: nil, ahora: ahora
        )

        #expect(guardada.origen == .fotoGlucometro)
        #expect(guardada.confirmadaPorUsuario)
        #expect(await repositorio.guardadas.allSatisfy { $0.origen == .fotoGlucometro })
    }

    /// Prueba 7 · RF-05 — la validación del paso 3 no se salta por venir de una foto. Un
    /// 900 leído por el OCR y confirmado por error tampoco se guarda.
    @Test("7 · RF-05: un 900 confirmado por error no se guarda")
    func novecientosConfirmadoTampocoSeGuarda() async throws {
        let (caso, repositorio) = caso()

        await #expect(throws: FalloRegistro.fueraDeRango) {
            try await caso.ejecutar(
                valorConfirmado: 900, valorLeidoOcr: 900, confianzaOcr: 0.99,
                tsUtc: ahora, contexto: nil, ahora: ahora
            )
        }

        #expect(await repositorio.guardadas.isEmpty)

        // Y una hora futura, igual que en la captura manual.
        await #expect(throws: FalloRegistro.horaFutura) {
            try await caso.ejecutar(
                valorConfirmado: 112, valorLeidoOcr: 112, confianzaOcr: 0.9,
                tsUtc: ahora.addingTimeInterval(60), contexto: nil, ahora: ahora
            )
        }
        #expect(await repositorio.guardadas.isEmpty)
    }

    /// Prueba 15 · RF-15 — una lectura por foto se escribe en Salud. El paso 4 ya lo
    /// contempla: `.fotoGlucometro` está en la lista de orígenes que se escriben.
    @Test("15 · RF-15: una lectura por foto se escribe en Salud")
    func laLecturaPorFotoSeEscribeEnSalud() async throws {
        let repositorio = RepositorioLecturasFalso()
        let salud = HealthKitFalso(disponible: true)

        let caso = RegistrarLecturaPorFoto(
            repositorio: repositorio,
            salud: EscribirEnHealthKit(servicio: salud, lecturas: repositorio)
        )

        let guardada = try await caso.ejecutar(
            valorConfirmado: 112, valorLeidoOcr: 112, confianzaOcr: 0.9,
            tsUtc: ahora, contexto: nil, ahora: ahora
        )

        let escritas = await salud.escritas
        #expect(escritas.count == 1)
        #expect(escritas.first?.uuid == guardada.uuid)
        #expect(escritas.first?.origen == .fotoGlucometro)
    }
}
