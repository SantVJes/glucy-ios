import UIKit
import XCTest

/// Las pruebas que dependen de un interruptor del teléfono: la persona pone el estado y la
/// prueba lo comprueba.
///
/// Todas empiezan saltándose si el script no las pidió o si el teléfono no está de verdad
/// como hace falta. **No fallan por eso**: una prueba que falla porque el teléfono no está
/// como ella quiere acaba desactivada, y con ella se van las que sí servían.
final class EntornoDelTelefonoUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    /// Si el teléfono llega a internet ahora mismo. Se pregunta de verdad, pidiendo la
    /// cabecera de Open Food Facts, que es justo el servicio que tiene que faltar: con el
    /// cable puesto el sistema dice que «hay ruta» aunque no haya wifi ni datos.
    private func hayRed() -> Bool {
        var peticion = URLRequest(url: URL(string: "https://world.openfoodfacts.org/")!)
        peticion.httpMethod = "HEAD"
        peticion.timeoutInterval = 4
        peticion.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        let listo = DispatchSemaphore(value: 0)
        nonisolated(unsafe) var respondio = false
        let sesion = URLSession(configuration: .ephemeral)
        sesion.dataTask(with: peticion) { _, respuesta, _ in
            respondio = respuesta != nil
            listo.signal()
        }.resume()
        _ = listo.wait(timeout: .now() + 6)
        sesion.invalidateAndCancel()
        return respondio
    }

    /// Espera a que la persona deje el teléfono sin red, y se salta si no lo hace.
    ///
    /// Se apagan el wifi y los datos móviles, **no** se enciende el modo avión: el modo avión
    /// corta también la conexión de Xcode con el teléfono y la prueba se muere a media
    /// corrida. Y no puede estar sin red desde antes, porque para abrir las pruebas iOS
    /// comprueba en línea el certificado de desarrollo. Para la app es lo mismo: no hay por
    /// dónde salir.
    private func esperarAQueNoHayaRed(segundos: TimeInterval = 180) throws {
        let limite = Date().addingTimeInterval(segundos)
        while hayRed(), Date() < limite { sleep(2) }
        try XCTSkipUnless(
            !hayRed(),
            "El teléfono siguió con red \(Int(segundos)) s: apaga el wifi y los datos móviles cuando la prueba ya esté abierta"
        )
    }

    // MARK: - Modo avión (P-07 y P-10)

    /// Casilla 14. Sin red se registra una glucosa, una comida a mano y una dosis; las tres
    /// quedan guardadas y la cola las cuenta.
    func testEnModoAvionTodoSeGuardaYLaColaLoCuenta() throws {
        try XCTSkipUnless(Entorno.esta("GLUCY_MODO_AVION"), "Corre con GLUCY_MODO_AVION=1 y apaga el wifi y los datos móviles cuando la prueba ya esté abierta")

        // La app se abre todavía con red: recién instalada, iOS comprueba en línea su
        // certificado la primera vez que arranca. El alta se hace mientras tanto.
        let app = XCUIApplication.yaDentro()
        try esperarAQueNoHayaRed()
        app.anotarGlucosa("118")

        app.tocar(app.buttons["segmentoComida"], hastaVer: app.buttons["viaManual"], "No apareció comida")
        let carbohidratos = app.textFields["campoCarbohidratos"]
        app.tocar(app.buttons["viaManual"], hastaVer: carbohidratos, "La captura manual no abre el campo de gramos")
        app.escribir("30", en: carbohidratos)
        app.tocar(app.buttons["botonGuardarComida"], hastaVer: app.staticTexts["Comida guardada"], "La comida no se guardó")

        let mas = app.buttons["botonMasMediaUnidad"]
        app.tocar(app.buttons["segmentoInsulina"], hastaVer: mas, "No apareció insulina")
        for _ in 0..<4 { mas.tap() }
        app.buttons["tipoRapida"].tap()
        app.tocar(app.buttons["botonGuardarDosis"], hastaVer: app.buttons["botonDeshacerDosis"], "La dosis no se guardó")

        // Las tres se ven en Inicio: el valor, los carbohidratos y la insulina que siguen activos.
        let valor = app.elemento("valorActual")
        app.tocar(app.tabBars.buttons["Inicio"], hastaVer: valor, "Inicio no enseña la lectura")
        XCTAssertTrue(valor.label.contains("118"), valor.label)
        let carbohidratosActivos = app.elemento("carbohidratosActivos")
        for _ in 0..<8 where !carbohidratosActivos.isHittable { app.swipeUp(velocity: .slow) }
        XCTAssertTrue(carbohidratosActivos.label.contains("30 gramos"), carbohidratosActivos.label)
        XCTAssertTrue(app.elemento("insulinaActivaEnInicio").label.contains("2.0 unidades"), app.elemento("insulinaActivaEnInicio").label)

        // Y Ajustes dice cuántos registros esperan turno.
        app.tocar(app.tabBars.buttons["Ajustes"], hastaVer: app.textFields["ajusteNombre"], "No apareció Ajustes")
        let pendientes = app.elemento("pendientesEnCola")
        for _ in 0..<20 where !pendientes.isHittable { app.swipeUp(velocity: .slow) }
        XCTAssertEqual(pendientes.label, "3 registros esperan en la cola.")
    }

    /// Casilla 15. Sin red, un código de barras no lleva a una pantalla de error: ofrece la
    /// foto de la etiqueta y, desde ahí, la captura manual.
    ///
    /// Con la cámara permitida el código solo se puede escanear, y una prueba no puede
    /// enseñarle un producto a la cámara. Por eso esta prueba le quita el permiso de cámara a
    /// Glucy, contesta que no cuando iOS pregunta y escribe el código; al terminar deja el
    /// permiso sin contestar, así que iOS lo vuelve a preguntar la próxima vez.
    func testEnModoAvionElCodigoDeBarrasBajaALaFotoYALoManual() throws {
        try XCTSkipUnless(Entorno.esta("GLUCY_MODO_AVION"), "Corre con GLUCY_MODO_AVION=1 y apaga el wifi y los datos móviles cuando la prueba ya esté abierta")

        let app = XCUIApplication()
        app.launchArguments.append("-GlucyBaseEnMemoria")
        app.resetAuthorizationStatus(for: .camera)
        addTeardownBlock { app.resetAuthorizationStatus(for: .camera) }
        let pregunta = addUIInterruptionMonitor(withDescription: "Permiso de cámara") { alerta in
            for titulo in ["No permitir", "Don’t Allow", "Don't Allow"] where alerta.buttons[titulo].exists {
                alerta.buttons[titulo].tap()
                return true
            }
            return false
        }
        defer { removeUIInterruptionMonitor(pregunta) }
        // Se abre todavía con red, por lo mismo que la otra, y después se espera a que no haya.
        app.launch()
        app.completarAltaSinSensor()
        try esperarAQueNoHayaRed()

        app.tocar(app.tabBars.buttons["Registrar"], hastaVer: app.buttons["segmentoComida"], "No apareció Registrar")
        app.tocar(app.buttons["segmentoComida"], hastaVer: app.buttons["viaCodigoDeBarras"], "No apareció comida")
        app.buttons["viaCodigoDeBarras"].tap()

        // La pregunta de iOS no se contesta hasta que la app recibe un toque.
        let campoCodigo = app.textFields["campoCodigoDeBarras"]
        for _ in 0..<4 where !campoCodigo.waitForExistence(timeout: 3) {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
        try XCTSkipUnless(
            campoCodigo.exists,
            "No se pudo negar el permiso de cámara, y con cámara el código solo se puede escanear: esta casilla se queda a ojo"
        )
        campoCodigo.tap()
        campoCodigo.typeText("7501055300075")
        app.buttons["botonBuscarCodigo"].tap()

        // Baja un escalón y lo dice, sin hablar de errores ni de conexión.
        let aviso = app.elemento("avisoComida")
        XCTAssertTrue(aviso.waitForExistence(timeout: 20), "Sin red, el código no llevó al aviso de la etiqueta")
        let textos = app.staticTexts.allElementsBoundByIndex.map { $0.label }.joined(separator: " ")
        XCTAssertFalse(textos.localizedCaseInsensitiveContains("error"), "Habla de error: \(textos)")
        XCTAssertFalse(textos.localizedCaseInsensitiveContains("conexión"), "Habla de conexión: \(textos)")
        XCTAssertEqual(app.alerts.count, 0, "Salió un diálogo de error")
        XCTAssertFalse(app.elemento("falloComida").exists, "Salió un mensaje de fallo")

        // El siguiente escalón está ahí mismo, y el último también.
        XCTAssertTrue(app.buttons["botonFotoDeEtiqueta"].isHittable, "No ofrece la foto de la etiqueta")
        let carbohidratos = app.textFields["campoCarbohidratos"]
        let manual = app.buttons["viaManual"]
        for _ in 0..<6 where !manual.isHittable { app.swipeUp(velocity: .slow) }
        app.tocar(manual, hastaVer: carbohidratos, "La captura manual no abre el campo de gramos")
    }

    // MARK: - Reducir movimiento

    /// Casilla 13, lo afirmable. Que el splash desaparezca en vez de desvanecerse **no se
    /// puede afirmar desde una prueba**: dura menos de lo que tarda la prueba en ver la
    /// pantalla. Lo que se comprueba es que el ajuste está puesto de verdad y que con él la
    /// app arranca, el splash se retira y el alta queda lista.
    func testConReducirMovimientoElSplashSeRetira() throws {
        try XCTSkipUnless(
            Entorno.esta("GLUCY_REDUCIR_MOVIMIENTO"),
            "Enciende «Reducir movimiento» y corre con GLUCY_REDUCIR_MOVIMIENTO=1"
        )
        try XCTSkipUnless(
            UIAccessibility.isReduceMotionEnabled,
            "«Reducir movimiento» no está encendido en el teléfono"
        )

        let app = XCUIApplication.recienInstalada()
        XCTAssertTrue(app.buttons["botonContinuarPaso1"].waitForExistence(timeout: 15), "No apareció el alta")
        XCTAssertFalse(app.elemento("splash").exists, "El splash sigue ahí con el alta ya en pantalla")
        capturar("reducir-movimiento-alta")

        app.completarAltaSinSensor()
        XCTAssertFalse(app.elemento("splash").exists)
        // El selector de «Registrar» tampoco se desliza: la pantalla nueva está en su sitio
        // en cuanto se toca.
        app.tocar(app.tabBars.buttons["Registrar"], hastaVer: app.buttons["segmentoComida"], "No apareció Registrar")
        app.buttons["segmentoComida"].tap()
        let via = app.buttons["viaCodigoDeBarras"]
        XCTAssertTrue(via.waitForExistence(timeout: 5))
        let ventana = app.windows.firstMatch.frame
        XCTAssertEqual(via.frame.midX, ventana.midX, accuracy: 2, "La pantalla de comida quedó corrida")
    }

    // MARK: - Salud

    /// Casilla 19 (P-09). Con sensor en el perfil y el permiso de glucosa negado en Salud, la
    /// app no se cae: entra, está en modo sin sensor y lo dice.
    func testConSaludRevocadaLaAppSigueEnModoSinSensor() throws {
        try XCTSkipUnless(
            Entorno.esta("GLUCY_SALUD_REVOCADA"),
            "Niega a Glucy la lectura de glucosa en la app Salud y corre con GLUCY_SALUD_REVOCADA=1"
        )

        let app = XCUIApplication.recienInstalada()
        app.completarAltaConSensor()

        XCTAssertTrue(app.elemento("avisoSinSensor").waitForExistence(timeout: 15), "No declara el modo sin sensor")
        XCTAssertEqual(app.alerts.count, 0, "Salió un diálogo de error")
        XCTAssertEqual(app.state, .runningForeground, "La app no sigue abierta")

        // Y sigue siendo usable: se registra una lectura y se ve.
        app.anotarGlucosa("121")
        let valor = app.elemento("valorActual")
        app.tocar(app.tabBars.buttons["Inicio"], hastaVer: valor, "Inicio no enseña la lectura")
        XCTAssertTrue(valor.label.contains("Sin sensor"), valor.label)
        XCTAssertEqual(app.state, .runningForeground)
    }

    /// Casilla 21. Con sensor en el perfil y sin datos frescos, sale la franja que lo dice,
    /// con la hora y no con un «error de conexión», y su botón se puede tocar.
    func testConElSensorCalladoSaleLaFranja() throws {
        try XCTSkipUnless(
            Entorno.esta("GLUCY_SENSOR_CALLADO"),
            "Con sensor en el perfil y la app del sensor cerrada más de 15 min, corre con GLUCY_SENSOR_CALLADO=1"
        )

        let app = XCUIApplication.recienInstalada()
        try XCTSkipUnless(
            app.completarAltaConSensor(),
            "Salud no dejó pedir el permiso de lectura: el alta siguió sin sensor y no hay sensor que esté callado"
        )

        // El primer día, sin ninguna lectura, Inicio enseña solo el aviso y la invitación a
        // registrar, y la franja no sale. Con una lectura a mano ya se dibuja la pantalla
        // completa, y un pinchazo no cuenta como dato del sensor.
        app.anotarGlucosa("109")
        app.tocar(app.tabBars.buttons["Inicio"], hastaVer: app.elemento("valorActual"), "Inicio no enseña la lectura")

        let franja = app.elemento("textoSinDatosDelSensor")
        try XCTSkipUnless(
            franja.waitForExistence(timeout: 20),
            "No salió la franja: el sensor escribió hace menos de 15 minutos, así que no está callado"
        )
        XCTAssertFalse(franja.label.localizedCaseInsensitiveContains("conexión"), franja.label)
        XCTAssertFalse(franja.label.localizedCaseInsensitiveContains("error"), franja.label)
        XCTAssertTrue(franja.label.contains("Revisa que la app de tu sensor esté abierta."), franja.label)
        // Debajo del aviso de que sin sensor no se anticipan hipoglucemias.
        let aviso = app.elemento("avisoSinSensor")
        XCTAssertTrue(aviso.exists)
        XCTAssertLessThan(aviso.frame.minY, franja.frame.minY)
        capturar("franja-del-sensor-callado")

        let reintentar = app.buttons["botonReintentarSensor"]
        XCTAssertTrue(reintentar.isHittable, "«Reintentar» no se puede tocar")
        reintentar.tap()
        XCTAssertTrue(franja.waitForExistence(timeout: 10), "Tras reintentar, la franja se fue sin que hubiera datos nuevos")
        XCTAssertEqual(app.state, .runningForeground)
    }

    /// Casilla 20 (P-14). La serie no se duplica al reiniciar.
    ///
    /// Es la única que corre sobre **la base de verdad** del teléfono, y solo la lee: con la
    /// base en memoria cada arranque empieza vacío y no habría nada que pudiera duplicarse.
    /// Hace falta el alta hecha con sensor, lecturas del sensor en Salud y alguna escrita por
    /// Glucy.
    func testLaSerieNoSeDuplicaAlReiniciar() throws {
        try XCTSkipUnless(
            Entorno.esta("GLUCY_SALUD_CON_DATOS"),
            "Con lecturas del sensor y alguna de Glucy en Salud, corre con GLUCY_SALUD_CON_DATOS=1"
        )

        func cuantasLecturas(_ app: XCUIApplication) throws -> Int {
            try XCTSkipUnless(
                app.tabBars.buttons["Historial"].waitForExistence(timeout: 15),
                "La app no está en las pestañas: hace falta el alta hecha y el candado apagado"
            )
            app.tabBars.buttons["Historial"].tap()
            app.tocar(app.buttons["periodo30"], hastaVer: app.buttons["periodo30"], "No apareció el periodo")
            let promedio = app.elemento("cifraPromedio")
            try XCTSkipUnless(
                promedio.waitForExistence(timeout: 10),
                "Historial no enseña cifras: hacen falta lecturas de al menos tres días"
            )
            // «Promedio: 142 miligramos por decilitro. sobre 94 mediciones»
            let palabras = promedio.label.components(separatedBy: " ")
            let despuesDeSobre = palabras.firstIndex(of: "sobre").map { palabras[$0 + 1] } ?? ""
            return try XCTUnwrap(Int(despuesDeSobre), "No pude leer cuántas mediciones: \(promedio.label)")
        }

        let app = XCUIApplication()
        app.terminate()
        app.launch()
        // Se le da tiempo a traer lo que haya nuevo en Salud antes de contar.
        sleep(8)
        let antes = try cuantasLecturas(app)

        app.terminate()
        app.launch()
        sleep(8)
        let despues = try cuantasLecturas(app)

        // Un sensor escribe cada cinco minutos: entre un arranque y otro puede entrar una
        // lectura nueva, o dos. Si la serie se duplicara, entrarían todas otra vez.
        XCTAssertGreaterThanOrEqual(despues, antes, "Se perdieron lecturas al reiniciar")
        XCTAssertLessThanOrEqual(
            despues - antes, 2,
            "Había \(antes) lecturas y tras reiniciar hay \(despues): la serie se duplicó"
        )
    }
}
