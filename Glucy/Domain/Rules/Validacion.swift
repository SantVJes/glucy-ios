import Foundation

/// Motivo por el que una lectura no se guarda.
///
/// Un rechazo nunca es un descarte silencioso: lleva su motivo para poder decirlo en
/// pantalla y para que el dato quede en cuarentena en lugar de desaparecer.
nonisolated enum Rechazo: Equatable, Sendable {
    case fueraDeRango(valor: Double)
    case marcaDeTiempoFutura
    case ocrSinConfirmar
    case duplicado(uuid: UUID)
}

/// Validación de lo que entra al teléfono. El backend la repite en la fase 2: un servidor
/// nunca debe confiar en lo que le mandan.
nonisolated enum Validacion {

    /// Devuelve `nil` si la lectura se puede guardar, o el motivo del rechazo.
    ///
    /// Un valor leído por OCR sin confirmar **no se guarda nunca**, sin umbral de
    /// confianza (D-11, caso P-01): el orden importa, la confirmación se revisa antes que
    /// el rango, porque un OCR sin confirmar no se guarda ni aunque el número sea válido.
    static func validarLectura(
        mgDl: Double,
        tsUtc: Date,
        ahora: Date,
        origen: Origen,
        confirmadaPorUsuario: Bool = true
    ) -> Rechazo? {
        if origen == .fotoGlucometro && !confirmadaPorUsuario {
            return .ocrSinConfirmar
        }
        guard (ConfiguracionDominio.glucosaMinima...ConfiguracionDominio.glucosaMaxima)
            .contains(mgDl) else {
            return .fueraDeRango(valor: mgDl)
        }
        // Una marca futura corrompe el orden de la serie, y con él la tasa de cambio y la
        // decisión de modo.
        if tsUtc > ahora {
            return .marcaDeTiempoFutura
        }
        return nil
    }

    /// Tasa de cambio imposible: más de 4 mg/dL por minuto sostenido.
    ///
    /// Solo tiene sentido sobre la serie continua del sensor: entre dos pinchazos
    /// separados por horas cualquier tasa es posible, y marcar eso como atípico sería un
    /// falso positivo.
    static func esAtipicaPorTasa(
        mgDlPrevio: Double, tsPrevio: Date,
        mgDl: Double, ts: Date,
        origen: Origen
    ) -> Bool {
        guard origen == .sensor else { return false }
        let minutos = ts.timeIntervalSince(tsPrevio) / 60
        guard minutos > 0 else { return false }
        return abs(mgDl - mgDlPrevio) / minutos > ConfiguracionDominio.tasaCambioImposible
    }

    /// Interpolar huecos de hasta 15 min, y solo en la serie continua (RF-23).
    /// Interpolar entre dos lecturas manuales sería inventar datos.
    static func sePuedeInterpolar(huecoMin: Double, origen: Origen) -> Bool {
        origen == .sensor
            && huecoMin > 0
            && huecoMin <= ConfiguracionDominio.interpolacionMaximaMin
    }
}
