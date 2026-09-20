import XCTest

/// El recorrido de punta a punta: abrir la app, ir a Registrar, anotar una glucosa y ver la
/// confirmación.
final class RegistroGlucosaUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    func testRegistrarUnaLecturaAMano() {
        let app = XCUIApplication()
        app.launch()

        // La app abre en cuatro pestañas; Registrar es la segunda.
        let registrar = app.tabBars.buttons["Registrar"]
        XCTAssertTrue(registrar.waitForExistence(timeout: 10), "No apareció la pestaña Registrar")
        registrar.tap()

        let campo = app.textFields["Valor de glucosa en miligramos por decilitro"]
        XCTAssertTrue(campo.waitForExistence(timeout: 5), "No apareció el campo del valor")
        campo.tap()
        campo.typeText("112")

        app.buttons["En ayunas"].tap()
        app.buttons["botonGuardar"].tap()

        // La franja de confirmación, que es lo que le dice a la persona que sí quedó.
        let franja = app.staticTexts["Lectura guardada"]
        XCTAssertTrue(franja.waitForExistence(timeout: 5), "No apareció la franja de confirmación")
    }
}
