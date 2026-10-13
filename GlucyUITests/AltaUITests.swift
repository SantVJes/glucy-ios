import XCTest

/// El alta de punta a punta, como la vive la persona: es el criterio de «hecho» del paso 9.
final class AltaUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    /// Prueba 26 · RF-06: se completa eligiendo «Sin sensor», sin tocar ningún permiso, y la
    /// app queda en las pestañas.
    func testElAltaSeCompletaSinSensorYSinPermisos() {
        let app = XCUIApplication.recienInstalada()

        // Lo primero es el alta, no las pestañas: la puerta es el consentimiento.
        XCTAssertTrue(app.buttons["botonContinuarPaso1"].waitForExistence(timeout: 15), "No apareció el alta")
        XCTAssertFalse(app.tabBars.firstMatch.exists, "Las pestañas se ven antes de aceptar")

        // Si saliera una hoja de permisos del sistema, este monitor lo anotaría.
        var salioUnaHojaDelSistema = false
        let monitor = addUIInterruptionMonitor(withDescription: "Permisos") { _ in
            salioUnaHojaDelSistema = true
            return false
        }
        defer { removeUIInterruptionMonitor(monitor) }

        app.completarAltaSinSensor()

        XCTAssertFalse(salioUnaHojaDelSistema, "El alta «sin sensor» pidió un permiso")
        // Ya dentro, y en modo sin sensor, con su aviso.
        XCTAssertTrue(
            app.descendants(matching: .any)["avisoSinSensor"].waitForExistence(timeout: 10),
            "Inicio no enseña el aviso del modo sin sensor"
        )
        for pestana in ["Inicio", "Registrar", "Historial", "Ajustes"] {
            XCTAssertTrue(app.tabBars.buttons[pestana].exists, "Falta la pestaña \(pestana)")
        }
    }

    /// RF-10b en el onboarding: la tarjeta «Sin sensor» advierte antes de elegir, y las dos
    /// tarjetas son del mismo tamaño.
    func testLasTarjetasDeSensorSonIgualesYLaSinSensorAdvierte() {
        let app = XCUIApplication.recienInstalada()
        XCTAssertTrue(app.buttons["botonContinuarPaso1"].waitForExistence(timeout: 15), "No apareció el alta")
        app.buttons["botonContinuarPaso1"].tap()
        app.buttons["tipoUsuario_prediabetes"].tap()
        let campoAnio = app.textFields["campoAnioNacimiento"]
        campoAnio.tap()
        campoAnio.typeText("1985")
        app.buttons["botonContinuarPaso2"].tap()

        let conSensor = app.buttons["tarjetaConSensor"]
        let sinSensor = app.buttons["tarjetaSinSensor"]
        XCTAssertTrue(sinSensor.waitForExistence(timeout: 5), "No aparecieron las tarjetas de sensor")

        XCTAssertTrue(sinSensor.label.contains("Sin sensor no puedo anticipar hipoglucemias"))
        XCTAssertEqual(conSensor.frame.width, sinSensor.frame.width, accuracy: 1)
        XCTAssertEqual(conSensor.frame.height, sinSensor.frame.height, accuracy: 1)

        // Ninguna viene elegida: no se puede continuar sin escoger.
        XCTAssertFalse(app.buttons["botonContinuarPaso3"].isEnabled)
    }

    /// Sin aceptar no se entra, y quien no llega a la edad mínima no pasa del segundo paso.
    func testSinEdadMinimaNoSeContinua() {
        let app = XCUIApplication.recienInstalada()
        XCTAssertTrue(app.buttons["botonContinuarPaso1"].waitForExistence(timeout: 15), "No apareció el alta")
        app.buttons["botonContinuarPaso1"].tap()
        app.buttons["tipoUsuario_tipo1"].tap()

        let campoAnio = app.textFields["campoAnioNacimiento"]
        campoAnio.tap()
        campoAnio.typeText(String(Calendar.current.component(.year, from: Date()) - 10))
        XCTAssertFalse(app.buttons["botonContinuarPaso2"].isEnabled, "Con diez años se pudo continuar")
        XCTAssertFalse(app.tabBars.firstMatch.exists)
    }
}
