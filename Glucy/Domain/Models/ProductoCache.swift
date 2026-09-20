import Foundation
import SwiftData

/// Lo que Open Food Facts contestó para un código de barras.
///
/// Se guarda para no repetir la consulta: el límite es de 15 por minuto y por IP, y la
/// consulta sale del teléfono, nunca del servidor en nombre de todos. Nace `local` y no
/// sube: es caché de un tercero, no dato de la persona (grupo C).
///
/// La fuente se atribuye en la pantalla que la usa (ODbL).
@Model
nonisolated final class ProductoCache {
    /// Aquí la clave natural es el código, no un UUID: dos consultas del mismo producto
    /// tienen que caer en la misma fila.
    @Attribute(.unique) var codigoBarras: String

    var nombre: String
    var marca: String?

    /// Carbohidratos por 100 g, tal como los publica la fuente.
    var carbsPor100g: Double

    var porcionSugeridaG: Double?

    /// De dónde salió el dato, para poder atribuirlo y para saber qué caducar.
    var fuente: String

    var consultadoTsUtc: Date
    /// Identificador de `TimeZone`, por ejemplo `America/Mexico_City` (regla 5).
    var zonaHoraria: String

    /// Nace `local` y se queda ahí: es caché de un tercero, no dato de la persona, y no
    /// tiene por qué subir. Está escrito y no dado por hecho para que se pueda comprobar.
    var syncEstado: SyncEstado

    init(
        codigoBarras: String,
        nombre: String,
        marca: String? = nil,
        carbsPor100g: Double,
        porcionSugeridaG: Double? = nil,
        fuente: String = "Open Food Facts",
        consultadoTsUtc: Date = Date(),
        zonaHoraria: String = TimeZone.current.identifier,
        syncEstado: SyncEstado = .local
    ) {
        self.codigoBarras = codigoBarras
        self.nombre = nombre
        self.marca = marca
        self.carbsPor100g = carbsPor100g
        self.porcionSugeridaG = porcionSugeridaG
        self.fuente = fuente
        self.consultadoTsUtc = consultadoTsUtc
        self.zonaHoraria = zonaHoraria
        self.syncEstado = syncEstado
    }
}
