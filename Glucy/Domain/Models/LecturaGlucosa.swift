import Foundation
import SwiftData

/// Una lectura de glucosa, venga del sensor, de un pinchazo capturado a mano o de la foto
/// del glucómetro.
@Model
nonisolated final class LecturaGlucosa {
    /// Lo genera el teléfono, nunca la base ni el servidor.
    @Attribute(.unique) var uuid: UUID

    /// Siempre en mg/dL: HealthKit se consulta con `preferredUnits(for:)` y se convierte
    /// al entrar, para que adentro haya una sola unidad.
    var mgDl: Double

    var tsUtc: Date
    /// Identificador de `TimeZone`, por ejemplo `America/Mexico_City` (regla 5).
    var zonaHoraria: String

    var origen: Origen
    var contexto: ContextoComida?

    /// Todo valor de OCR entra confirmado por la persona o no entra (D-11, caso P-01).
    var confirmadaPorUsuario: Bool

    /// La marcó `Validacion.esAtipicaPorTasa`. Se conserva y se señala; no se borra.
    var atipica: Bool

    /// La app escribe en HealthKit solo lo que ella capturó. Lo que vino del sensor no se
    /// reescribe, o la serie se duplica al siguiente arranque (RF-15b, caso P-14).
    var escritaEnHealthKit: Bool

    /// No sube al backend (regla 3).
    var nota: String?

    // MARK: - Lo que leyó el OCR (RF-05b)

    /// Lo que el OCR propuso, antes de que la persona lo tocara. `nil` si la lectura no
    /// vino de una foto. El dato clínico sigue siendo `mgDl`: el confirmado.
    var valorLeidoOcr: Double?

    /// Si el valor guardado no es el que propuso el OCR.
    var fueCorregido: Bool

    /// Lo que el OCR reportó, de 0 a 1. **No decide nada** (D-11): se guarda para poder
    /// evaluar después si predice bien los errores, no para elegir ni para comparar contra
    /// ningún umbral.
    var confianzaOcr: Double?

    var syncEstado: SyncEstado

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

// MARK: - Conversión a valor

extension LecturaGlucosa {
    /// La fila a partir del valor que entregó quien llama al repositorio.
    convenience init(dato: LecturaGlucosaDato) {
        self.init(
            uuid: dato.uuid,
            mgDl: dato.mgDl,
            tsUtc: dato.tsUtc,
            zonaHoraria: dato.zonaHoraria,
            origen: dato.origen,
            contexto: dato.contexto,
            confirmadaPorUsuario: dato.confirmadaPorUsuario,
            atipica: dato.atipica,
            escritaEnHealthKit: dato.escritaEnHealthKit,
            nota: dato.nota,
            valorLeidoOcr: dato.valorLeidoOcr,
            fueCorregido: dato.fueCorregido,
            confianzaOcr: dato.confianzaOcr,
            syncEstado: dato.syncEstado
        )
    }

    /// La fila como valor, que es lo único que puede salir del actor.
    var dato: LecturaGlucosaDato {
        LecturaGlucosaDato(
            uuid: uuid,
            mgDl: mgDl,
            tsUtc: tsUtc,
            zonaHoraria: zonaHoraria,
            origen: origen,
            contexto: contexto,
            confirmadaPorUsuario: confirmadaPorUsuario,
            atipica: atipica,
            escritaEnHealthKit: escritaEnHealthKit,
            nota: nota,
            valorLeidoOcr: valorLeidoOcr,
            fueCorregido: fueCorregido,
            confianzaOcr: confianzaOcr,
            syncEstado: syncEstado
        )
    }
}
