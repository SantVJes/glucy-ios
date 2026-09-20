import Foundation

/// Una comida como valor. Ver `LecturaGlucosaDato` para por qué los repositorios hablan de
/// structs y no de objetos `@Model`.
nonisolated struct ComidaDato: Sendable, Equatable, Identifiable {
    var id: UUID { uuid }

    /// Lo genera el teléfono, nunca la base ni el servidor (RF-36c).
    let uuid: UUID
    let tsUtc: Date
    /// Identificador de `TimeZone` (regla 5). Siempre viaja junto al `tsUtc`.
    let zonaHoraria: String
    let carbsG: Double
    let tiempoAbsorcionMin: Int
    let origen: Origen
    let descripcion: String?
    let codigoBarras: String?
    let nombreProducto: String?
    let porcionG: Double?
    let confirmadaPorUsuario: Bool
    let escritaEnHealthKit: Bool
    /// No sube al backend (regla 3).
    let nota: String?
    let syncEstado: SyncEstado

    init(
        uuid: UUID = UUID(),
        tsUtc: Date,
        zonaHoraria: String = TimeZone.current.identifier,
        carbsG: Double,
        tiempoAbsorcionMin: Int = ConfiguracionDominio.absorcionPorOmisionMin,
        origen: Origen,
        descripcion: String? = nil,
        codigoBarras: String? = nil,
        nombreProducto: String? = nil,
        porcionG: Double? = nil,
        confirmadaPorUsuario: Bool = true,
        escritaEnHealthKit: Bool = false,
        nota: String? = nil,
        syncEstado: SyncEstado = .pendiente
    ) {
        self.uuid = uuid
        self.tsUtc = tsUtc
        self.zonaHoraria = zonaHoraria
        self.carbsG = carbsG
        self.tiempoAbsorcionMin = tiempoAbsorcionMin
        self.origen = origen
        self.descripcion = descripcion
        self.codigoBarras = codigoBarras
        self.nombreProducto = nombreProducto
        self.porcionG = porcionG
        self.confirmadaPorUsuario = confirmadaPorUsuario
        self.escritaEnHealthKit = escritaEnHealthKit
        self.nota = nota
        self.syncEstado = syncEstado
    }
}
