import Foundation

/// Una lectura de glucosa como valor, no como fila.
///
/// Los objetos `@Model` de SwiftData no son `Sendable` y no pueden cruzar de un actor a
/// otro. Los repositorios son actores, así que lo que entra y sale de ellos son structs
/// como este; el `@Model` nunca se asoma fuera de `Data/`.
///
/// Sin esta separación toda escritura tendría que ocurrir en el hilo principal, y en el
/// paso 4 la entrega en segundo plano de HealthKit no podría guardar nada.
nonisolated struct LecturaGlucosaDato: Sendable, Equatable, Identifiable {
    var id: UUID { uuid }

    /// Lo genera el teléfono, nunca la base ni el servidor (RF-36c).
    let uuid: UUID
    let mgDl: Double
    let tsUtc: Date
    /// Identificador de `TimeZone` (regla 5). Siempre viaja junto al `tsUtc`.
    let zonaHoraria: String
    let origen: Origen
    let contexto: ContextoComida?
    let confirmadaPorUsuario: Bool
    let atipica: Bool
    let escritaEnHealthKit: Bool
    /// No sube al backend (regla 3).
    let nota: String?

    /// Lo que el OCR propuso, antes de que la persona lo tocara (RF-05b). `nil` si la
    /// lectura no vino de una foto.
    let valorLeidoOcr: Double?
    /// Si el valor guardado no es el que propuso el OCR.
    let fueCorregido: Bool
    /// De 0 a 1, tal como lo reportó el OCR. **No decide nada** (D-11).
    let confianzaOcr: Double?

    let syncEstado: SyncEstado

    init(
        uuid: UUID = UUID(),
        mgDl: Double,
        tsUtc: Date,
        zonaHoraria: String = TimeZone.current.identifier,
        origen: Origen,
        contexto: ContextoComida? = nil,
        confirmadaPorUsuario: Bool = true,
        atipica: Bool = false,
        escritaEnHealthKit: Bool = false,
        nota: String? = nil,
        valorLeidoOcr: Double? = nil,
        fueCorregido: Bool = false,
        confianzaOcr: Double? = nil,
        syncEstado: SyncEstado = .pendiente
    ) {
        self.uuid = uuid
        self.mgDl = mgDl
        self.tsUtc = tsUtc
        self.zonaHoraria = zonaHoraria
        self.origen = origen
        self.contexto = contexto
        self.confirmadaPorUsuario = confirmadaPorUsuario
        self.atipica = atipica
        self.escritaEnHealthKit = escritaEnHealthKit
        self.nota = nota
        self.valorLeidoOcr = valorLeidoOcr
        self.fueCorregido = fueCorregido
        self.confianzaOcr = confianzaOcr
        self.syncEstado = syncEstado
    }
}
