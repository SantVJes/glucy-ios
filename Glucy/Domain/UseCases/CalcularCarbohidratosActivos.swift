import Foundation

/// Los carbohidratos que todavía se están absorbiendo, ahora mismo.
///
/// La curva ya está escrita y probada en `Carbohidratos.cobTotal` desde el paso 1, con los
/// mismos números que `cob_total` de `referencia/reglas_clinicas.py`. Esto solo le da de
/// comer, y solo con lo que la persona registró: no se infiere ninguna comida (RF-37, D-9).
nonisolated struct CalcularCarbohidratosActivos: Sendable {
    let comidas: any RepositorioComidas

    /// Pide la ventana más larga que el dominio admite (`absorcionConfigurableMin`, 300 min)
    /// y no la de 180 por omisión: cada comida lleva su propio tiempo de absorción, y con
    /// 180 se quedarían fuera los carbohidratos de una comida lenta que sigue absorbiéndose.
    ///
    /// - Parameter ahora: se pasa, no se toma de `Date()` dentro, para poder probarlo.
    func ejecutar(ahora: Date) async throws -> Double {
        let recientes = try await comidas.recientes(
            horas: Double(ConfiguracionDominio.absorcionConfigurableMin.upperBound) / 60,
            hasta: ahora
        )
        return Carbohidratos.cobTotal(comidas: recientes.map { comida in
            (
                carbsG: comida.carbsG,
                minutos: ahora.timeIntervalSince(comida.tsUtc) / 60,
                // Cada comida con el tiempo que se guardó con ella (RF-24b, D-8).
                absorcionMin: comida.tiempoAbsorcionMin
            )
        })
    }
}
