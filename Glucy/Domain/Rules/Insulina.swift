import Foundation

/// Insulina activa (IOB).
///
/// Nada de aquí calcula ni sugiere una dosis (regla 7). Estas funciones responden
/// «cuánta insulina de la que ya te aplicaste sigue trabajando», que es información, no
/// una instrucción de tratamiento.
nonisolated enum Insulina {

    /// Fracción de una dosis que sigue activa a los `minutos` indicados.
    ///
    /// Curva exponencial de los sistemas de lazo cerrado de código abierto, con pico
    /// ~75 min y duración de acción de 5 h por omisión. El perfil puede mover la duración
    /// entre 2 y 8 h: sin ese campo la insulina activa se calcularía con una curva
    /// equivocada.
    ///
    /// Antes de aplicarse la fracción es 1; pasada la duración de acción es 0.
    static func fraccionActiva(
        minutos: Double,
        diaH: Double = ConfiguracionDominio.duracionAccionPorOmisionH,
        picoMin: Double = ConfiguracionDominio.picoInsulinaMin
    ) -> Double {
        let diaMin = diaH * 60
        if minutos <= 0 { return 1.0 }
        if minutos >= diaMin { return 0.0 }

        let tau = picoMin * (1 - picoMin / diaMin) / (1 - 2 * picoMin / diaMin)
        let a = 2 * tau / diaMin
        let s = 1 / (1 - a + (1 + a) * exp(-diaMin / tau))
        let factor = minutos * minutos / (tau * diaMin * (1 - a)) - minutos / tau - 1
        let restante = 1 - s * (1 - a) * (factor * exp(-minutos / tau) + 1)
        return min(1.0, max(0.0, restante))
    }

    /// Insulina activa total. Cada elemento es una dosis con sus minutos transcurridos.
    ///
    /// Solo cuenta la insulina de bolo: la basal no se acumula como insulina activa en
    /// este modelo, y la basal temporal no se modela porque no hay bomba en el alcance.
    /// Quien llame a esta función filtra los boles antes.
    static func iob(
        dosis: [(unidades: Double, minutos: Double)],
        diaH: Double = ConfiguracionDominio.duracionAccionPorOmisionH,
        picoMin: Double = ConfiguracionDominio.picoInsulinaMin
    ) -> Double {
        dosis.reduce(0) { total, d in
            total + d.unidades * fraccionActiva(minutos: d.minutos, diaH: diaH, picoMin: picoMin)
        }
    }
}
