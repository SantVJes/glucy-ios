import Testing
@testable import Glucy

/// Cuándo se vacía la cola hacia el backend (RF-35, RF-36).
struct DecisionSincronizacionTests {

    /// P-08. Con datos móviles no sincroniza salvo que la persona toque «sincronizar
    /// ahora».
    @Test("P-08: no sincroniza con datos móviles salvo por botón manual")
    func P08_noSincronizaConDatosMoviles() {
        #expect(DecisionSincronizacion.debeSincronizar(hayWifi: false, pendientes: 12) == false)
        #expect(DecisionSincronizacion.debeSincronizar(
            hayWifi: false, pendientes: 12, forzadoPorUsuario: true
        ))
    }

    @Test("Con wifi y cola pendiente, sincroniza")
    func conWifiYPendientesSincroniza() {
        #expect(DecisionSincronizacion.debeSincronizar(hayWifi: true, pendientes: 1))
    }

    /// P-07. En modo avión todo sigue funcionando y lo capturado espera en la cola; sin
    /// nada pendiente no se gasta batería en abrir una conexión.
    @Test("Sin nada pendiente no se sincroniza, ni con wifi ni a mano")
    func sinPendientesNoSincroniza() {
        #expect(DecisionSincronizacion.debeSincronizar(hayWifi: true, pendientes: 0) == false)
        #expect(DecisionSincronizacion.debeSincronizar(
            hayWifi: true, pendientes: 0, forzadoPorUsuario: true
        ) == false)
    }
}
