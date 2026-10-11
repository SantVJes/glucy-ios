import XCTest

/// Ir y volver entre Glucosa y Comida no borra lo que la persona ya escribió.
final class RegistrarUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    func testCambiarDeRegistroNoBorraLoEscrito() {
        let app = XCUIApplication()
        app.launch()

        let registrar = app.tabBars.buttons["Registrar"]
        XCTAssertTrue(registrar.waitForExistence(timeout: 10), "No apareció la pestaña Registrar")
        registrar.tap()

        let campo = app.textFields["Valor de glucosa en miligramos por decilitro"]
        XCTAssertTrue(campo.waitForExistence(timeout: 5), "No apareció el campo del valor")
        campo.tap()
        campo.typeText("112")

        app.buttons["segmentoComida"].tap()
        XCTAssertTrue(
            app.buttons["viaCodigoDeBarras"].waitForExistence(timeout: 5),
            "No apareció la pantalla de comida"
        )

        app.buttons["segmentoGlucosa"].tap()
        XCTAssertTrue(campo.waitForExistence(timeout: 5), "No volvió la pantalla de glucosa")
        XCTAssertEqual(campo.value as? String, "112", "Se perdió lo escrito al cambiar de registro")
    }

    /// Volver a Glucosa con el selector no abre el teclado: nadie lo pidió.
    func testVolverAGlucosaNoAbreElTeclado() {
        let app = XCUIApplication()
        app.launch()

        let registrar = app.tabBars.buttons["Registrar"]
        XCTAssertTrue(registrar.waitForExistence(timeout: 10), "No apareció la pestaña Registrar")
        registrar.tap()

        app.buttons["segmentoComida"].tap()
        XCTAssertTrue(
            app.buttons["viaCodigoDeBarras"].waitForExistence(timeout: 5),
            "No apareció la pantalla de comida"
        )

        app.buttons["segmentoGlucosa"].tap()
        let campo = app.textFields["Valor de glucosa en miligramos por decilitro"]
        XCTAssertTrue(campo.waitForExistence(timeout: 5), "No volvió la pantalla de glucosa")
        XCTAssertTrue(
            app.keyboards.firstMatch.waitForNonExistence(timeout: 3),
            "El teclado se abrió solo al volver a Glucosa"
        )
    }
}
