import XCTest

/// P-15: las diez pantallas con la letra de accesibilidad más grande.
///
/// Comprueba las tres formas en que esto se rompe de verdad: que los elementos clave sigan
/// existiendo y se puedan tocar, que ninguno se salga del ancho de la ventana, y que el
/// recorrido crítico se pueda terminar.
///
/// Lo que **no** detecta es un texto cortado con puntos suspensivos dentro de su propio
/// marco. Eso se mira en el iPhone.
final class AccesibilidadUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    private func appConLaLetraMasGrande() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-GlucyBaseEnMemoria",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
        ]
        app.launch()
        return app
    }

    private func elemento(_ identificador: String, en app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identificador).firstMatch
    }

    /// Lleva el elemento a donde se pueda tocar, desplazando si hace falta, y comprueba que
    /// se alcanza y que cabe a lo ancho.
    private func comprobar(
        _ identificadores: [String], en app: XCUIApplication, pantalla: String,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        let ventana = app.windows.firstMatch.frame
        for identificador in identificadores {
            let elemento = elemento(identificador, en: app)
            XCTAssertTrue(
                elemento.waitForExistence(timeout: 5),
                "\(pantalla): no existe «\(identificador)»", file: file, line: line
            )
            var intentos = 0
            while !elemento.isHittable, intentos < 12 {
                app.swipeUp(velocity: .slow)
                intentos += 1
            }
            XCTAssertTrue(
                elemento.isHittable,
                "\(pantalla): «\(identificador)» existe pero no se alcanza", file: file, line: line
            )
            let marco = elemento.frame
            XCTAssertGreaterThanOrEqual(
                marco.minX, ventana.minX - 1,
                "\(pantalla): «\(identificador)» se sale por la izquierda", file: file, line: line
            )
            XCTAssertLessThanOrEqual(
                marco.maxX, ventana.maxX + 1,
                "\(pantalla): «\(identificador)» se sale por la derecha", file: file, line: line
            )
        }
    }

    /// Prueba 16 · P-15.
    func testLasDiezPantallasConLaLetraMasGrande() {
        let app = appConLaLetraMasGrande()

        // 1 y 2 · El splash se retira solo y deja el alta, paso por paso.
        comprobar(["campoNombre", "campoApellidos", "botonContinuarPaso1"], en: app, pantalla: "Alta, paso 1")
        app.tocar(
            app.buttons["botonContinuarPaso1"], hastaVer: app.buttons["tipoUsuario_tipo1"],
            "No apareció el paso 2 del alta"
        )

        comprobar(
            ["tipoUsuario_tipo1", "tipoUsuario_tipo2_insulinodependiente", "tipoUsuario_prediabetes",
             "tipoUsuario_resistencia_insulina", "campoAnioNacimiento"],
            en: app, pantalla: "Alta, paso 2"
        )
        // Con esta letra el campo puede quedar pegado a la barra de «Continuar»: si el toque
        // no abre el teclado, se sube un poco y se vuelve a tocar, como haría una persona.
        let campoAnio = app.textFields["campoAnioNacimiento"]
        for _ in 0..<4 {
            campoAnio.tap()
            if app.keyboards.firstMatch.waitForExistence(timeout: 2) { break }
            app.swipeUp(velocity: .slow)
        }
        XCTAssertTrue(app.keyboards.firstMatch.exists, "Alta, paso 2: el campo del año no abre el teclado")
        campoAnio.typeText("1960")
        // Con el año ya puesto, se elige el tipo: tocarlo baja el teclado.
        app.swipeDown(velocity: .slow)
        app.swipeDown(velocity: .slow)
        comprobar(["tipoUsuario_tipo1"], en: app, pantalla: "Alta, paso 2")
        app.buttons["tipoUsuario_tipo1"].tap()
        comprobar(["botonContinuarPaso2"], en: app, pantalla: "Alta, paso 2")
        app.tocar(
            app.buttons["botonContinuarPaso2"], hastaVer: app.buttons["tarjetaConSensor"],
            "No apareció el paso 3 del alta"
        )

        // Las dos tarjetas siguen siendo del mismo tamaño cuando se apilan.
        let conSensor = app.buttons["tarjetaConSensor"]
        let sinSensor = app.buttons["tarjetaSinSensor"]
        XCTAssertEqual(conSensor.frame.width, sinSensor.frame.width, accuracy: 1)
        XCTAssertEqual(conSensor.frame.height, sinSensor.frame.height, accuracy: 1)
        comprobar(["tarjetaConSensor", "tarjetaSinSensor"], en: app, pantalla: "Alta, paso 3")
        sinSensor.tap()
        comprobar(["botonContinuarPaso3"], en: app, pantalla: "Alta, paso 3")
        app.tocar(
            app.buttons["botonContinuarPaso3"], hastaVer: app.buttons["botonContinuarPaso4"],
            "No apareció el paso 4 del alta"
        )

        comprobar(
            ["unidad_mgDl", "unidad_mmolL", "umbralHipoMas", "umbralHiperMenos", "campoPeso",
             "campoTipoInsulina", "duracionAccionMas", "botonContinuarPaso4"],
            en: app, pantalla: "Alta, paso 4"
        )
        app.tocar(
            app.buttons["botonContinuarPaso4"], hastaVer: app.buttons["botonAcepto"],
            "No apareció el consentimiento"
        )

        comprobar(["fechaDelConsentimiento", "botonAcepto"], en: app, pantalla: "Alta, paso 5")
        app.tocar(
            app.buttons["botonAcepto"], hastaVer: app.tabBars.buttons["Inicio"],
            "El alta no llevó a las pestañas"
        )

        // 3 · Inicio, sin sensor y sin lecturas.
        comprobar(["avisoSinSensor", "botonIrARegistrar"], en: app, pantalla: "Inicio")

        // 4 · Registro de glucosa.
        app.tocar(
            app.tabBars.buttons["Registrar"], hastaVer: app.buttons["segmentoGlucosa"],
            "No apareció la pestaña Registrar"
        )
        comprobar(
            ["segmentoGlucosa", "segmentoComida", "segmentoInsulina", "viaFoto", "viaSensor", "botonGuardar"],
            en: app, pantalla: "Registro de glucosa"
        )

        // 5 · Registro de comida.
        app.swipeDown(velocity: .slow)
        app.tocar(
            app.buttons["segmentoComida"], hastaVer: app.buttons["viaCodigoDeBarras"],
            "No apareció la pantalla de comida"
        )
        comprobar(
            ["viaCodigoDeBarras", "viaFotoEtiqueta", "viaManual", "botonGuardarComida"],
            en: app, pantalla: "Registro de comida"
        )

        // 6 · Registro de insulina.
        app.swipeDown(velocity: .slow)
        app.tocar(
            app.buttons["segmentoInsulina"], hastaVer: app.buttons["botonMasMediaUnidad"],
            "No apareció la pantalla de insulina"
        )
        comprobar(
            ["avisoDeLaFrontera", "campoUnidades", "botonMasMediaUnidad", "botonMenosMediaUnidad",
             "tipoRapida", "tipoBasal", "botonGuardarDosis"],
            en: app, pantalla: "Registro de insulina"
        )

        // 7 · Historial.
        app.tocar(
            app.tabBars.buttons["Historial"], hastaVer: app.buttons["periodo7"],
            "No apareció Historial"
        )
        comprobar(
            ["periodo7", "periodo14", "periodo30", "diasQueLlevas", "botonInformeParaMiMedico"],
            en: app, pantalla: "Historial"
        )

        // 8 · La hoja del informe.
        app.tocar(
            app.buttons["botonInformeParaMiMedico"], hastaVer: elemento("interruptorDeIdentidad", en: app),
            "No apareció la hoja del informe"
        )
        comprobar(
            ["interruptorDeIdentidad", "botonCompartirPdf", "botonCerrarInforme"],
            en: app, pantalla: "Informe"
        )
        app.tocar(
            app.buttons["botonCerrarInforme"], hastaVer: app.tabBars.buttons["Ajustes"],
            "La hoja del informe no se cerró"
        )

        // 9 · Ajustes.
        app.tocar(
            app.tabBars.buttons["Ajustes"], hastaVer: app.textFields["ajusteNombre"],
            "No apareció Ajustes"
        )
        comprobar(
            ["ajusteNombre", "ajustePeso", "ajusteUnidad_mgDl", "ajusteUmbralHipoMas",
             "ajusteRegistraInsulina", "ajusteDuracionAccionMas", "ajusteUsaSensor",
             "ajusteSincronizacion", "pendientesEnCola", "ajusteCandado", "botonIrABorrarCuenta",
             "avisoNoEsDispositivoMedico"],
            en: app, pantalla: "Ajustes"
        )

        // 10 · La barrera de borrar la cuenta.
        comprobar(["botonIrABorrarCuenta"], en: app, pantalla: "Ajustes")
        app.tocar(
            app.buttons["botonIrABorrarCuenta"], hastaVer: app.textFields["campoConfirmarBorrado"],
            "No apareció la barrera de borrado"
        )
        comprobar(
            ["loQueSePierde", "campoConfirmarBorrado", "botonBorrarCuenta"],
            en: app, pantalla: "Borrar la cuenta"
        )
    }

    /// Prueba 17 · P-15: con esa letra, registrar una glucosa a mano de punta a punta. Si el
    /// botón de guardar no se alcanza, la app no es usable para quien necesita esa letra.
    func testRegistrarUnaGlucosaConLaLetraMasGrande() {
        let app = appConLaLetraMasGrande()
        app.completarAltaSinSensor()

        let campo = app.textFields["Valor de glucosa en miligramos por decilitro"]
        app.tocar(app.tabBars.buttons["Registrar"], hastaVer: campo, "No apareció el campo del valor")
        campo.tap()
        campo.typeText("112")

        comprobar(["botonGuardar"], en: app, pantalla: "Registro de glucosa")
        app.tocar(
            app.buttons["botonGuardar"], hastaVer: app.staticTexts["Lectura guardada"],
            "No apareció la franja de confirmación"
        )
        comprobar(["botonDeshacer"], en: app, pantalla: "Registro de glucosa")

        // Y lo guardado se ve en Inicio, con su cifra entera.
        let valor = elemento("valorActual", en: app)
        app.tocar(app.tabBars.buttons["Inicio"], hastaVer: valor, "Inicio no enseña la lectura")
        XCTAssertTrue(valor.label.hasPrefix("112 miligramos por decilitro"), "Inicio dice: \(valor.label)")
        comprobar(
            ["valorActual", "avisoSinSensor", "graficaGlucosa", "accesoAnotarComida", "accesoAnotarInsulina"],
            en: app, pantalla: "Inicio con una lectura"
        )
    }
}
