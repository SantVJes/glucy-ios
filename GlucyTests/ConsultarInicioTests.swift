import Foundation
import Testing
@testable import Glucy

/// Lo que la pantalla de inicio recibe ya resuelto. Aquí se fijan las tres cosas que no puede
/// hacer: unir pinchazos con una línea, inventar una comida y callarse que sin sensor no
/// anticipa hipoglucemias.
struct ConsultarInicioTests {

    /// El estado de inicio con esas lecturas y sin comidas ni dosis registradas.
    private func estado(
        _ lecturas: [(mgDl: Double, haceMin: Double, origen: Origen)],
        lecturaHealthKitActiva: Bool,
        comidas: RepositorioComidasFalso
    ) async throws -> EstadoInicio {
        let repositorio = RepositorioLecturasFalso()
        for l in lecturas {
            try await InicioDePrueba.guardar(l.mgDl, haceMin: l.haceMin, origen: l.origen, en: repositorio)
        }
        return try await InicioDePrueba.estado(
            lecturas: repositorio, comidas: comidas, dosis: RepositorioDosisFalso(),
            lecturaHealthKitActiva: lecturaHealthKitActiva
        )
    }

    @Test("20 · RF-23: en modo sin sensor cada punto viene en su propio tramo")
    func sinSensorNoHayLineaQueDibujar() async throws {
        // Pinchazos separados por horas, y dos casi seguidos: ni esos se unen. El último
        // queda fuera de la ventana de siete días y no se dibuja.
        let estado = try await estado(
            [
                (95, 5, .manual), (180, 10, .manual), (140, 9 * 60, .manual),
                (110, 26 * 60, .manual), (160, 5 * 1440, .manual), (200, 8 * 1440, .manual),
            ],
            lecturaHealthKitActiva: false, comidas: RepositorioComidasFalso()
        )

        #expect(estado.modo == .sinSensor)
        #expect(estado.tramos.count == 5)
        #expect(estado.tramos.allSatisfy { $0.count == 1 })
        #expect(estado.ultima?.mgDl == 95)
        #expect(estado.antiguedadMin == 5)

        // Con sensor esos mismos dos puntos seguidos sí forman una línea.
        let conSensor = try await self.estado(
            [(95, 5, .sensor), (180, 10, .sensor)],
            lecturaHealthKitActiva: true, comidas: RepositorioComidasFalso()
        )
        #expect(conSensor.tramos.map(\.count) == [2])
    }

    @Test("21 · P-12: la glucosa sube 60 mg/dL sin comida registrada y no se inventa ninguna")
    func noSeInfiereUnaComida() async throws {
        let comidas = RepositorioComidasFalso()
        let estado = try await estado(
            [100.0, 112, 124, 136, 148, 160].enumerated().map { indice, mgDl in
                (mgDl, Double(25 - indice * 5), Origen.sensor)
            },
            lecturaHealthKitActiva: true, comidas: comidas
        )

        #expect(estado.modo == .sensor)
        #expect(estado.ultima?.mgDl == 160)
        #expect(estado.carbohidratosActivosG == 0)
        #expect(estado.insulinaActivaUI == 0)
        #expect(await comidas.vecesGuardado == 0)
        #expect(try await comidas.contar() == 0)
        // Los seis puntos que se midieron, y ni uno más.
        #expect(estado.tramos.flatMap { $0 }.map(\.mgDl) == [100, 112, 124, 136, 148, 160])
    }

    @Test("22 · P-04: en modo sin sensor no se puede alertar de hipoglucemia")
    func sinSensorNoSeAnticipa() async throws {
        // Sin Salud.
        let sinSalud = try await estado(
            [(120, 3, .manual)], lecturaHealthKitActiva: false, comidas: RepositorioComidasFalso()
        )
        #expect(!sinSalud.puedeAlertarHipoglucemia)

        // Con Salud, pero con la última muestra del sensor ya vieja (P-03).
        let rancio = try await estado(
            [(120, 20, .sensor)], lecturaHealthKitActiva: true, comidas: RepositorioComidasFalso()
        )
        #expect(rancio.modo == .sinSensor)
        #expect(!rancio.puedeAlertarHipoglucemia)

        // El primer día, sin ninguna lectura.
        let vacio = try await estado([], lecturaHealthKitActiva: false, comidas: RepositorioComidasFalso())
        #expect(!vacio.puedeAlertarHipoglucemia)
        #expect(vacio.ultima == nil)
        #expect(vacio.antiguedadMin == nil)
        #expect(vacio.tramos.isEmpty)

        // Solo con el sensor fresco.
        let fresco = try await estado(
            [(120, 4, .sensor)], lecturaHealthKitActiva: true, comidas: RepositorioComidasFalso()
        )
        #expect(fresco.puedeAlertarHipoglucemia)
    }
}
