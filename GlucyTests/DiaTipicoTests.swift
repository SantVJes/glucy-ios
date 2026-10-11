import Foundation
import Testing
@testable import Glucy

/// El día típico: mediana y cuartiles por hora. Es la única regla clínica de la fase 1 sin
/// par en `referencia/reglas_clinicas.py`, así que los números de aquí están calculados a
/// mano con la definición por omisión de `numpy.percentile`, que es la que la fase 2 tiene
/// que reproducir.
struct DiaTipicoTests {

    /// Medianoche UTC del 19 de septiembre de 2025.
    private static let medianoche = Date(timeIntervalSince1970: 1_758_240_000)

    private static func lectura(
        _ mgDl: Double, hora: Int, minuto: Int = 0, dia: Int = 0, zona: String = "UTC"
    ) -> LecturaGlucosaDato {
        LecturaGlucosaDato(
            mgDl: mgDl,
            tsUtc: medianoche.addingTimeInterval(Double(dia * 86_400 + hora * 3600 + minuto * 60)),
            zonaHoraria: zona,
            origen: .manual
        )
    }

    @Test("1 · RF-16: la mediana de una lista par interpola: [1, 2, 3, 4] da 2.5")
    func laMedianaDeUnaListaParInterpola() {
        #expect(DiaTipico.percentil(50, de: [1, 2, 3, 4]) == 2.5)
        // El orden de entrada no importa.
        #expect(DiaTipico.percentil(50, de: [4, 1, 3, 2]) == 2.5)
    }

    @Test(
        "2 · RF-16: los percentiles son los de numpy.percentile por omisión",
        arguments: [
            (25.0, [10.0, 20, 30, 40, 50], 20.0),
            (75.0, [10.0, 20, 30, 40, 50], 40.0),
            // Posición 0.25 × 3 = 0.75: entre el 1 y el 2.
            (25.0, [1.0, 2, 3, 4], 1.75),
            (75.0, [1.0, 2, 3, 4], 3.25),
            (0.0, [10.0, 20, 30], 10.0),
            (100.0, [10.0, 20, 30], 30.0),
        ]
    )
    func percentilesComoNumpy(p: Double, valores: [Double], esperado: Double) throws {
        let resultado = try #require(DiaTipico.percentil(p, de: valores))
        #expect(abs(resultado - esperado) < 1e-12)
    }

    @Test("3 · RF-16: el percentil de una lista vacía es nil, y el de un solo valor es ese valor")
    func losDosExtremos() {
        #expect(DiaTipico.percentil(50, de: []) == nil)
        #expect(DiaTipico.percentil(50, de: [112]) == 112)
        #expect(DiaTipico.percentil(25, de: [112]) == 112)
        #expect(DiaTipico.percentil(75, de: [112]) == 112)
    }

    @Test("4 · RF-16: una hora con dos lecturas no aparece: con dos no hay cuartil")
    func dosLecturasNoBastan() {
        let horas = DiaTipico.calcular(lecturas: [
            Self.lectura(100, hora: 8, dia: 0),
            Self.lectura(140, hora: 8, dia: 1),
        ])
        #expect(horas.isEmpty)
    }

    @Test("5 · RF-16: una hora con tres lecturas aparece, con n igual a 3")
    func tresLecturasBastan() throws {
        let horas = DiaTipico.calcular(lecturas: [
            Self.lectura(100, hora: 8, dia: 0),
            Self.lectura(120, hora: 8, minuto: 30, dia: 1),
            Self.lectura(160, hora: 8, minuto: 59, dia: 2),
            // Una sola lectura a las nueve: esa hora se queda vacía, no hereda la de las ocho.
            Self.lectura(200, hora: 9, dia: 0),
        ])
        #expect(horas.count == 1)
        let ocho = try #require(horas.first)
        #expect(ocho.hora == 8)
        #expect(ocho.n == 3)
        #expect(ocho.mediana == 120)
        #expect(ocho.p25 == 110)
        #expect(ocho.p75 == 140)
    }

    @Test("6 · regla 5: el mismo instante con zonas distintas cae en horas distintas")
    func seAgrupaPorLaHoraLocalGuardada() {
        // Medianoche UTC son las 18 h en Ciudad de México y las 9 h en Tokio.
        let lecturas = (0..<3).flatMap { dia in
            [
                Self.lectura(110, hora: 0, dia: dia, zona: "America/Mexico_City"),
                Self.lectura(150, hora: 0, dia: dia, zona: "Asia/Tokyo"),
            ]
        }
        let horas = DiaTipico.calcular(lecturas: lecturas)

        #expect(horas.map(\.hora) == [9, 18])
        #expect(horas.map(\.mediana) == [150, 110])
        // Ninguna cayó en la hora de UTC.
        #expect(!horas.contains { $0.hora == 0 })
    }

    @Test("7 · RF-16: 24 horas con datos dan 24 horas típicas, ordenadas de 0 a 23")
    func elDiaCompleto() {
        let lecturas = (0..<24).reversed().flatMap { hora in
            (0..<3).map { dia in Self.lectura(100 + Double(hora), hora: hora, dia: dia) }
        }
        let horas = DiaTipico.calcular(lecturas: lecturas)

        #expect(horas.map(\.hora) == Array(0..<24))
        #expect(horas.allSatisfy { $0.n == 3 })
        #expect(horas.map(\.mediana) == (0..<24).map { 100 + Double($0) })
    }

    @Test("8 · RF-16: en toda hora, P25 ≤ mediana ≤ P75")
    func losCuartilesEstanEnOrden() {
        // Una secuencia fija, no `random()`: si esto falla, tiene que fallar igual mañana.
        var semilla: UInt64 = 20_260_919
        func siguiente() -> Double {
            semilla = semilla &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Double(semilla >> 33) / Double(1 << 31)
        }
        let lecturas = (0..<600).map { _ in
            Self.lectura(
                40 + siguiente() * 360,
                hora: Int(siguiente() * 24) % 24,
                minuto: Int(siguiente() * 60) % 60,
                dia: Int(siguiente() * 14) % 14
            )
        }
        let horas = DiaTipico.calcular(lecturas: lecturas)

        #expect(!horas.isEmpty)
        #expect(horas.reduce(0) { $0 + $1.n } <= lecturas.count)
        for hora in horas {
            #expect(hora.p25 <= hora.mediana, "hora \(hora.hora)")
            #expect(hora.mediana <= hora.p75, "hora \(hora.hora)")
        }
    }
}
