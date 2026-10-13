import Foundation
import Testing
@testable import Glucy

/// Los carbohidratos que siguen absorbiéndose, con las comidas que la persona registró. La
/// curva es la de `cob_total` en `referencia/reglas_clinicas.py`: lineal, sin modelar la
/// digestión (D-8, RF-24b).
struct CalcularCarbohidratosActivosTests {

    private let ahora = Date(timeIntervalSince1970: 1_758_240_000)

    private func comida(_ carbsG: Double, haceMin minutos: Double, absorcionMin: Int = 180) -> ComidaDato {
        ComidaDato(
            tsUtc: ahora.addingTimeInterval(-minutos * 60),
            carbsG: carbsG,
            tiempoAbsorcionMin: absorcionMin,
            origen: .manual
        )
    }

    private func repositorio(con comidas: [ComidaDato]) async throws -> RepositorioComidasFalso {
        let repositorio = RepositorioComidasFalso()
        for c in comidas { try await repositorio.guardar(c) }
        return repositorio
    }

    @Test("9 · P-11: 60 g con absorción de 180 min, a los 90 min, son 30 g")
    func elCasoDeSiempre() async throws {
        let comidas = try await repositorio(con: [comida(60, haceMin: 90)])
        let activos = try await CalcularCarbohidratosActivos(comidas: comidas).ejecutar(ahora: ahora)
        #expect(activos == 30)
    }

    @Test("10 · RF-24b: una comida lenta sigue contando a las cuatro horas; se pide la ventana larga")
    func sePideLaVentanaLarga() async throws {
        // Absorción de 300 min, hace 240: queda la quinta parte. Pidiendo solo las tres
        // horas de la absorción por omisión, esta comida ni siquiera llegaría al cálculo.
        let comidas = try await repositorio(con: [comida(50, haceMin: 240, absorcionMin: 300)])
        let activos = try await CalcularCarbohidratosActivos(comidas: comidas).ejecutar(ahora: ahora)

        #expect(await comidas.horasPedidas == [5])
        #expect(abs(activos - 10) < 1e-9)

        // Y cada comida con su propio tiempo: la misma, con 180 min, ya se absorbió.
        let rapida = try await repositorio(con: [comida(50, haceMin: 240, absorcionMin: 180)])
        #expect(try await CalcularCarbohidratosActivos(comidas: rapida).ejecutar(ahora: ahora) == 0)
    }

    @Test("11 · RF-37: sin comidas registradas da cero y no lanza")
    func elPrimerDia() async throws {
        let comidas = RepositorioComidasFalso()
        let activos = try await CalcularCarbohidratosActivos(comidas: comidas).ejecutar(ahora: ahora)
        #expect(activos == 0)
        #expect(await comidas.vecesGuardado == 0)
    }
}
