import Testing
@testable import Glucy

/// El dígito verificador, que se comprueba en el teléfono antes de salir a la red.
struct CodigoBarrasTests {

    /// Prueba 1 · RF-12.
    @Test("1 · RF-12: un EAN-13 real se acepta")
    func eanTreceRealSeAcepta() {
        #expect(CodigoBarras.esValido("3017620422003"))
        #expect(CodigoBarras.esValido("4006381333931"))
        // Un UPC-A llega del escáner como EAN-13 con un cero delante.
        #expect(CodigoBarras.esValido("0036000291452"))
    }

    /// Prueba 2 · RF-12 — la regla. Que además no se consulte está en
    /// `BuscarProductoPorCodigoTests`.
    @Test("2 · RF-12: el mismo con un dígito cambiado se rechaza")
    func unDigitoCambiadoSeRechaza() {
        #expect(!CodigoBarras.esValido("3017620422004"))   // el verificador
        #expect(!CodigoBarras.esValido("3017620522003"))   // uno de en medio
        #expect(!CodigoBarras.esValido("3071620422003"))   // dos vecinos intercambiados
    }

    /// Prueba 3 · RF-12.
    @Test("3 · RF-12: un EAN-8 válido se acepta")
    func eanOchoSeAcepta() {
        #expect(CodigoBarras.esValido("73513537"))
        #expect(!CodigoBarras.esValido("73513538"))
    }

    /// Prueba 4 · RF-12.
    @Test("4 · RF-12: un código con letras o con los dígitos mal contados se rechaza")
    func letrasOLongitudEquivocadaSeRechazan() {
        #expect(!CodigoBarras.esValido("30176204220O3"))    // una O por un cero
        #expect(!CodigoBarras.esValido("301762042200"))     // doce
        #expect(!CodigoBarras.esValido("30176204220033"))   // catorce
        #expect(!CodigoBarras.esValido(""))
        #expect(!CodigoBarras.esValido("3017620422003 "))
        // Dígitos de otro alfabeto no son un código de barras.
        #expect(!CodigoBarras.esValido("٣٠١٧٦٢٠٤٢٢٠٠٣"))
    }

    /// Un UPC-E mide ocho dígitos, como un EAN-8, pero su verificador es el del código
    /// expandido. Sin expandirlo se rechazaría siempre.
    @Test("RF-12: un UPC-E se expande a su EAN-13 y entonces sí cuadra")
    func upceSeExpande() {
        #expect(CodigoBarras.ean13(desdeUpce: "04252614") == "0042100005264")
        #expect(CodigoBarras.esValido("0042100005264"))
        #expect(CodigoBarras.ean13(desdeUpce: "0425261") == nil)
        #expect(CodigoBarras.ean13(desdeUpce: "0425261A") == nil)
    }
}
