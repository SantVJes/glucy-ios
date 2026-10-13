import XCTest

/// Recorre las pantallas y las captura, para revisarlas juntas en el Mac en lugar de navegar
/// diez pantallas a mano en cada tamaño de letra.
///
/// No afirma nada sobre cómo se ven: eso lo decide quien mira la galería. Con
/// `GLUCY_LETRA_GRANDE=1` las saca con la letra de accesibilidad más grande.
final class CapturasUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    /// Captura la pantalla y, si es larga, lo que hay más abajo.
    private func capturar(_ nombre: String, en app: XCUIApplication, bajando veces: Int = 0) {
        capturar(nombre)
        for parte in 0..<veces {
            app.swipeUp(velocity: .slow)
            capturar("\(nombre)-\(parte + 2)")
        }
        for _ in 0..<veces { app.swipeDown(velocity: .fast) }
    }

    func testCapturarLasPantallas() {
        let app = XCUIApplication.paraCapturar()
        let largas = Entorno.letraGrande ? 3 : 1

        // El alta, paso por paso. El splash dura menos de lo que tarda en arrancar la prueba.
        let paso1 = app.buttons["botonContinuarPaso1"]
        XCTAssertTrue(paso1.waitForExistence(timeout: 15), "No apareció el alta")
        capturar("01-alta-paso-1", en: app)
        app.tocar(paso1, hastaVer: app.buttons["tipoUsuario_tipo1"], "No apareció el paso 2")

        app.buttons["tipoUsuario_tipo1"].tap()
        capturar("02-alta-paso-2", en: app, bajando: largas)
        app.escribir("1990", en: app.textFields["campoAnioNacimiento"])
        app.tocar(app.buttons["botonContinuarPaso2"], hastaVer: app.buttons["tarjetaSinSensor"], "No apareció el paso 3")

        capturar("03-alta-paso-3-tarjetas-de-sensor", en: app, bajando: largas)
        app.buttons["tarjetaSinSensor"].tap()
        app.tocar(app.buttons["botonContinuarPaso3"], hastaVer: app.buttons["botonContinuarPaso4"], "No apareció el paso 4")

        capturar("04-alta-paso-4", en: app, bajando: largas + 1)
        app.tocar(app.buttons["botonContinuarPaso4"], hastaVer: app.buttons["botonAcepto"], "No apareció el paso 5")

        capturar("05-alta-paso-5-consentimiento", en: app, bajando: largas + 1)
        app.tocar(app.buttons["botonAcepto"], hastaVer: app.tabBars.buttons["Inicio"], "El alta no llevó a las pestañas")

        // Inicio el primer día.
        XCTAssertTrue(app.elemento("avisoSinSensor").waitForExistence(timeout: 10))
        capturar("06-inicio-primer-dia", en: app, bajando: Entorno.letraGrande ? 1 : 0)

        // Tres días de lecturas, y una fuera de la escala de la gráfica para ver el triángulo.
        app.anotarGlucosa("112")
        capturar("07-registro-de-glucosa-guardada", en: app, bajando: largas)
        app.anotarGlucosa("450", haceDias: 1)
        app.anotarGlucosa("95", haceDias: 2)

        // Comida e insulina.
        app.tocar(app.buttons["segmentoComida"], hastaVer: app.buttons["viaCodigoDeBarras"], "No apareció comida")
        capturar("08-registro-de-comida", en: app, bajando: largas)
        app.tocar(app.buttons["segmentoInsulina"], hastaVer: app.buttons["botonMasMediaUnidad"], "No apareció insulina")
        capturar("09-registro-de-insulina", en: app, bajando: largas + 1)

        // Inicio con lecturas: la cifra con su unidad, el aviso y los puntos sin línea.
        app.tocar(app.tabBars.buttons["Inicio"], hastaVer: app.elemento("valorActual"), "Inicio no enseña la lectura")
        capturar("10-inicio-sin-sensor-con-lecturas", en: app, bajando: largas + 1)

        // Historial y la hoja del informe.
        app.tocar(app.tabBars.buttons["Historial"], hastaVer: app.elemento("cifraTiempoEnRango"), "Historial no enseña cifras")
        capturar("11-historial", en: app, bajando: largas + 1)
        let informe = app.buttons["botonInformeParaMiMedico"]
        for _ in 0..<10 where !informe.isHittable { app.swipeUp(velocity: .slow) }
        app.tocar(informe, hastaVer: app.elemento("interruptorDeIdentidad"), "No apareció la hoja del informe")
        XCTAssertTrue(app.elemento("botonCompartirPdf").waitForExistence(timeout: 10), "El PDF no terminó de armarse")
        capturar("12-hoja-del-informe", en: app, bajando: Entorno.letraGrande ? 1 : 0)
        app.tocar(app.buttons["botonCerrarInforme"], hastaVer: app.tabBars.buttons["Ajustes"], "La hoja no se cerró")

        // Ajustes, que es la pantalla más larga, y la barrera de borrado.
        app.tocar(app.tabBars.buttons["Ajustes"], hastaVer: app.textFields["ajusteNombre"], "No apareció Ajustes")
        capturar("13-ajustes", en: app, bajando: Entorno.letraGrande ? 16 : 5)
        let borrar = app.buttons["botonIrABorrarCuenta"]
        for _ in 0..<30 where !borrar.isHittable { app.swipeUp(velocity: .slow) }
        app.tocar(borrar, hastaVer: app.textFields["campoConfirmarBorrado"], "No apareció la barrera de borrado")
        capturar("14-borrar-la-cuenta", en: app, bajando: Entorno.letraGrande ? 1 : 0)
    }
}
