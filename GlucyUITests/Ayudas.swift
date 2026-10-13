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

    /// Toca `boton` y espera a que aparezca `siguiente`. Si no aparece, vuelve a tocar.
    ///
    /// En un teléfono de verdad, un toque sintetizado mientras la pantalla todavía se está
    /// moviendo —el splash que se desvanece, el teclado que baja, la pestaña que cambia— a
    /// veces no llega. Una persona volvería a tocar; la prueba también.
    func tocar(
        _ boton: XCUIElement, hastaVer siguiente: XCUIElement, _ mensaje: String,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        for _ in 0..<3 {
            if boton.exists, boton.isHittable, boton.isEnabled { boton.tap() }
            if siguiente.waitForExistence(timeout: 6) { return }
        }
        XCTFail(mensaje, file: file, line: line)
    }

    /// Recorre los cinco pasos del alta eligiendo «Me mido con glucómetro».
    func completarAltaSinSensor(tipo: String = "tipoUsuario_tipo1", anio: String = "1990") {
        // Paso 1: el nombre y los apellidos se dejan en blanco, que son opcionales.
        let paso1 = buttons["botonContinuarPaso1"]
        XCTAssertTrue(paso1.waitForExistence(timeout: 15), "No apareció el alta")
        let opcion = buttons[tipo]
        tocar(paso1, hastaVer: opcion, "No apareció la opción \(tipo)")

        // Paso 2: tipo de usuario y año de nacimiento.
        opcion.tap()
        let campoAnio = textFields["campoAnioNacimiento"]
        campoAnio.tap()
        campoAnio.typeText(anio)
        let paso2 = buttons["botonContinuarPaso2"]
        XCTAssertTrue(
            paso2.wait(for: \.isEnabled, toEqual: true, timeout: 5),
            "Con el tipo y el año puestos no se pudo continuar"
        )
        let sinSensor = buttons["tarjetaSinSensor"]
        tocar(paso2, hastaVer: sinSensor, "No aparecieron las tarjetas de sensor")

        // Paso 3: sin sensor. No pide nada.
        sinSensor.tap()
        let paso4 = buttons["botonContinuarPaso4"]
        tocar(buttons["botonContinuarPaso3"], hastaVer: paso4, "No apareció el paso de parámetros")

        // Paso 4: todo trae su valor por omisión.
        let acepto = buttons["botonAcepto"]
        tocar(paso4, hastaVer: acepto, "No apareció el consentimiento")

        // Paso 5: el consentimiento.
        tocar(acepto, hastaVer: tabBars.buttons["Inicio"], "El alta no llevó a las pestañas")
    }
}
