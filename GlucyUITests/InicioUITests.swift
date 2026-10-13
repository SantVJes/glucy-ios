import XCTest

/// La pantalla de inicio en modo sin sensor, que es como arranca la app sin Salud.
final class InicioUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    /// P-04, RF-10b: el aviso está y no hay gesto que lo quite. Es la única manera de probar
    /// «no descartable»: que no exista con qué descartarlo.
    func testElAvisoSinSensorNoSePuedeCerrar() {
        let app = XCUIApplication.yaDentro()

        let aviso = app.descendants(matching: .any)["avisoSinSensor"]
        XCTAssertTrue(aviso.waitForExistence(timeout: 10), "No apareció el aviso del modo sin sensor")
        XCTAssertTrue(aviso.label.contains("Sin sensor no puedo anticipar hipoglucemias."))
        XCTAssertTrue(aviso.label.contains("Si te sientes mal, mídete."))

        // No es un botón ni lleva uno dentro: no hay «entendido» ni equis.
        XCTAssertEqual(aviso.buttons.count, 0)
        aviso.tap()
        XCTAssertTrue(aviso.exists, "El aviso se cerró al tocarlo")

        aviso.swipeLeft()
        XCTAssertTrue(aviso.exists, "El aviso se cerró al deslizarlo")

        app.swipeUp()
        app.swipeDown()
        XCTAssertTrue(aviso.waitForExistence(timeout: 5), "El aviso se fue al desplazar la pantalla")

        // Y sigue ahí al salir de la pestaña y volver.
        app.tabBars.buttons["Historial"].tap()
        app.tabBars.buttons["Inicio"].tap()
        XCTAssertTrue(aviso.waitForExistence(timeout: 5), "El aviso no volvió con la pestaña")
    }

    /// Las cuatro pestañas tienen ya su pantalla.
    func testLasPestanasYaTienenPantalla() {
        let app = XCUIApplication.yaDentro()

        XCTAssertTrue(
            app.descendants(matching: .any)["avisoSinSensor"].waitForExistence(timeout: 10),
            "Inicio no enseña su pantalla"
        )

        app.tabBars.buttons["Historial"].tap()
        XCTAssertTrue(app.buttons["periodo7"].waitForExistence(timeout: 5), "Historial no enseña sus periodos")
        XCTAssertTrue(app.buttons["periodo14"].exists)
        XCTAssertTrue(app.buttons["periodo30"].exists)

        app.tabBars.buttons["Ajustes"].tap()
        XCTAssertTrue(
            app.staticTexts["glucyNoCalculaDosis"].waitForExistence(timeout: 5),
            "Ajustes no enseña su pantalla"
        )
    }
}
