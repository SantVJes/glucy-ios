import Foundation
import SwiftData

/// La última predicción calculada, guardada para que la pantalla de inicio pueda pintarse
/// al instante y sin red.
///
/// Es caché: nace `local` y no viaja. La predicción que le importa al backend es la que él
/// mismo genera; subir de vuelta la suya sería un viaje redondo sin valor.
@Model
nonisolated final class PrediccionCache {
    /// Lo genera el teléfono, nunca la base ni el servidor.
    @Attribute(.unique) var uuid: UUID

    /// Cuándo se calculó, no para cuándo es.
    var tsUtc: Date
    /// Identificador de `TimeZone`, por ejemplo `America/Mexico_City` (regla 5).
    var zonaHoraria: String

    /// 30 o 60 minutos.
    var horizonteMin: Int
    var valorMgDl: Double

    /// Modo en el que se calculó. Una predicción hecha en modo sin sensor no vale lo mismo
    /// que una hecha con serie continua, y la pantalla lo dice.
    var modo: ModoApp

    var versionModelo: String

    /// Explicación en español llano ya resuelta. Si el modelo de lenguaje no contestó, es
    /// la de la plantilla determinista; en ningún caso contiene una indicación de
    /// tratamiento (regla 7).
    var explicacion: String?

    /// Contribuciones SHAP serializadas, para poder repintar la explicación sin recalcular.
    var shapJson: String?

    var syncEstado: SyncEstado

    init(
        uuid: UUID = UUID(),
        tsUtc: Date,
        zonaHoraria: String = TimeZone.current.identifier,
        horizonteMin: Int,
        valorMgDl: Double,
        modo: ModoApp,
        versionModelo: String,
        explicacion: String? = nil,
        shapJson: String? = nil,
        syncEstado: SyncEstado = .local
    ) {
        self.uuid = uuid
        self.tsUtc = tsUtc
        self.zonaHoraria = zonaHoraria
        self.horizonteMin = horizonteMin
        self.valorMgDl = valorMgDl
        self.modo = modo
        self.versionModelo = versionModelo
        self.explicacion = explicacion
        self.shapJson = shapJson
        self.syncEstado = syncEstado
    }
}
