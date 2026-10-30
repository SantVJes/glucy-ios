import Foundation
import Testing
@testable import Glucy

/// Lo que la gráfica tiene prohibido dibujar: una recta sobre un hueco y una proyección sin
/// modelo.
struct GraficaGlucosaTests {

    private let inicio = Date(timeIntervalSince1970: 1_758_240_000)

    private func puntos(enMinutos minutos: [Double]) -> [PuntoGrafica] {
        minutos.map {
            PuntoGrafica(
                id: UUID(), ts: inicio.addingTimeInterval($0 * 60), mgDl: 120,
                serie: .medida, origen: .sensor
            )
        }
    }

    @Test("18 · RF-06b: un hueco de 20 min parte la serie en dos tramos; uno de 10 min, no")
    func elHuecoCortaLaLinea() {
        let conHueco = TramosDeSerie.partir(puntos(enMinutos: [0, 5, 10, 30, 35]))
        #expect(conHueco.map(\.count) == [3, 2])

        let sinHueco = TramosDeSerie.partir(puntos(enMinutos: [0, 5, 15, 25]))
        #expect(sinHueco.map(\.count) == [4])

        // Justo en el límite todavía es la misma línea; un minuto más ya no.
        #expect(TramosDeSerie.partir(puntos(enMinutos: [0, 15])).count == 1)
        #expect(TramosDeSerie.partir(puntos(enMinutos: [0, 16])).count == 2)
        #expect(TramosDeSerie.partir([]).isEmpty)
    }

    /// Ya hay modelo —la fase 3 llegó—, así que esta prueba dejó de ser una frontera y pasó a
    /// ser la red: **sin artefacto cargado nadie inventa un punto proyectado**. Una línea base
    /// de respaldo en la app sería una cifra que nadie validó, en el sitio donde la gente la
    /// leería como una predicción. Lo que sí hay con modelo está en
    /// `InicioConProyeccionTests`.
    @Test("19 · RF-10: sin artefacto cargado no hay ningún punto de la serie proyectada")
    func nadaConstruyeUnaProyeccion() async throws {
        for activa in [true, false] {
            let lecturas = RepositorioLecturasFalso()
            for minutos in stride(from: 0.0, through: 170, by: 5) {
                try await InicioDePrueba.guardar(
                    110 + minutos / 5, haceMin: minutos, origen: .sensor, en: lecturas
                )
            }
            try await InicioDePrueba.guardar(140, haceMin: 600, origen: .manual, en: lecturas)

            let estado = try await InicioDePrueba.estado(
                lecturas: lecturas, comidas: RepositorioComidasFalso(), dosis: RepositorioDosisFalso(),
                lecturaHealthKitActiva: activa
            )
            let todos = estado.tramos.flatMap { $0 }

            #expect(estado.modo == (activa ? .sensor : .sinSensor))
            #expect(!todos.isEmpty)
            #expect(todos.allSatisfy { $0.serie == .medida })
            // Ni un punto después de ahora: nada de 30 ni de 60 minutos hacia adelante.
            #expect(todos.allSatisfy { $0.ts <= InicioDePrueba.ahora })
        }
    }
}
