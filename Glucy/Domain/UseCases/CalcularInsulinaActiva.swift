import Foundation

/// La insulina que todavía está trabajando, ahora mismo.
///
/// La curva ya está escrita y probada en `Insulina.iob` desde el paso 1, con los mismos
/// números que `referencia/reglas_clinicas.py`. Esto solo le da de comer.
///
/// Devuelve una cifra y nada más: no la compara contra nada ni dice si es mucha o poca
/// (regla 7).
nonisolated struct CalcularInsulinaActiva: Sendable {
    let dosis: any RepositorioDosis

    /// - Parameter ahora: se pasa, no se toma de `Date()` dentro, para poder probarlo.
    func ejecutar(ahora: Date) async throws -> Double {
        // Se pide la ventana más larga que el perfil admite y no la duración por omisión:
        // cada dosis lleva la suya, y con cinco horas se quedaría fuera insulina que sigue
        // activa en alguien con una duración de ocho.
        let recientes = try await dosis.recientes(
            horas: ConfiguracionDominio.duracionAccionConfigurableH.upperBound,
            hasta: ahora
        )
        return recientes
            // Solo el bolo cuenta como insulina activa en este modelo; ver `Insulina.iob`.
            .filter { $0.tipo == .bolo }
            .reduce(0) { total, d in
                // Cada dosis con la duración que tenía guardada, no con la del perfil de hoy.
                total + Insulina.iob(
                    dosis: [(unidades: d.unidades, minutos: ahora.timeIntervalSince(d.tsUtc) / 60)],
                    diaH: d.duracionAccionH
                )
            }
    }
}
