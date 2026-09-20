import Foundation

/// Carbohidratos activos (COB).
nonisolated enum Carbohidratos {

    /// Carbohidratos que siguen activos de una comida.
    ///
    /// Absorción lineal, sin modelo fisiológico de digestión (D-8, RF-24b):
    /// `COB(t) = carbs × (1 − t / absorción)`, y 0 cuando `t ≥ absorción`.
    ///
    /// Es una simplificación consciente: la alternativa exige datos que la persona no
    /// captura y una validación clínica que este proyecto no puede hacer.
    ///
    /// Caso P-11: 60 g con 180 min, a los 90 min → 30 g exactos.
    ///
    /// - Parameter minutosDesdeComida: negativo no tiene sentido; se trata como la comida
    ///   completa todavía activa, igual que en el instante cero.
    static func cob(
        carbsG: Double,
        minutosDesdeComida: Double,
        tiempoAbsorcionMin: Int = ConfiguracionDominio.absorcionPorOmisionMin
    ) -> Double {
        guard tiempoAbsorcionMin > 0 else { return 0 }
        guard minutosDesdeComida > 0 else { return carbsG }
        guard minutosDesdeComida < Double(tiempoAbsorcionMin) else { return 0 }
        return carbsG * (1 - minutosDesdeComida / Double(tiempoAbsorcionMin))
    }

    /// Suma el COB de varias comidas, cada una con su propio tiempo de absorción.
    ///
    /// No se infiere ninguna comida que la persona no haya registrado (D-9, RF-37): esta
    /// función solo suma lo que se le da.
    static func cobTotal(comidas: [(carbsG: Double, minutos: Double, absorcionMin: Int)]) -> Double {
        comidas.reduce(0) { total, comida in
            total + cob(
                carbsG: comida.carbsG,
                minutosDesdeComida: comida.minutos,
                tiempoAbsorcionMin: comida.absorcionMin
            )
        }
    }
}
