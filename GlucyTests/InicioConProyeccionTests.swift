import Foundation
import Testing
@testable import Glucy

/// Dónde acaba la predicción cuando llega a la pantalla: en su propio tramo, punteada, y con
/// la ventana de la gráfica estirada para que se vea.
struct InicioConProyeccionTests {

    private let ahora = InicioDePrueba.ahora

    private func conSerie(_ cuantas: Int) async throws -> RepositorioLecturasFalso {
        let lecturas = RepositorioLecturasFalso()
        for indice in 0..<cuantas {
            try await InicioDePrueba.guardar(
                100 + Double(indice) * 2,
                haceMin: Double(cuantas - 1 - indice) * 5,
                origen: .sensor, en: lecturas
            )
        }
        return lecturas
    }

    @Test("La predicción va en su propio tramo y marcada como proyectada")
    func laPrediccionVaEnSuPropioTramo() async throws {
        let lecturas = try await conSerie(13)
        let estado = try await InicioDePrueba.estado(
            lecturas: lecturas, comidas: RepositorioComidasFalso(),
            dosis: RepositorioDosisFalso(), lecturaHealthKitActiva: true,
            modelos: [ModeloFalso(devuelve: .success(145))]
        )

        let proyectados = estado.tramos.flatMap { $0 }.filter { $0.serie == .proyectada }
        // Tres puntos: la lectura desde la que se predijo y la predicción. Con un solo modelo
        // son dos; el tercero sale cuando están los dos horizontes.
        #expect(proyectados.count == 2)
        #expect(proyectados.first?.mgDl == 124)   // la última medida, que es la base
        #expect(proyectados.last?.mgDl == 145)
        // Y van juntos en un tramo, aparte de los medidos: así la gráfica los une con línea
        // punteada sin tocar la continua.
        let suTramo = try #require(estado.tramos.last)
        #expect(suTramo.allSatisfy { $0.serie == .proyectada })
        #expect(estado.tramos.dropLast().flatMap { $0 }.allSatisfy { $0.serie == .medida })
    }

    @Test("Los puntos predichos tienen el mismo id entre dos consultas seguidas")
    func losIdsDeLaProyeccionNoCambian() async throws {
        let lecturas = try await conSerie(13)
        func ids() async throws -> [UUID] {
            try await InicioDePrueba.estado(
                lecturas: lecturas, comidas: RepositorioComidasFalso(),
                dosis: RepositorioDosisFalso(), lecturaHealthKitActiva: true,
                modelos: [ModeloFalso(devuelve: .success(145))]
            ).tramos.flatMap { $0 }.filter { $0.serie == .proyectada }.map(\.id)
        }
        // Con un id nuevo en cada pasada la gráfica se volvería a animar entera cada minuto.
        #expect(try await ids() == (try await ids()))
    }

    @Test("La ventana de la gráfica llega hasta la predicción más lejana")
    func laVentanaLlegaHastaLaPrediccion() async throws {
        let lecturas = try await conSerie(13)
        let estado = try await InicioDePrueba.estado(
            lecturas: lecturas, comidas: RepositorioComidasFalso(),
            dosis: RepositorioDosisFalso(), lecturaHealthKitActiva: true,
            modelos: [
                ModeloFalso(horizonteMin: 30, devuelve: .success(145)),
                ModeloFalso(horizonteMin: 60, devuelve: .success(150)),
            ]
        )
        // Sin esto la línea punteada se calcula, se dibuja fuera de la escala y no se ve: el
        // peor de los dos fallos, porque parece que la app no predice.
        let maslejano = try #require(
            estado.tramos.flatMap { $0 }.filter { $0.serie == .proyectada }.map(\.ts).max()
        )
        #expect(estado.ventana.upperBound >= maslejano)
        #expect(estado.ventana.upperBound == ahora.addingTimeInterval(60 * 60))
    }

    @Test("Sin sensor no hay tramo punteado y el motivo es ese")
    func sinSensorNoHayTramoPunteado() async throws {
        let lecturas = RepositorioLecturasFalso()
        try await InicioDePrueba.guardar(120, haceMin: 200, origen: .manual, en: lecturas)
        let estado = try await InicioDePrueba.estado(
            lecturas: lecturas, comidas: RepositorioComidasFalso(),
            dosis: RepositorioDosisFalso(), lecturaHealthKitActiva: false,
            modelos: [ModeloFalso(devuelve: .success(145))]
        )

        #expect(estado.proyeccion == .failure(.sinSensor))
        #expect(estado.tramos.flatMap { $0 }.allSatisfy { $0.serie == .medida })
        // Y el aviso de RF-10b sigue en pie: no es un caso degradado, es la regla 8.
        #expect(estado.puedeAlertarHipoglucemia == false)
    }

    @Test("Sin artefacto cargado la pantalla queda como estaba y lo dice")
    func sinArtefactoLaPantallaQuedaIgual() async throws {
        let lecturas = try await conSerie(13)
        let estado = try await InicioDePrueba.estado(
            lecturas: lecturas, comidas: RepositorioComidasFalso(),
            dosis: RepositorioDosisFalso(), lecturaHealthKitActiva: true
        )

        guard case .failure(.sinModelo) = estado.proyeccion else {
            Issue.record("se esperaba `sinModelo` y salió \(estado.proyeccion)")
            return
        }
        #expect(estado.tramos.flatMap { $0 }.allSatisfy { $0.serie == .medida })
        #expect(estado.ventana.upperBound == ahora)
        // Y lo demás sigue en su sitio: un artefacto que no carga no puede quitarle a nadie
        // su glucosa de ahora (regla 1).
        #expect(estado.ultima?.mgDl == 124)
    }
}
