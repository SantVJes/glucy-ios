import SwiftUI
import Testing
import UIKit
@testable import Glucy

/// Un color de letra o de borde contra el fondo sobre el que de verdad se dibuja.
struct ParMedido: Sendable, CustomTestStringConvertible {
    let nombre: String
    let frente: ParDeColores
    let fondo: ParDeColores

    var testDescription: String { nombre }
}

/// Los pares que se dibujan juntos. Son los de la tabla del apartado 4 de
/// `docs/modo-oscuro.md`: un color que se use sobre un fondo nuevo se agrega aquí, o entra
/// sin medirse.
enum ParesMedidos {
    private static let coloresDeTexto: [(String, ParDeColores)] = [
        ("textoPrincipal", Tema.Paleta.textoPrincipal),
        ("textoSecundario", Tema.Paleta.textoSecundario),
        ("azulPrimario", Tema.Paleta.azulPrimario),
        ("azulProfundo", Tema.Paleta.azulProfundo),
        ("enRango", Tema.Paleta.enRango),
        ("precaucion", Tema.Paleta.precaucion),
        ("hipoglucemia", Tema.Paleta.hipoglucemia),
    ]

    /// Los siete colores de texto sobre `superficie` y sobre `fondo`: catorce pares.
    static let texto: [ParMedido] = coloresDeTexto.flatMap { nombre, color in
        [
            ParMedido(nombre: "\(nombre) / superficie", frente: color, fondo: Tema.Paleta.superficie),
            ParMedido(nombre: "\(nombre) / fondo", frente: color, fondo: Tema.Paleta.fondo),
        ]
    }

    /// La letra de los botones y de la franja de «guardado».
    static let sobreColor: [ParMedido] = [
        ("azulPrimario", Tema.Paleta.azulPrimario),
        ("enRango", Tema.Paleta.enRango),
        ("hipoglucemia", Tema.Paleta.hipoglucemia),
        ("textoSecundario", Tema.Paleta.textoSecundario),
    ].map { nombre, relleno in
        ParMedido(
            nombre: "textoSobreColor / \(nombre)",
            frente: Tema.Paleta.textoSobreColor, fondo: relleno
        )
    }

    /// El chip elegido.
    static let sobreAzulClaro: [ParMedido] = [
        ParMedido(
            nombre: "azulPrimario / azulClaro",
            frente: Tema.Paleta.azulPrimario, fondo: Tema.Paleta.azulClaro
        ),
        ParMedido(
            nombre: "textoPrincipal / azulClaro",
            frente: Tema.Paleta.textoPrincipal, fondo: Tema.Paleta.azulClaro
        ),
    ]

    /// El borde y el icono de los avisos.
    static let bordes: [ParMedido] = [
        ParMedido(
            nombre: "alertaAmbar / superficie",
            frente: Tema.Paleta.alertaAmbar, fondo: Tema.Paleta.superficie
        ),
        ParMedido(
            nombre: "alertaAmbar / fondo",
            frente: Tema.Paleta.alertaAmbar, fondo: Tema.Paleta.fondo
        ),
    ]
}

/// El contraste de cada color contra el fondo donde se usa, en los dos modos.
///
/// Los mínimos son los de WCAG 2.2 y los del Documento 1: 4.5:1 en texto (1.4.3) y 3:1 en
/// bordes e iconos (1.4.11). La pantalla se lee de madrugada, con una hipoglucemia encima.
struct ContrasteTests {

    private static let minimoTexto = 4.5
    private static let minimoBorde = 3.0

    // MARK: - La fórmula

    @Test("1: negro sobre blanco da 21:1 y un color sobre sí mismo da 1:1")
    func losExtremosDeLaFormula() {
        #expect(abs(Contraste.razon(0x000000, 0xFFFFFF) - 21) < 0.001)
        #expect(Contraste.razon(0x1A56DB, 0x1A56DB) == 1)
    }

    @Test("2: el orden de los dos colores no importa")
    func elOrdenNoImporta() {
        #expect(Contraste.razon(0x1A56DB, 0xFFFFFF) == Contraste.razon(0xFFFFFF, 0x1A56DB))
        #expect(Contraste.razon(0x0B0F17, 0xFF6259) == Contraste.razon(0xFF6259, 0x0B0F17))
    }

    @Test("3: el azul primario sobre blanco da 6.18, el 6.2:1 del Documento 1")
    func elAzulPrimarioCoincideConElDocumento() {
        #expect(abs(Contraste.razon(0x1A56DB, 0xFFFFFF) - 6.18) <= 0.01)
    }

    // MARK: - Texto

    @Test("4: texto sobre superficie y sobre fondo, modo claro", arguments: ParesMedidos.texto)
    func textoEnClaro(_ par: ParMedido) {
        #expect(Contraste.razon(par.frente.claro, par.fondo.claro) >= Self.minimoTexto, "\(par.nombre)")
    }

    @Test("5: texto sobre superficie y sobre fondo, modo oscuro", arguments: ParesMedidos.texto)
    func textoEnOscuro(_ par: ParMedido) {
        #expect(Contraste.razon(par.frente.oscuro, par.fondo.oscuro) >= Self.minimoTexto, "\(par.nombre)")
    }

    @Test("6: la letra encima de un relleno de color, en los dos modos", arguments: ParesMedidos.sobreColor)
    func letraSobreColor(_ par: ParMedido) {
        #expect(Contraste.razon(par.frente.claro, par.fondo.claro) >= Self.minimoTexto, "\(par.nombre), claro")
        #expect(Contraste.razon(par.frente.oscuro, par.fondo.oscuro) >= Self.minimoTexto, "\(par.nombre), oscuro")
    }

    @Test("7: el chip elegido, en los dos modos", arguments: ParesMedidos.sobreAzulClaro)
    func chipElegido(_ par: ParMedido) {
        #expect(Contraste.razon(par.frente.claro, par.fondo.claro) >= Self.minimoTexto, "\(par.nombre), claro")
        #expect(Contraste.razon(par.frente.oscuro, par.fondo.oscuro) >= Self.minimoTexto, "\(par.nombre), oscuro")
    }

    // MARK: - Bordes y superficies

    @Test("8: el borde ámbar de los avisos, en los dos modos", arguments: ParesMedidos.bordes)
    func bordeDeAviso(_ par: ParMedido) {
        #expect(Contraste.razon(par.frente.claro, par.fondo.claro) >= Self.minimoBorde, "\(par.nombre), claro")
        #expect(Contraste.razon(par.frente.oscuro, par.fondo.oscuro) >= Self.minimoBorde, "\(par.nombre), oscuro")
    }

    /// Las tarjetas se separan del fondo por ser de otro tono, no por una sombra.
    @Test("9: la tarjeta se distingue del fondo en los dos modos")
    func laTarjetaSeSeparaDelFondo() {
        #expect(Contraste.razon(Tema.Paleta.superficie.claro, Tema.Paleta.fondo.claro) > 1.05)
        #expect(Contraste.razon(Tema.Paleta.superficie.oscuro, Tema.Paleta.fondo.oscuro) > 1.05)
    }

    // MARK: - El color dinámico

    /// Que la paleta tenga dos columnas no sirve de nada si el color que llega a la vista no
    /// cambia con el modo. Aquí se resuelve de verdad, como lo hace iOS al dibujar.
    @Test("10: el color dinámico cambia de verdad con el modo del sistema")
    @MainActor
    func elColorDinamicoSigueAlSistema() {
        let color = UIColor(Tema.Colores.hipoglucemia)

        let enOscuro = color.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark))
        let enClaro = color.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))

        #expect(Self.coincide(enOscuro, con: 0xFF6259))
        #expect(Self.coincide(enClaro, con: 0xCC2A1E))
    }

    /// SwiftUI no resuelve los colores en el hilo principal sino en el de dibujo. Si el
    /// cierre del color dinámico queda aislado al actor principal, la app se cae al dibujar
    /// la primera pantalla y ninguna prueba que corra en el principal lo ve.
    @Test("10: el color dinámico se puede resolver fuera del hilo principal")
    func elColorDinamicoSeResuelveFueraDelPrincipal() async {
        let color = await MainActor.run { UIColor(Tema.Colores.hipoglucemia) }

        let enOscuro = await Task.detached {
            color.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark))
        }.value

        #expect(Self.coincide(enOscuro, con: 0xFF6259))
    }

    /// Los doce pares, valor por valor, contra la tabla del apartado 3 de
    /// `docs/modo-oscuro.md`. Quien cambie un color tiene que cambiar el documento y esta
    /// prueba: no se mueve uno solo.
    @Test("11: la paleta es exactamente la de la tabla del documento")
    func laPaletaEsLaDelDocumento() {
        #expect(Tema.Paleta.azulPrimario == ParDeColores(claro: 0x1A56DB, oscuro: 0x7EA6FF))
        #expect(Tema.Paleta.azulClaro == ParDeColores(claro: 0xD1E2FF, oscuro: 0x1E3560))
        #expect(Tema.Paleta.azulProfundo == ParDeColores(claro: 0x0B2A6B, oscuro: 0xDCE6FF))
        #expect(Tema.Paleta.fondo == ParDeColores(claro: 0xF4F6FA, oscuro: 0x0B0F17))
        #expect(Tema.Paleta.superficie == ParDeColores(claro: 0xFFFFFF, oscuro: 0x171D28))
        #expect(Tema.Paleta.textoPrincipal == ParDeColores(claro: 0x111827, oscuro: 0xEEF1F6))
        #expect(Tema.Paleta.textoSecundario == ParDeColores(claro: 0x667085, oscuro: 0x9BA4B4))
        #expect(Tema.Paleta.enRango == ParDeColores(claro: 0x0B7A54, oscuro: 0x5EE0A0))
        #expect(Tema.Paleta.precaucion == ParDeColores(claro: 0xB54708, oscuro: 0xFDB022))
        #expect(Tema.Paleta.alertaAmbar == ParDeColores(claro: 0xDC6803, oscuro: 0xF79009))
        #expect(Tema.Paleta.hipoglucemia == ParDeColores(claro: 0xCC2A1E, oscuro: 0xFF6259))
        #expect(Tema.Paleta.textoSobreColor == ParDeColores(claro: 0xFFFFFF, oscuro: 0x0B0F17))
    }

    /// En claro el rojo y el verde tienen la misma luminosidad: en escala de grises son el
    /// mismo gris. En oscuro se separan, y el color ayuda en vez de estorbar.
    @Test("12: en oscuro el rojo de hipoglucemia se distingue por luminosidad")
    func elRojoSeSeparaPorLuminosidad() {
        let rojo = Tema.Paleta.hipoglucemia.oscuro
        #expect(Contraste.razon(rojo, Tema.Paleta.enRango.oscuro) >= 1.5)
        #expect(Contraste.razon(rojo, Tema.Paleta.precaucion.oscuro) >= 1.5)
    }

    // MARK: - Ayuda

    /// Con tolerancia de 1/255 por canal, que es lo que se pierde al pasar por `CGFloat`.
    private static func coincide(_ color: UIColor, con hex: UInt32) -> Bool {
        var (rojo, verde, azul, alfa): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        guard color.getRed(&rojo, green: &verde, blue: &azul, alpha: &alfa) else { return false }
        let esperado = [(hex >> 16) & 0xFF, (hex >> 8) & 0xFF, hex & 0xFF].map { CGFloat($0) / 255 }
        return zip([rojo, verde, azul], esperado).allSatisfy { abs($0 - $1) <= 1.0 / 255 }
    }
}
