import Testing
@testable import Glucy

/// Carbohidratos activos. Los mismos números que `referencia/reglas_clinicas.py`
/// de glucy-backend.
struct CarbohidratosTests {

    /// P-11, el caso que más se cita del proyecto.
    @Test("P-11: 60 g con absorción de 180 min, a los 90 min, son 30 g")
    func P11_cob60g180minALos90min() {
        #expect(Carbohidratos.cob(carbsG: 60, minutosDesdeComida: 90, tiempoAbsorcionMin: 180) == 30)
    }

    @Test("Pasada la absorción el COB es cero, nunca negativo")
    func cobSeAgotaYNoSeVuelveNegativo() {
        #expect(Carbohidratos.cob(carbsG: 60, minutosDesdeComida: 200) == 0)
        #expect(Carbohidratos.cob(carbsG: 60, minutosDesdeComida: 180, tiempoAbsorcionMin: 180) == 0)
        #expect(Carbohidratos.cob(carbsG: 60, minutosDesdeComida: 10_000) == 0)
    }

    @Test("En el instante de la comida sigue activo todo lo que se comió")
    func cobEnCeroEsLaComidaCompleta() {
        #expect(Carbohidratos.cob(carbsG: 45, minutosDesdeComida: 0) == 45)
    }

    @Test("El preset lento de 300 min alarga la absorción")
    func cobConAbsorcionLenta() {
        // Referencia: cob(45, 30, 300) = 40.5
        let resultado = Carbohidratos.cob(carbsG: 45, minutosDesdeComida: 30, tiempoAbsorcionMin: 300)
        #expect(abs(resultado - 40.5) < 1e-9)
    }

    @Test("El COB total suma cada comida con su propio tiempo de absorción")
    func cobTotalSumaCadaComidaConSuAbsorcion() {
        // Referencia: cob_total([(60, 90, 180), (20, 15, 30)]) = 40.0
        let total = Carbohidratos.cobTotal(comidas: [
            (carbsG: 60, minutos: 90, absorcionMin: 180),
            (carbsG: 20, minutos: 15, absorcionMin: 30)
        ])
        #expect(abs(total - 40.0) < 1e-9)
    }

    @Test("Sin comidas registradas el COB es cero, y no se infiere ninguna (D-9, RF-37)")
    func cobTotalSinComidasEsCero() {
        #expect(Carbohidratos.cobTotal(comidas: []) == 0)
    }
}
