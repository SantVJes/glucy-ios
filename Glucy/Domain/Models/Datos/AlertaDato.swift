import Foundation

/// Una alerta emitida, como valor.
///
/// Guarda **el umbral que estaba vigente** cuando se emitió, y no solo el valor: quien mueve
/// su umbral de 70 a 80 cambia qué cuenta como alerta, y sin el umbral de ese momento no se
/// podría explicar después por qué se avisó de un 75 el martes y no el lunes.
///
/// Guarda también **el modo**, porque en modo sin sensor no hay alerta anticipada (RF-10b,
/// regla 8, caso P-04): sin ese campo no se podría auditar si la app prometió algo que no
/// podía cumplir.
nonisolated struct AlertaDato: Sendable, Equatable, Identifiable {
    var id: UUID { uuid }

    /// Lo genera el teléfono, nunca la base ni el servidor (RF-36c).
    let uuid: UUID
    /// Cuándo se emitió.
    let tsUtc: Date
    /// Identificador de `TimeZone` (regla 5). Siempre viaja junto al `tsUtc`.
    let zonaHoraria: String
    /// El valor que la disparó: el predicho cuando hay horizonte, el medido cuando no.
    let valorMgDl: Double
    let umbralMgDl: Double
    /// Minutos hacia adelante. `nil` cuando la alerta es sobre el valor de ahora y no sobre
    /// una predicción.
    let horizonteMin: Int?
    let modo: ModoApp
    /// Si el sistema aceptó entregarla. `false` mientras no se haya entregado, y así se
    /// distingue «no se avisó» de «se avisó y la persona no lo vio».
    let entregada: Bool
    /// Cuándo la persona la dio por vista. `nil` mientras no la reconozca.
    let reconocidaTsUtc: Date?
    /// `.local` por omisión, y a propósito: entre los siete endpoints del contrato no hay uno
    /// de alertas, así que una alerta marcada como pendiente se quedaría en la cola de subida
    /// para siempre. El día que exista `/alerts` esto cambia aquí y en `guardar`.
    let syncEstado: SyncEstado

    init(
        uuid: UUID = UUID(),
        tsUtc: Date,
        zonaHoraria: String = TimeZone.current.identifier,
        valorMgDl: Double,
        umbralMgDl: Double,
        horizonteMin: Int? = nil,
        modo: ModoApp,
        entregada: Bool = false,
        reconocidaTsUtc: Date? = nil,
        syncEstado: SyncEstado = .local
    ) {
        self.uuid = uuid
        self.tsUtc = tsUtc
        self.zonaHoraria = zonaHoraria
        self.valorMgDl = valorMgDl
        self.umbralMgDl = umbralMgDl
        self.horizonteMin = horizonteMin
        self.modo = modo
        self.entregada = entregada
        self.reconocidaTsUtc = reconocidaTsUtc
        self.syncEstado = syncEstado
    }

    /// Hacia dónde avisó. Se deriva de comparar el valor con el umbral, igual que la alerta
    /// se deriva de la predicción (RF-26): el modelo predice un número, no una clase.
    var esBaja: Bool { valorMgDl < umbralMgDl }
}
