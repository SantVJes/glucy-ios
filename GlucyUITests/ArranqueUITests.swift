import XCTest

/// El arranque en frío: menos de dos segundos hasta ver el valor actual.
///
/// **Se corre a mano en el iPhone, no en la integración continua.** Un simulador en un runner
/// compartido da números que no significan nada, y una prueba de rendimiento que falla al
/// azar se acaba desactivando y con ella se van las que sí servían.
///
/// Usa la base de verdad del teléfono, sin tocarla: hace falta haber pasado por el alta,
/// tener al menos una lectura y el candado apagado.
final class ArranqueUITests: XCTestCase {

    private static let presupuestoS = 2.0

    /// Prueba 18 del paso 10.
    func testElArranqueEnFrioDejaVerElValorEnMenosDeDosSegundos() throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("El arranque en frío se mide en el iPhone físico, no en el simulador.")
        #else
        let app = XCUIApplication()
        app.launchArguments.append("-GlucyMedirArranque")
        app.terminate()
        app.launch()

        let valor = app.descendants(matching: .any)["valorActual"]
        guard valor.waitForExistence(timeout: 15) else {
            throw XCTSkip(
                "No hay valor que medir: hace falta el alta hecha, al menos una lectura y el candado apagado."
            )
        }
        // El número lo toma la propia app, desde que el sistema creó el proceso hasta que
        // tuvo el valor listo. Desde aquí no se puede medir: la automatización de la prueba
        // tarda varios segundos en arrancar y esos no son de la app.
        let segundos = try XCTUnwrap(
            Double(valor.value as? String ?? ""), "La app no anotó cuánto tardó el arranque"
        )

        let nota = XCTAttachment(string: String(format: "Arranque en frío: %.3f s hasta el valor", segundos))
        nota.lifetime = .keepAlways
        add(nota)
        print(String(format: "Arranque en frío: %.3f s hasta el valor actual", segundos))

        XCTAssertLessThan(
            segundos, Self.presupuestoS,
            "El valor tardó \(segundos) s. Lo primero que se baja es splashMinimoS, no la migración ni lo que se lee."
        )
        #endif
    }
}
