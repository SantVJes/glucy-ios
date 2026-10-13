import Foundation

/// Dónde queda el ancla de la consulta de glucosa entre un arranque y otro.
///
/// Es un archivo propio en la carpeta de soporte de la app, junto a la base. Si se pierde,
/// la siguiente consulta trae todo otra vez y la idempotencia del repositorio evita los
/// duplicados.
///
/// Guarda bytes y no un `HKQueryAnchor` para no importar HealthKit: así el caso de uso y las
/// pruebas la usan sin Salud. Serializar y deserializar es cosa de `HealthKitReal`.
nonisolated struct AnclaHealthKit: Sendable {
    /// `nil` es el de la app. Las pruebas pasan un dominio propio para no tocar el de la
    /// app ni el de otra prueba.
    let dominio: String?
    let clave: String

    init(dominio: String? = nil, clave: String = "glucy.healthkit.anclaGlucosa") {
        self.dominio = dominio
        self.clave = clave
    }

    func leer() -> Data? {
        try? Data(contentsOf: archivo)
    }

    func guardar(_ ancla: Data?) {
        guard let ancla else {
            borrar()
            return
        }
        try? FileManager.default.createDirectory(at: carpeta, withIntermediateDirectories: true)
        // Sin protección «completa», igual que la base: la entrega en segundo plano de
        // HealthKit llega con el teléfono bloqueado y tiene que poder avanzar el ancla.
        try? ancla.write(to: archivo, options: .atomic)
    }

    /// Olvida hasta dónde se había leído. Lo usa el borrado de la cuenta: sin esto, quien
    /// vuelva a dar de alta su sensor no recibiría de nuevo su historial.
    func borrar() {
        try? FileManager.default.removeItem(at: archivo)
    }

    private var carpeta: URL {
        URL.applicationSupportDirectory.appendingPathComponent("Glucy", isDirectory: true)
    }

    private var archivo: URL {
        carpeta.appendingPathComponent("\(dominio.map { "\($0)." } ?? "")\(clave).ancla")
    }
}
