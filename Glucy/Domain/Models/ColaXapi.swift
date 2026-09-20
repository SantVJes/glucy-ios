import Foundation
import SwiftData

/// Una sentencia xAPI de autocuidado esperando al Learning Record Store (fase 6).
///
/// Cola aparte de `ColaSincronizacion` porque va a otro destino, con otro formato y otra
/// cadencia: mezclarlas obligaría a que un fallo del LRS frenara los datos clínicos.
@Model
nonisolated final class ColaXapi {
    /// Lo genera el teléfono, nunca la base ni el servidor.
    @Attribute(.unique) var uuid: UUID

    /// Las tres partes de la sentencia, legibles sin abrir el JSON.
    var verbo: String
    var objeto: String

    /// La sentencia completa, ya serializada. Se arma cuando ocurre el hecho, no cuando se
    /// envía: reconstruirla meses después daría otro resultado.
    var sentenciaJson: String

    var tsUtc: Date
    /// Identificador de `TimeZone`, por ejemplo `America/Mexico_City` (regla 5).
    var zonaHoraria: String

    var intentos: Int
    var ultimoIntentoTsUtc: Date?
    var ultimoError: String?

    var estado: SyncEstado

    init(
        uuid: UUID = UUID(),
        verbo: String,
        objeto: String,
        sentenciaJson: String,
        tsUtc: Date = Date(),
        zonaHoraria: String = TimeZone.current.identifier,
        intentos: Int = 0,
        ultimoIntentoTsUtc: Date? = nil,
        ultimoError: String? = nil,
        estado: SyncEstado = .pendiente
    ) {
        self.uuid = uuid
        self.verbo = verbo
        self.objeto = objeto
        self.sentenciaJson = sentenciaJson
        self.tsUtc = tsUtc
        self.zonaHoraria = zonaHoraria
        self.intentos = intentos
        self.ultimoIntentoTsUtc = ultimoIntentoTsUtc
        self.ultimoError = ultimoError
        self.estado = estado
    }
}
