import Foundation

/// Una muestra de glucosa como la entrega HealthKit, ya convertida a mg/dL.
///
/// Este archivo no importa HealthKit a propósito: el protocolo y sus tipos los usan los
/// casos de uso y las pruebas, y la integración continua no tiene Salud. Solo
/// `HealthKitReal` habla con el framework.
nonisolated struct MuestraGlucosa: Sendable, Equatable {
    /// El de HealthKit, que es estable entre consultas. Se usa como UUID de la lectura, y
    /// así una muestra reentregada choca con la idempotencia del repositorio (RF-36c).
    let uuid: UUID
    let mgDl: Double
    let ts: Date
    /// La de `HKMetadataKeyTimeZone` si el fabricante la puso; si no, la del teléfono.
    let zonaHoraria: String?
    let contexto: ContextoComida?
    /// `true` si la escribió Glucy. Las propias **no** se vuelven a guardar ni a escribir.
    let esPropia: Bool

    /// La conversión ocurre aquí, al entrar, y no más adelante: lo que sale de este init ya
    /// está en mg/dL y nada de lo que viene después tiene que preguntar la unidad.
    init(
        uuid: UUID,
        valor: Double,
        unidad: UnidadGlucosa = .mgDl,
        ts: Date,
        zonaHoraria: String? = nil,
        contexto: ContextoComida? = nil,
        esPropia: Bool = false
    ) {
        self.uuid = uuid
        self.mgDl = unidad.aMgDl(valor)
        self.ts = ts
        self.zonaHoraria = zonaHoraria
        self.contexto = contexto
        self.esPropia = esPropia
    }
}

/// Lo que trae una consulta ancorada: las muestras y el ancla con la que se pide lo que
/// siga.
///
/// El ancla no la guarda el servicio sino el caso de uso, y **después** de guardar las
/// muestras. Si el servicio la guardara al consultar y el guardado local fallara, esas
/// muestras quedarían detrás del ancla y no volverían a llegar nunca.
nonisolated struct LoteMuestras: Sendable, Equatable {
    let muestras: [MuestraGlucosa]
    /// Serializada. `nil` si HealthKit no devolvió ninguna.
    let ancla: Data?
    /// Hay más muestras detrás de este lote. La primera consulta, sin ancla, puede traer
    /// años de sensor; se pide por lotes para no cargarlos todos en memoria.
    let hayMas: Bool
}

/// La frontera con Salud. Todo lo de HealthKit pasa por aquí (D-2.1 del paso 4).
nonisolated protocol ServicioHealthKit: Sendable {
    /// `false` en un dispositivo sin Salud, como el iPad. No es un error: es modo sin
    /// sensor.
    var disponible: Bool { get }

    /// Pide los permisos por tipo y por separado. No devuelve si los dieron: para lectura
    /// iOS no lo dice, a propósito, porque saberlo ya sería un dato de salud.
    func pedirPermisos() async throws

    /// Trae lo nuevo desde `ancla`, o todo si es `nil`, en un lote de tamaño acotado.
    func muestrasNuevas(desde ancla: Data?) async throws -> LoteMuestras

    /// Registra el observador y enciende la entrega en segundo plano. El observador solo
    /// avisa; quien trae los datos es `muestrasNuevas(desde:)`.
    func observarGlucosa(alLlegarMuestras: @escaping @Sendable () async -> Void) async throws

    /// Escribe una lectura que **Glucy** capturó. Nunca una de origen sensor (RF-15b): esa
    /// guarda vive en `EscribirEnHealthKit`, en un solo lugar.
    func escribirGlucosa(_ dato: LecturaGlucosaDato) async throws

    /// Borra de Salud la lectura que Glucy escribió con ese UUID, y solo esa. Existe por el
    /// «Deshacer» de la pantalla de registro.
    func eliminarGlucosa(uuid: UUID) async throws

    func escribirCarbohidratos(gramos: Double, ts: Date) async throws

    /// Bolo o basal viaja como `HKMetadataKeyInsulinDeliveryReason`. Lo decide el tipo de
    /// insulina y no el motivo: una dosis programada puede ser de rápida.
    func escribirInsulina(unidades: Double, ts: Date, tipo: TipoInsulina) async throws

    /// La unidad que la persona eligió en Salud. Solo para avisarle si no es mg/dL.
    func unidadPreferida() async throws -> UnidadGlucosa
}
