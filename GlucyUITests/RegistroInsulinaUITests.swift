import XCTest

/// El recorrido de anotar una dosis: el aviso de la frontera está antes que nada, la dosis se
/// guarda con dos toques y «Deshacer» la quita.
final class RegistroInsulinaUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    private func abrirInsulina() -> XCUIApplication {
        let app = XCUIApplication.yaDentro()

        let registrar = app.tabBars.buttons["Registrar"]
        XCTAssertTrue(registrar.waitForExistence(timeout: 10), "No apareció la pestaña Registrar")
        registrar.tap()

        let insulina = app.buttons["segmentoInsulina"]
        XCTAssertTrue(insulina.waitForExistence(timeout: 5), "El selector no ofrece Insulina")
        insulina.tap()
        return app
    }

    /// Regla 7: el aviso está en la pantalla, a la vista sin desplazar, y no hay con qué
    /// cerrarlo.
    func testElAvisoDeLaFronteraEstaALaVistaYNoSeCierra() {
        let app = abrirInsulina()

        let aviso = app.descendants(matching: .any)["avisoDeLaFrontera"]
        XCTAssertTrue(aviso.waitForExistence(timeout: 5), "No apareció el aviso de la frontera")
        XCTAssertTrue(aviso.isHittable, "El aviso no se ve sin desplazar")
        XCTAssertTrue(aviso.label.contains("Glucy solo anota lo que tú te aplicaste."))
        XCTAssertTrue(aviso.label.contains("No calcula ni sugiere dosis."))

        // Está por encima del campo de unidades.
        let campo = app.textFields["campoUnidades"]
        XCTAssertTrue(campo.exists, "No apareció el campo de unidades")
        XCTAssertLessThan(aviso.frame.maxY, campo.frame.minY + 1)

        // No es un botón ni lleva uno dentro: no hay «entendido» ni equis.
        XCTAssertEqual(aviso.buttons.count, 0)
        aviso.tap()
        XCTAssertTrue(aviso.exists, "El aviso se cerró al tocarlo")
    }

    func testAnotarUnaDosisYDeshacerla() {
        let app = abrirInsulina()

        let mas = app.buttons["botonMasMediaUnidad"]
        XCTAssertTrue(mas.waitForExistence(timeout: 5), "No apareció el botón de media unidad más")
        for _ in 0..<4 { mas.tap() }
        XCTAssertEqual(app.textFields["campoUnidades"].value as? String, "2")

        // La base puede traer dosis de antes (en el teléfono son las de verdad), así que se
        // compara contra lo que había y no contra una cifra fija.
        let antes = unidadesActivas(en: app)

        app.buttons["tipoRapida"].tap()
        app.buttons["botonGuardarDosis"].tap()

        let deshacer = app.buttons["botonDeshacerDosis"]
        if !deshacer.waitForExistence(timeout: 5) {
            // Lo que sí hay en pantalla, para saber si la dosis no se guardó o si se guardó
            // y lo que falta es el botón.
            let rechazo = app.staticTexts.matching(identifier: "falloDeInsulina").firstMatch
            XCTFail("""
                No apareció «Deshacer». \
                Franja a la vista: \(app.staticTexts["Dosis guardada"].exists). \
                Rechazo: \(rechazo.exists ? rechazo.label : "ninguno"). \
                Campo: \(app.textFields["campoUnidades"].value as? String ?? "vacío"). \
                Guardar habilitado: \(app.buttons["botonGuardarDosis"].isEnabled).
                """)
        }
        // La cifra se recalcula un instante después de que aparece la franja. Se espera
        // poco: la franja se va sola a los cinco segundos y hay que alcanzar a deshacer.
        var despues = unidadesActivas(en: app)
        let limite = Date().addingTimeInterval(2)
        while despues == antes, Date() < limite { despues = unidadesActivas(en: app) }

        // Se deshace antes de comprobar nada más: si la prueba falla, la dosis de prueba no
        // se queda en la base ni en Salud.
        deshacer.tap()
        XCTAssertTrue(deshacer.waitForNonExistence(timeout: 5), "La franja no se fue al deshacer")

        XCTAssertEqual(
            despues - antes, 2, accuracy: 0.15,
            "La dosis recién guardada no movió la insulina activa (antes \(antes), después \(despues))"
        )
        var alFinal = unidadesActivas(en: app)
        let limiteFinal = Date().addingTimeInterval(3)
        while abs(alFinal - antes) > 0.15, Date() < limiteFinal { alFinal = unidadesActivas(en: app) }
        XCTAssertEqual(
            alFinal, antes, accuracy: 0.15,
            "Deshacer no devolvió la insulina activa a lo que había"
        )
    }

    /// La cifra de la tarjeta de insulina activa. Cero si dice que no queda o si no está.
    private func unidadesActivas(en app: XCUIApplication) -> Double {
        let tarjeta = app.descendants(matching: .any)["insulinaActiva"]
        guard tarjeta.exists, tarjeta.label.hasPrefix("Te quedan ") else { return 0 }
        return Double(tarjeta.label.dropFirst("Te quedan ".count).prefix { $0 != " " }) ?? 0
    }
}
