import Foundation

/// Dónde queda el ancla de la consulta de glucosa entre un arranque y otro.
///
/// Va en `UserDefaults`, y eso sí está permitido: la regla prohíbe ahí llaves y tokens, y un
/// ancla de sincronización no es ninguna de las dos. Si se pierde, la siguiente consulta
/// trae todo otra vez y la idempotencia del repositorio evita los duplicados.
///
/// Guarda bytes y no un `HKQueryAnchor` para no importar HealthKit: así el caso de uso y las
/// pruebas la usan sin Salud. Serializar y deserializar es cosa de `HealthKitReal`.
nonisolated struct AnclaHealthKit: Sendable {
    /// `nil` es `UserDefaults.standard`. Las pruebas pasan un dominio propio para no tocar
    /// el de la app.
    let dominio: String?
    let clave: String

    init(dominio: String? = nil, clave: String = "glucy.healthkit.anclaGlucosa") {
        self.dominio = dominio
        self.clave = clave
    }

    func leer() -> Data? {
        defaults.data(forKey: clave)
    }

    func guardar(_ ancla: Data?) {
        if let ancla {
            defaults.set(ancla, forKey: clave)
        } else {
            defaults.removeObject(forKey: clave)
        }
    }

    // `UserDefaults` se pide en cada llamada en lugar de guardarse: así el struct es
    // `Sendable` sin depender de cómo esté marcada la clase en cada versión del SDK.
    private var defaults: UserDefaults {
        dominio.flatMap(UserDefaults.init(suiteName:)) ?? .standard
    }
}
