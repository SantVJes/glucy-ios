import Foundation

/// La cola de lo que espera turno para subir al backend.
///
/// En el paso 2 la cola **se llena y no se vacía**: no hay servidor hasta la fase 2. La
/// regla de cuándo vaciarla ya existe desde el paso 1, en
/// `DecisionSincronizacion.debeSincronizar` (RF-20).
nonisolated protocol RepositorioCola: Sendable {
    /// Encola un registro. Si ese UUID ya estaba en la cola no lo mete dos veces.
    @discardableResult
    func encolar(tipo: String, uuidRegistro: UUID) async throws -> Bool

    /// Lo más antiguo primero, hasta `limite`. La cola se vacía en el orden en que se
    /// llenó, o el backend reconstruiría la serie desordenada.
    func pendientes(limite: Int) async throws -> [PendienteDato]

    /// - Parameter uuid: el de **la fila de la cola**, el que trae `PendienteDato.uuid`,
    ///   no el del registro que espera.
    func marcarEnviado(uuid: UUID) async throws

    /// Un fallo no se descarta en silencio: se guarda el motivo y sube el contador de
    /// intentos, **sin borrar la fila**, para poder mostrarlo y reintentar (RF-22, RF-36b).
    func marcarError(uuid: UUID, motivo: String) async throws

    func contarPendientes() async throws -> Int
}

/// Los nombres de tipo que viajan en la cola. En un solo lugar porque el backend de la
/// fase 2 los va a leer tal cual: una errata aquí se convierte en un registro que nunca se
/// reconoce del otro lado.
nonisolated enum TipoRegistro {
    static let lecturaGlucosa = "lectura_glucosa"
    static let comida = "comida"
    static let dosisInsulina = "dosis_insulina"
    static let eventoContexto = "evento_contexto"
    static let alerta = "alerta"
}
