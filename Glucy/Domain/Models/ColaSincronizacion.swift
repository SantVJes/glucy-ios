import Foundation
import SwiftData

/// Un registro esperando su turno para subir al backend.
///
/// Existe desde el primer día aunque no haya servidor hasta la fase 2. En modo avión todo
/// sigue funcionando y lo que se captura se queda aquí (caso P-07); con datos móviles no
/// se vacía salvo que la persona lo pida (caso P-08). Lo más antiguo primero.
@Model
nonisolated final class ColaSincronizacion {
    /// Lo genera el teléfono, nunca la base ni el servidor.
    @Attribute(.unique) var uuid: UUID

    /// Qué tipo de registro espera y cuál, por su UUID. La cola no guarda una copia del
    /// dato: el dueño del dato es la tabla original (regla 1).
    var tipoRegistro: String
    var uuidRegistro: UUID

    var creadoTsUtc: Date
    /// Identificador de `TimeZone`, por ejemplo `America/Mexico_City` (regla 5).
    var zonaHoraria: String

    var intentos: Int
    var ultimoIntentoTsUtc: Date?

    /// El error del último intento, guardado en texto. Un fallo no se descarta en
    /// silencio: se reintenta y se puede mostrar.
    var ultimoError: String?

    var estado: SyncEstado

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

// MARK: - Conversión a valor

extension ColaSincronizacion {
    convenience init(dato: PendienteDato) {
        self.init(
            uuid: dato.uuid,
            tipoRegistro: dato.tipoRegistro,
            uuidRegistro: dato.uuidRegistro,
            creadoTsUtc: dato.creadoTsUtc,
            zonaHoraria: dato.zonaHoraria,
            intentos: dato.intentos,
            ultimoIntentoTsUtc: dato.ultimoIntentoTsUtc,
            ultimoError: dato.ultimoError,
            estado: dato.estado
        )
    }

    var dato: PendienteDato {
        PendienteDato(
            uuid: uuid,
            tipoRegistro: tipoRegistro,
            uuidRegistro: uuidRegistro,
            creadoTsUtc: creadoTsUtc,
            zonaHoraria: zonaHoraria,
            intentos: intentos,
            ultimoIntentoTsUtc: ultimoIntentoTsUtc,
            ultimoError: ultimoError,
            estado: estado
        )
    }
}
