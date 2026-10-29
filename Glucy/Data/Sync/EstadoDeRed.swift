import Foundation
import Network

/// Si ahora mismo hay wifi.
///
/// Detrás de un protocolo porque la regla de cuándo sincronizar (RF-35, RF-36, caso P-08) se
/// prueba sin red: `NWPathMonitor` no se puede poner en «modo avión» desde una prueba
/// unitaria, y esa es justo la condición que hay que probar.
nonisolated protocol EstadoDeRed: Sendable {
    /// `true` solo con wifi. Con datos móviles es `false` **a propósito**: la cola no se
    /// vacía con el plan de datos de nadie salvo que la persona lo pida.
    var hayWifi: Bool { get }
}

/// El estado de la red de verdad.
///
/// Un `NWPathMonitor` vivo, no una consulta puntual: el sistema no ofrece preguntar «¿hay
/// wifi?» de golpe, solo avisar de los cambios. Por eso el monitor arranca una vez y guarda
/// la última ruta que vio.
///
/// Se consulta cuando la app decide sincronizar, y la decisión se vuelve a tomar en cada
/// ventana: entre que el monitor dice «wifi» y que el lote sale pueden pasar segundos y
/// cambiar la red. Eso no se puede evitar y no hace daño: el lote fallaría y se quedaría en
/// la cola, que es exactamente lo que tenía que pasar.
final class MonitorDeRed: EstadoDeRed, @unchecked Sendable {
    private let monitor = NWPathMonitor(requiredInterfaceType: .wifi)
    private let cola = DispatchQueue(label: "mx.glucy.red")
    /// Lo protege `candado`; de ahí el `@unchecked Sendable`.
    private var wifi = false
    private let candado = NSLock()

    init() {
        monitor.pathUpdateHandler = { [weak self] ruta in
            guard let self else { return }
            candado.lock()
            wifi = ruta.status == .satisfied
            candado.unlock()
        }
        monitor.start(queue: cola)
    }

    deinit { monitor.cancel() }

    var hayWifi: Bool {
        candado.lock()
        defer { candado.unlock() }
        return wifi
    }
}
