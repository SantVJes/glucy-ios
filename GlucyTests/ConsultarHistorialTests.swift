import Foundation
import Testing
@testable import Glucy

/// Cuándo se enseña cada cifra del historial. Calcularlas ya estaba probado desde el paso 1;
/// aquí se fija lo que puede engañar: enseñar un tiempo en rango de un día suelto o un GMI
/// de seis pinchazos.
struct ConsultarHistorialTests {

    /// Mediodía UTC, para que «hace N días» caiga siempre en un día distinto.
    private let ahora = Date(timeIntervalSince1970: 1_758_240_000 + 12 * 3600)

    private func lectura(_ mgDl: Double, haceDias dias: Double) -> LecturaGlucosaDato {
        LecturaGlucosaDato(
            mgDl: mgDl,
            tsUtc: ahora.addingTimeInterval(-dias * 86_400 - 60),
            zonaHoraria: "UTC",
            origen: .manual
        )
    }

    private func historial(
        _ lecturas: [LecturaGlucosaDato], periodoDias: Int = 7, perfil: PerfilDato? = nil
    ) async throws -> EstadoHistorial {
        let repositorio = RepositorioLecturasFalso()
        for l in lecturas { try await repositorio.guardar(l) }
        return try await ConsultarHistorial(
            lecturas: repositorio, perfil: RepositorioPerfilFalso(perfil)
        ).ejecutar(periodoDias: periodoDias, ahora: ahora)
    }

    @Test("12 · RF-16: con lecturas de dos días no hay indicadores, y se dice que son dos")
    func dosDiasNoBastan() async throws {
        let estado = try await historial([
            lectura(100, haceDias: 0), lectura(110, haceDias: 0.1), lectura(120, haceDias: 0.2),
            lectura(130, haceDias: 1), lectura(140, haceDias: 1.1), lectura(150, haceDias: 1.2),
        ])
        #expect(estado.indicadores == nil)
        #expect(estado.diasConLecturas == 2)
        #expect(!estado.gmiEsFiable)
        // Tampoco un día típico: describiría un día suelto.
        #expect(estado.diaTipico.isEmpty)
    }

    @Test("13 · RF-16: con lecturas de tres días hay indicadores, y el GMI todavía no es fiable")
    func tresDiasDanTiempoEnRango() async throws {
        let estado = try await historial([
            lectura(100, haceDias: 0), lectura(150, haceDias: 1), lectura(200, haceDias: 2),
        ])
        let indicadores = try #require(estado.indicadores)
        #expect(indicadores.n == 3)
        #expect(abs(indicadores.tir - 200.0 / 3) < 1e-9)
        #expect(indicadores.promedio == 150)
        #expect(estado.diasConLecturas == 3)
        #expect(!estado.gmiEsFiable)
    }

    @Test("14 · RF-16: con lecturas de catorce días el GMI ya es fiable")
    func catorceDiasDanGmi() async throws {
        let trece = (0..<13).map { lectura(154, haceDias: Double($0)) }
        #expect(try await historial(trece, periodoDias: 30).gmiEsFiable == false)

        let catorce = (0..<14).map { lectura(154, haceDias: Double($0)) }
        let estado = try await historial(catorce, periodoDias: 30)
        #expect(estado.diasConLecturas == 14)
        #expect(estado.gmiEsFiable)
        // El mismo número que la referencia: 3.31 + 0.02392 × 154.
        #expect(abs(try #require(estado.indicadores).gmi - 6.9936799999999995) < 1e-9)
    }

    @Test("15 · RF-16: el TIR se mide contra 70–180 aunque el perfil tenga el umbral de hipo en 80")
    func elPerfilNoMueveElTir() async throws {
        let perfil = PerfilDato(
            fechaNacimiento: Date(timeIntervalSince1970: 800_000_000), tipoUsuario: .tipo1,
            umbralHipo: 80, umbralHiper: 160
        )
        let estado = try await historial(
            [lectura(75, haceDias: 0), lectura(75, haceDias: 1), lectura(170, haceDias: 2)],
            perfil: perfil
        )
        let indicadores = try #require(estado.indicadores)
        #expect(indicadores.tir == 100)                       // las tres están entre 70 y 180
        #expect(abs(indicadores.tbr - 200.0 / 3) < 1e-9)      // las dos de 75 están bajo 80
        #expect(abs(indicadores.tar - 100.0 / 3) < 1e-9)      // la de 170 está sobre 160
    }

    @Test("16 · RF-16: el periodo de 7 días no incluye una lectura de hace 9")
    func laVentanaSeRespeta() async throws {
        let lecturas = [
            lectura(100, haceDias: 0), lectura(110, haceDias: 1), lectura(120, haceDias: 2),
            lectura(400, haceDias: 9),
        ]
        let semana = try await historial(lecturas, periodoDias: 7)
        #expect(semana.periodoDias == 7)
        #expect(try #require(semana.indicadores).n == 3)
        #expect(semana.diasConLecturas == 3)
        #expect(try #require(semana.indicadores).promedio == 110)

        // En el de 14 sí entra.
        let quincena = try await historial(lecturas, periodoDias: 14)
        #expect(try #require(quincena.indicadores).n == 4)
    }

    @Test("17 · RF-16: sin perfil guardado, los umbrales son los de ConfiguracionDominio")
    func sinPerfilNoSeCae() async throws {
        let estado = try await historial(
            [lectura(65, haceDias: 0), lectura(100, haceDias: 1), lectura(185, haceDias: 2)]
        )
        let indicadores = try #require(estado.indicadores)
        #expect(abs(indicadores.tbr - 100.0 / 3) < 1e-9)      // solo el 65 está bajo 70
        #expect(abs(indicadores.tar - 100.0 / 3) < 1e-9)      // solo el 185 está sobre 180
        // Las tres cayeron a la misma hora: esa tiene día típico y las otras 23 no.
        #expect(estado.diaTipico.map(\.hora) == [11])
        #expect(estado.horasSinDatos == 23)
    }
}
