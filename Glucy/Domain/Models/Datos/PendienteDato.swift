import Foundation

/// Una fila de la cola de sincronización, como valor.
///
/// La cola no guarda una copia del registro: guarda de qué tipo es y cuál, por su UUID. El
/// dueño del dato es la tabla original (regla 1).
nonisolated struct PendienteDato: Sendable, Equatable, Identifiable {
    var id: UUID { uuid }

    /// Identificador de **la fila de la cola**, no del registro que espera. Es el que se le
    /// pasa a `marcarEnviado` y a `marcarError`.
    let uuid: UUID
    let tipoRegistro: String
    /// El UUID del registro que espera turno, en su propia tabla.
    let uuidRegistro: UUID
    let creadoTsUtc: Date
    /// Identificador de `TimeZone` (regla 5).
    let zonaHoraria: String
    let intentos: Int
    let ultimoIntentoTsUtc: Date?
    /// El motivo del último fallo. Un dato rechazado sin rastro es una falla invisible
    /// (RF-22, RF-36b).
    let ultimoError: String?
    let estado: SyncEstado

    init(
        uuid: UUID = UUID(),
        tipoRegistro: String,
        uuidRegistro: UUID,
        creadoTsUtc: Date = Date(),
        zonaHoraria: String = TimeZone.current.identifier,
        intentos: Int = 0,
        ultimoIntentoTsUtc: Date? = nil,
        ultimoError: String? = nil,
        estado: SyncEstado = .pendiente
    ) {
        self.uuid = uuid
        self.tipoRegistro = tipoRegistro
        self.uuidRegistro = uuidRegistro
        self.creadoTsUtc = creadoTsUtc
        self.zonaHoraria = zonaHoraria
        self.intentos = intentos
        self.ultimoIntentoTsUtc = ultimoIntentoTsUtc
        self.ultimoError = ultimoError
        self.estado = estado
    }
}
