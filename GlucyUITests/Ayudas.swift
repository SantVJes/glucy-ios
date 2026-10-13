import XCTest

extension XCUIApplication {

    /// La app recién instalada: con la base en memoria, así que arranca en el alta y no toca
    /// los datos de quien corre las pruebas en su propio teléfono.
    static func recienInstalada() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments.append("-GlucyBaseEnMemoria")
        app.launch()
        return app
    }

    /// La app ya dentro, en las pestañas, después de un alta «sin sensor» que no concede
    /// ningún permiso. Es el punto de partida de las pruebas que no son del alta.
    static func yaDentro(tipo: String = "tipoUsuario_tipo1") -> XCUIApplication {
        let app = recienInstalada()
        app.completarAltaSinSensor(tipo: tipo)
        return app
    }

    /// Recorre los cinco pasos del alta eligiendo «Me mido con glucómetro».
    func completarAltaSinSensor(tipo: String = "tipoUsuario_tipo1", anio: String = "1990") {
        // Paso 1: el nombre y los apellidos se dejan en blanco, que son opcionales.
        let paso1 = buttons["botonContinuarPaso1"]
        XCTAssertTrue(paso1.waitForExistence(timeout: 15), "No apareció el alta")
        paso1.tap()

        // Paso 2: tipo de usuario y año de nacimiento.
        let opcion = buttons[tipo]
        XCTAssertTrue(opcion.waitForExistence(timeout: 5), "No apareció la opción \(tipo)")
        opcion.tap()
        let campoAnio = textFields["campoAnioNacimiento"]
        campoAnio.tap()
        campoAnio.typeText(anio)
        buttons["botonContinuarPaso2"].tap()

        // Paso 3: sin sensor. No pide nada.
        let sinSensor = buttons["tarjetaSinSensor"]
        XCTAssertTrue(sinSensor.waitForExistence(timeout: 5), "No aparecieron las tarjetas de sensor")
        sinSensor.tap()
        buttons["botonContinuarPaso3"].tap()

        // Paso 4: todo trae su valor por omisión.
        let paso4 = buttons["botonContinuarPaso4"]
        XCTAssertTrue(paso4.waitForExistence(timeout: 5), "No apareció el paso de parámetros")
        paso4.tap()

        // Paso 5: el consentimiento.
        let acepto = buttons["botonAcepto"]
        XCTAssertTrue(acepto.waitForExistence(timeout: 5), "No apareció el consentimiento")
        acepto.tap()

        XCTAssertTrue(
            tabBars.buttons["Inicio"].waitForExistence(timeout: 10),
            "El alta no llevó a las pestañas"
        )
    }
}
