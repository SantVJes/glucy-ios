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

// MARK: - Para las pruebas que corren en el iPhone

/// Lo que el script le dice a las pruebas con una variable de entorno. `xcodebuild` se las
/// pasa al corredor quitándoles el prefijo `TEST_RUNNER_`.
enum Entorno {
    static func esta(_ variable: String) -> Bool {
        ProcessInfo.processInfo.environment[variable] == "1"
    }

    /// Con la letra de accesibilidad más grande.
    static var letraGrande: Bool { esta("GLUCY_LETRA_GRANDE") }
}

extension XCUIApplication {

    /// La app con la base en memoria y, si el script lo pidió, con la letra más grande.
    static func paraCapturar() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments.append("-GlucyBaseEnMemoria")
        if Entorno.letraGrande {
            app.launchArguments += [
                "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
            ]
        }
        app.launch()
        return app
    }

    func elemento(_ identificador: String) -> XCUIElement {
        descendants(matching: .any).matching(identifier: identificador).firstMatch
    }

    /// Recorre el alta eligiendo «Tengo un sensor». Si iOS enseña la hoja de permisos de
    /// Salud, la acepta; si ya se había contestado antes, iOS no la vuelve a enseñar.
    ///
    /// - Returns: `false` si Salud no dejó pedir el permiso y el alta siguió sin sensor.
    @discardableResult
    func completarAltaConSensor(tipo: String = "tipoUsuario_tipo1", anio: String = "1990") -> Bool {
        let paso1 = buttons["botonContinuarPaso1"]
        XCTAssertTrue(paso1.waitForExistence(timeout: 15), "No apareció el alta")
        let opcion = buttons[tipo]
        tocar(paso1, hastaVer: opcion, "No apareció la opción \(tipo)")

        opcion.tap()
        escribir(anio, en: textFields["campoAnioNacimiento"])
        let paso2 = buttons["botonContinuarPaso2"]
        XCTAssertTrue(paso2.wait(for: \.isEnabled, toEqual: true, timeout: 5), "No se pudo continuar del paso 2")
        let conSensor = buttons["tarjetaConSensor"]
        tocar(paso2, hastaVer: conSensor, "No aparecieron las tarjetas de sensor")

        conSensor.tap()
        XCTAssertTrue(
            elemento("explicacionDelPermiso").waitForExistence(timeout: 5),
            "La explicación del permiso no sale antes de la hoja del sistema"
        )
        buttons["botonContinuarPaso3"].tap()
        aceptarLaHojaDeSaludSiSale()
        let quedoConSensor = !elemento("seguimosSinSensor").waitForExistence(timeout: 3)

        let paso4 = buttons["botonContinuarPaso4"]
        // Si Salud no dejó pedir el permiso, el alta se queda un toque más para decirlo.
        tocar(buttons["botonContinuarPaso3"], hastaVer: paso4, "No apareció el paso de parámetros")
        let acepto = buttons["botonAcepto"]
        tocar(paso4, hastaVer: acepto, "No apareció el consentimiento")
        tocar(acepto, hastaVer: tabBars.buttons["Inicio"], "El alta no llevó a las pestañas")
        return quedoConSensor
    }

    /// La hoja de permisos de Salud, en español o en inglés. Sale dentro de la propia app.
    private func aceptarLaHojaDeSaludSiSale() {
        let permitir = descendants(matching: .any).matching(
            NSPredicate(format: "label IN %@", ["Permitir", "Allow"])
        ).firstMatch
        guard permitir.waitForExistence(timeout: 6) else { return }
        let activarTodo = descendants(matching: .any).matching(
            NSPredicate(format: "label IN %@", ["Activar todo", "Activar todas", "Turn On All"])
        ).firstMatch
        if activarTodo.exists { activarTodo.tap() }
        if permitir.isEnabled { permitir.tap() }
    }

    /// Toca el campo y escribe. Si el toque no abre el teclado —con la letra grande el campo
    /// puede quedar pegado a la barra de abajo—, sube un poco y vuelve a tocar.
    func escribir(_ texto: String, en campo: XCUIElement) {
        for _ in 0..<4 {
            campo.tap()
            if keyboards.firstMatch.waitForExistence(timeout: 2) { break }
            swipeUp(velocity: .slow)
        }
        campo.typeText(texto)
    }

    /// Registra una glucosa a mano desde la pestaña «Registrar».
    ///
    /// - Parameter haceDias: para fecharla en un día anterior, con el selector de fecha de la
    ///   pantalla. Es la única forma de tener lecturas de varios días sin tocar la base.
    func anotarGlucosa(_ valor: String, haceDias dias: Int = 0) {
        let campo = textFields["Valor de glucosa en miligramos por decilitro"]
        if !campo.exists || !campo.isHittable {
            tocar(tabBars.buttons["Registrar"], hastaVer: buttons["segmentoGlucosa"], "No apareció Registrar")
            tocar(buttons["segmentoGlucosa"], hastaVer: campo, "No apareció el campo del valor")
        }
        // La franja de la lectura anterior tiene que haberse ido, o no se sabría cuál se guardó.
        _ = staticTexts["Lectura guardada"].waitForNonExistence(timeout: 8)

        if dias > 0 { elegirFecha(haceDias: dias) }
        escribir(valor, en: campo)
        tocar(buttons["botonGuardar"], hastaVer: staticTexts["Lectura guardada"], "La lectura de \(valor) no se guardó")
    }

    /// Elige un día anterior en el calendario del selector de fecha.
    private func elegirFecha(haceDias dias: Int) {
        let calendario = Calendar.current
        let hoy = Date()
        guard let destino = calendario.date(byAdding: .day, value: -dias, to: hoy) else { return }

        // El selector compacto tiene dos botones: la fecha y la hora. La fecha abre el mes.
        let selector = datePickers.firstMatch
        for _ in 0..<6 where !selector.isHittable { swipeUp(velocity: .slow) }
        let botonDeFecha = selector.buttons.element(boundBy: 1)
        let mesAnterior = buttons["DatePicker.PreviousMonth"]
        tocar(botonDeFecha, hastaVer: mesAnterior, "No se abrió el calendario")
        if calendario.component(.month, from: destino) != calendario.component(.month, from: hoy) {
            mesAnterior.tap()
        }

        // El día se busca por su número al final de la etiqueta: «Monday, 12 October» o
        // «lunes, 12 de octubre», según en qué idioma salga el calendario.
        let dia = calendario.component(.day, from: destino)
        let delDia = buttons.matching(
            NSPredicate(format: "label MATCHES %@", ".*[^0-9]\(dia) [^0-9]+$")
        ).firstMatch
        XCTAssertTrue(delDia.waitForExistence(timeout: 5), "No está el día \(dia) en el calendario")
        delDia.tap()

        // Tocar fuera cierra el calendario. Dónde queda «fuera» depende del tamaño de la
        // letra: con la más grande el calendario ocupa casi toda la pantalla, así que se
        // prueba arriba, abajo y a los lados hasta que se cierra.
        let fuera = [(0.5, 0.2), (0.5, 0.97), (0.02, 0.5), (0.98, 0.5), (0.5, 0.12)]
        for (x, y) in fuera where mesAnterior.exists {
            coordinate(withNormalizedOffset: CGVector(dx: x, dy: y)).tap()
            _ = mesAnterior.waitForNonExistence(timeout: 2)
        }
        XCTAssertFalse(mesAnterior.exists, "El calendario no se cerró")
        for _ in 0..<6 where !textFields["Valor de glucosa en miligramos por decilitro"].isHittable {
            swipeDown(velocity: .slow)
        }
    }
}

extension XCTestCase {
    /// Guarda una captura de la pantalla con un nombre que el script reconoce al exportarla.
    func capturar(_ nombre: String) {
        let captura = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        captura.name = nombre
        captura.lifetime = .keepAlways
        add(captura)
    }
}
