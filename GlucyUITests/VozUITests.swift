import XCTest

/// Lo que VoiceOver va a leer. Corre con VoiceOver **apagado**: la etiqueta es la misma, y con
/// él encendido las pruebas no pueden tocar nada.
///
/// Se afirma el contenido de las etiquetas, no la frase palabra por palabra: una prueba que
/// fija la frase entera se rompe cada vez que se mejora la redacción. El orden en que
/// VoiceOver las dice no se puede afirmar desde aquí: eso se oye.
final class VozUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    /// Casilla 8. La etiqueta del valor lleva la cifra, su unidad y su antigüedad. Una cifra
    /// sola no sirve: «112» no dice si es de ahora o de hace tres horas.
    func testElValorSeLeeConSuUnidadYSuAntiguedad() {
        let app = XCUIApplication.yaDentro()
        app.anotarGlucosa("112")

        let valor = app.elemento("valorActual")
        app.tocar(app.tabBars.buttons["Inicio"], hastaVer: valor, "Inicio no enseña la lectura")

        let etiqueta = valor.label
        XCTAssertTrue(etiqueta.contains("112"), "No dice la cifra: \(etiqueta)")
        XCTAssertTrue(etiqueta.contains("miligramos por decilitro"), "No dice la unidad: \(etiqueta)")
        XCTAssertTrue(etiqueta.contains("hace"), "No dice la antigüedad: \(etiqueta)")
        // El modo va en la misma etiqueta: el letrero no es un elemento aparte.
        XCTAssertTrue(etiqueta.contains("Sin sensor"), "No nombra el modo: \(etiqueta)")

        // Y el aviso de que sin sensor no se anticipan hipoglucemias se lee completo.
        let aviso = app.elemento("avisoSinSensor")
        XCTAssertTrue(aviso.label.contains("Sin sensor no puedo anticipar hipoglucemias."))
        XCTAssertTrue(aviso.label.contains("Si te sientes mal, mídete."))
    }

    /// Casillas 9 y 10. Las tres cifras de Historial dicen su unidad y sobre cuántas
    /// mediciones se calcularon, y las dos gráficas tienen descripción.
    func testLasCifrasYLasGraficasTienenQueLeer() {
        let app = XCUIApplication.yaDentro()
        // Tres días distintos: con menos, Historial no enseña cifras.
        app.anotarGlucosa("112")
        app.anotarGlucosa("150", haceDias: 1)
        app.anotarGlucosa("95", haceDias: 2)

        // La gráfica de Inicio.
        let graficaDeInicio = app.elemento("graficaGlucosa")
        app.tocar(app.tabBars.buttons["Inicio"], hastaVer: app.elemento("valorActual"), "Inicio no enseña la lectura")
        XCTAssertTrue(graficaDeInicio.waitForExistence(timeout: 5), "Inicio no tiene gráfica")
        XCTAssertTrue(
            graficaDeInicio.label.contains("miligramos por decilitro"),
            "La gráfica de Inicio no se describe: «\(graficaDeInicio.label)»"
        )
        XCTAssertTrue(graficaDeInicio.label.contains("3 mediciones"), "No dice cuántas: «\(graficaDeInicio.label)»")

        // Historial.
        let tiempoEnRango = app.elemento("cifraTiempoEnRango")
        app.tocar(app.tabBars.buttons["Historial"], hastaVer: tiempoEnRango, "Historial no enseña sus cifras")

        XCTAssertTrue(tiempoEnRango.label.contains("por ciento"), tiempoEnRango.label)
        XCTAssertTrue(tiempoEnRango.label.contains("sobre 3 mediciones"), tiempoEnRango.label)

        let promedio = app.elemento("cifraPromedio")
        XCTAssertTrue(promedio.label.contains("miligramos por decilitro"), promedio.label)
        XCTAssertTrue(promedio.label.contains("sobre 3 mediciones"), promedio.label)

        // Con tres días el GMI no es fiable: la etiqueta dice por qué, no un número.
        let gmi = app.elemento("cifraGmi")
        XCTAssertTrue(gmi.exists, "La tarjeta del GMI desapareció")
        XCTAssertTrue(gmi.label.contains("Me faltan"), gmi.label)
        XCTAssertTrue(gmi.label.contains("necesita al menos 14 días"), gmi.label)
        XCTAssertFalse(gmi.label.contains("por ciento"), "Presenta un GMI que no es fiable: \(gmi.label)")

        // La gráfica del día típico.
        let diaTipico = app.elemento("graficaGlucosa")
        for _ in 0..<8 where !diaTipico.isHittable { app.swipeUp(velocity: .slow) }
        XCTAssertTrue(diaTipico.exists, "Historial no tiene la gráfica del día típico")
        XCTAssertTrue(
            diaTipico.label.contains("Tu día típico"),
            "La gráfica del día típico no se describe: «\(diaTipico.label)»"
        )
    }

    /// Casilla 12, la parte que se puede afirmar sin oír nada: ningún control del alta está
    /// sin etiqueta. Un control mudo es justo lo que deja a alguien atascado.
    func testNingunControlDelAltaEstaSinEtiqueta() {
        let app = XCUIApplication.recienInstalada()
        let paso1 = app.buttons["botonContinuarPaso1"]
        XCTAssertTrue(paso1.waitForExistence(timeout: 15), "No apareció el alta")

        revisarEtiquetas(en: app, paso: 1)
        app.tocar(paso1, hastaVer: app.buttons["tipoUsuario_tipo1"], "No apareció el paso 2")

        revisarEtiquetas(en: app, paso: 2)
        app.buttons["tipoUsuario_tipo1"].tap()
        app.escribir("1990", en: app.textFields["campoAnioNacimiento"])
        app.tocar(app.buttons["botonContinuarPaso2"], hastaVer: app.buttons["tarjetaSinSensor"], "No apareció el paso 3")

        revisarEtiquetas(en: app, paso: 3)
        app.buttons["tarjetaSinSensor"].tap()
        app.tocar(app.buttons["botonContinuarPaso3"], hastaVer: app.buttons["botonContinuarPaso4"], "No apareció el paso 4")

        revisarEtiquetas(en: app, paso: 4)
        app.tocar(app.buttons["botonContinuarPaso4"], hastaVer: app.buttons["botonAcepto"], "No apareció el paso 5")

        revisarEtiquetas(en: app, paso: 5)
    }

    private func revisarEtiquetas(en app: XCUIApplication, paso: Int) {
        // El paso se anuncia con su número.
        let progreso = app.elemento("pasoDelAlta")
        XCTAssertTrue(progreso.waitForExistence(timeout: 5), "Paso \(paso): no dice en qué paso va")
        XCTAssertTrue(progreso.label.contains("Paso \(paso) de 5"), "Dice «\(progreso.label)» en el paso \(paso)")

        let controles = app.buttons.allElementsBoundByIndex
            + app.textFields.allElementsBoundByIndex
            + app.switches.allElementsBoundByIndex
        XCTAssertFalse(controles.isEmpty, "Paso \(paso): no hay ningún control")
        for control in controles where control.exists {
            let etiqueta = control.label.trimmingCharacters(in: .whitespacesAndNewlines)
            XCTAssertFalse(
                etiqueta.isEmpty,
                "Paso \(paso): hay un control sin etiqueta (\(control.elementType.rawValue), «\(control.identifier)»)"
            )
        }
    }
}
