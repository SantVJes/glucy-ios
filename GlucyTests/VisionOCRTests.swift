import Foundation
import Testing
@testable import Glucy

/// Vision de verdad, sobre las imágenes de `Recursos/`.
///
/// La cámara no existe en el simulador, pero **Vision sí corre ahí sobre una imagen ya
/// cargada**, así que el OCR se puede probar en la integración continua y no solo con un
/// doble. Las imágenes son pantallas con números, no datos de nadie, y por eso sí se suben
/// al repositorio.
struct VisionOCRTests {

    /// Swift Testing usa structs, y `Bundle(for:)` pide una clase. Esta solo existe para
    /// dar con el paquete de pruebas.
    private final class AnclaDelPaquete {}

    private func imagen(_ nombre: String) throws -> Data {
        let paquete = Bundle(for: AnclaDelPaquete.self)
        let url = try #require(
            paquete.url(forResource: nombre, withExtension: "png"),
            "No se encontró \(nombre).png en los recursos de prueba"
        )
        return try Data(contentsOf: url)
    }

    /// Prueba 13 — que el OCR de verdad funcione, y que la regla se quede con la glucosa y
    /// no con la fecha ni con la hora que hay en la misma imagen.
    @Test("13: Vision lee el número de la pantalla y la regla elige la glucosa")
    func visionLeeElNumero() async throws {
        let ocr = VisionOCR()

        let numeros = try await ocr.numerosEn(imagen: try imagen("glucometro-112"))
        #expect(!numeros.isEmpty, "Vision no leyó nada en la imagen")

        let glucosa = try #require(SeleccionDeNumero.glucosa(entre: numeros))
        #expect(glucosa.valor == 112)

        // La confianza se reporta y se guarda, pero no decidió nada de lo anterior.
        #expect(glucosa.confianza > 0)
        #expect(glucosa.confianza <= 1)
    }

    @Test("13: y lo mismo con otra pantalla, para que no sea una casualidad")
    func visionLeeOtraPantalla() async throws {
        let numeros = try await VisionOCR().numerosEn(imagen: try imagen("glucometro-85"))
        #expect(SeleccionDeNumero.glucosa(entre: numeros)?.valor == 85)
    }

    /// Prueba 11 · RF-03, de punta a punta: una imagen sin ningún número deja a la persona
    /// escribiéndolo, no ante una pantalla de error.
    @Test("13 · RF-03: una imagen sin números no produce ningún candidato")
    func sinNumerosNoHayCandidato() async throws {
        let numeros = try await VisionOCR().numerosEn(imagen: try imagen("sin-numero"))
        #expect(SeleccionDeNumero.glucosa(entre: numeros) == nil)
    }

    /// Lo que no es una imagen se dice, no se traga en silencio.
    @Test("Una imagen ilegible lanza, no devuelve una lista vacía")
    func imagenIlegible() async throws {
        await #expect(throws: ErrorOCR.imagenIlegible) {
            try await VisionOCR().numerosEn(imagen: Data([0x01, 0x02, 0x03]))
        }
    }
}
