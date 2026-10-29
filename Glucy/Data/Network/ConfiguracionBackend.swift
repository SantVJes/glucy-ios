import Foundation

/// Dónde vive el backend y si la sincronización está encendida.
///
/// **Sin URL no hay sincronización, y la app funciona igual**: la fase 1 completa corre sin
/// servidor y así va a seguir (regla 1). Por eso el valor por omisión es «apagado» y no una
/// dirección de ejemplo que fallaría en silencio contra un servidor que no existe.
///
/// Aquí no hay ninguna llave ni token: el token vive en el Keychain (`Llavero`). Lo único
/// que guarda esta estructura es una dirección y un tope, que no son secretos.
nonisolated struct ConfiguracionBackend: Sendable, Equatable {

    /// La raíz de la API, sin diagonal final. `nil` es «no hay backend configurado».
    let url: URL?

    /// Cuántos renglones van en un lote. El servidor acepta hasta 500 por petición
    /// (`MAX_RENGLONES_POR_LOTE`), así que 500 es el tope y no una elección libre.
    let renglonesPorLote: Int

    /// Cuánto se espera una respuesta antes de dejar el lote en la cola para la siguiente
    /// ventana de wifi. Subir no es una función de emergencia: más vale rendirse pronto que
    /// tener la app esperando.
    let timeoutSegundos: TimeInterval

    static let maximoRenglonesPorLote = 500

    init(url: URL? = nil, renglonesPorLote: Int = 500, timeoutSegundos: TimeInterval = 30) {
        self.url = url
        self.renglonesPorLote = min(max(1, renglonesPorLote), Self.maximoRenglonesPorLote)
        self.timeoutSegundos = timeoutSegundos
    }

    /// Lee la dirección de `Info.plist`, clave `GlucyBackendURL`.
    ///
    /// Va en el `Info.plist` y no en el código porque cambia entre el servidor de casa y el
    /// de la entrega, y porque una dirección no es un secreto. Si la clave no está o no es
    /// una URL válida, la sincronización se queda apagada en lugar de adivinar.
    static func desdeBundle(_ bundle: Bundle = .main) -> ConfiguracionBackend {
        guard
            let texto = bundle.object(forInfoDictionaryKey: "GlucyBackendURL") as? String,
            !texto.isEmpty,
            let url = URL(string: texto),
            url.scheme == "https" || url.scheme == "http"
        else {
            return ConfiguracionBackend()
        }
        return ConfiguracionBackend(url: url)
    }

    var estaConfigurado: Bool { url != nil }
}
