import CoreGraphics
import Foundation
import Testing
@testable import Glucy

/// Cuál de los números de la etiqueta son los carbohidratos. Sin imágenes y sin Vision, que
/// es para lo que la regla vive aparte; al final, dos etiquetas pasadas por Vision de verdad.
struct SeleccionDeCarbohidratosTests {

    /// Un renglón en la fila `fila` (0 es la de arriba) que empieza en `x`.
    private func renglon(
        _ texto: String, fila: Int, x: Double = 0.05, ancho: Double = 0.6, confianza: Double = 0.5
    ) -> TextoLeido {
        TextoLeido(
            texto: texto,
            confianza: confianza,
            caja: CGRect(x: x, y: 0.9 - Double(fila) * 0.1, width: ancho, height: 0.06)
        )
    }

    /// Prueba 11 · RF-13.
    @Test("11 · RF-13: «Hidratos de carbono 75 g» en la etiqueta da 75")
    func hidratosDeCarbono() {
        let etiqueta = [
            renglon("Información nutrimental", fila: 0),
            renglon("Por 100 g", fila: 1),
            renglon("Proteínas 6 g", fila: 2),
            renglon("Hidratos de carbono 75 g", fila: 3),
            renglon("Sodio 320 mg", fila: 4)
        ]
        #expect(SeleccionDeCarbohidratos.gramos(entre: etiqueta) == 75)

        // Las importadas lo dicen de otras formas, con mayúsculas y con coma decimal.
        #expect(SeleccionDeCarbohidratos.gramos(entre: [renglon("CARBOHIDRATOS TOTALES 12,5 g", fila: 0)]) == 12.5)
        #expect(SeleccionDeCarbohidratos.gramos(entre: [renglon("Total Carbohydrate 31g", fila: 0)]) == 31)
        #expect(SeleccionDeCarbohidratos.gramos(entre: [renglon("Glúcidos 48 g", fila: 0)]) == 48)

        // El número de antes de la palabra es el tamaño de referencia, no los carbohidratos.
        #expect(SeleccionDeCarbohidratos.gramos(entre: [renglon("100 g Hidratos de carbono 75 g", fila: 0)]) == 75)
    }

    /// Prueba 12 · RF-13 — confundirlos subestima los carbohidratos, que es el error que
    /// más daño hace.
    @Test("12 · RF-13: un renglón de «Azúcares 30 g» no se toma por los carbohidratos")
    func losAzucaresNoSonLosCarbohidratos() {
        let soloAzucares = [
            renglon("Azúcares 30 g", fila: 0),
            renglon("Fibra dietética 2 g", fila: 1)
        ]
        #expect(SeleccionDeCarbohidratos.gramos(entre: soloAzucares) == nil)

        // Aunque el renglón nombre también los carbohidratos.
        #expect(SeleccionDeCarbohidratos.gramos(entre: [
            renglon("Carbohidratos de los cuales azúcares 30 g", fila: 0)
        ]) == nil)

        // Y con los dos, gana el total, venga en el orden que venga.
        let azucares = renglon("Azúcares 30 g", fila: 4)
        let hidratos = renglon("Hidratos de carbono 75 g", fila: 3)
        #expect(SeleccionDeCarbohidratos.gramos(entre: [azucares, hidratos]) == 75)
        #expect(SeleccionDeCarbohidratos.gramos(entre: [hidratos, azucares]) == 75)
    }

    /// Prueba 13 · RF-13 — el nombre a la izquierda y la cifra a la derecha, en
    /// observaciones distintas.
    @Test("13 · RF-13: en una tabla en columnas, el número a la derecha del renglón se asocia bien")
    func tablaEnColumnas() {
        let tabla = [
            renglon("Proteínas", fila: 2, ancho: 0.3), renglon("6 g", fila: 2, x: 0.75, ancho: 0.1),
            renglon("Hidratos de carbono", fila: 3, ancho: 0.4), renglon("75 g", fila: 3, x: 0.75, ancho: 0.1),
            renglon("Azúcares", fila: 4, ancho: 0.3), renglon("30 g", fila: 4, x: 0.75, ancho: 0.1)
        ]
        #expect(SeleccionDeCarbohidratos.gramos(entre: tabla) == 75)
        #expect(SeleccionDeCarbohidratos.gramos(entre: tabla.reversed()) == 75)

        // Con dos columnas de cifras gana la más cercana al nombre.
        let dosColumnas = [
            renglon("Carbohidratos", fila: 3, ancho: 0.3),
            renglon("22 g", fila: 3, x: 0.8, ancho: 0.1),
            renglon("62 g", fila: 3, x: 0.6, ancho: 0.1)
        ]
        #expect(SeleccionDeCarbohidratos.gramos(entre: dosColumnas) == 62)
    }

    /// Prueba 14 · RF-13 — y `nil` es la captura manual.
    @Test("14 · RF-13: una etiqueta sin la palabra devuelve nil")
    func sinLaPalabraDevuelveNil() {
        #expect(SeleccionDeCarbohidratos.gramos(entre: []) == nil)
        #expect(SeleccionDeCarbohidratos.gramos(entre: [
            renglon("Ingredientes: harina de trigo, azúcar", fila: 0),
            renglon("Contenido neto 180 g", fila: 1)
        ]) == nil)
        // La palabra sin ninguna cifra tampoco alcanza.
        #expect(SeleccionDeCarbohidratos.gramos(entre: [renglon("Hidratos de carbono", fila: 0)]) == nil)
    }

    /// D-11 — la confianza se reporta y no decide nada.
    @Test("D-11: la selección de carbohidratos no usa la confianza")
    func laConfianzaNoDecide() {
        let dudoso = renglon("Hidratos de carbono 75 g", fila: 3, confianza: 0.05)
        let seguro = renglon("Azúcares 30 g", fila: 4, confianza: 0.99)
        #expect(SeleccionDeCarbohidratos.gramos(entre: [seguro, dudoso]) == 75)
    }

    // MARK: - Con Vision de verdad

    private final class AnclaDelPaquete {}

    private func imagen(_ nombre: String) throws -> Data {
        let url = try #require(
            Bundle(for: AnclaDelPaquete.self).url(forResource: nombre, withExtension: "png"),
            "No se encontró \(nombre).png en los recursos de prueba"
        )
        return try Data(contentsOf: url)
    }

    @Test("11 · RF-13: Vision lee la etiqueta mexicana y la regla da 75, no los 30 de azúcares")
    func visionLeeLaEtiquetaMexicana() async throws {
        let renglones = try await VisionOCR().textosEn(imagen: try imagen("etiqueta-mexicana"))
        #expect(!renglones.isEmpty, "Vision no leyó nada en la imagen")
        #expect(SeleccionDeCarbohidratos.gramos(entre: renglones) == 75)
    }

    @Test("13 · RF-13: Vision lee la etiqueta en columnas y la regla da 62, no los 21 de azúcares")
    func visionLeeLaEtiquetaEnColumnas() async throws {
        let renglones = try await VisionOCR().textosEn(imagen: try imagen("etiqueta-en-columnas"))
        #expect(SeleccionDeCarbohidratos.gramos(entre: renglones) == 62)
    }

    @Test("14 · RF-13: una imagen sin tabla nutrimental no da ningún número")
    func visionSinEtiqueta() async throws {
        let renglones = try await VisionOCR().textosEn(imagen: try imagen("glucometro-112"))
        #expect(SeleccionDeCarbohidratos.gramos(entre: renglones) == nil)
    }
}
