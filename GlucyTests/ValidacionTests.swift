import Foundation
import Testing
@testable import Glucy

/// Validación de lo que entra al teléfono.
struct ValidacionTests {

    private let ahora = Date(timeIntervalSince1970: 1_758_240_000)

    /// P-01. Sin umbral de confianza: no hay número de OCR lo bastante bueno para
    /// guardarse solo (D-11).
    @Test("P-01: un valor de OCR sin confirmar no se guarda")
    func P01_ocrSinConfirmarNoSeGuarda() {
        let rechazo = Validacion.validarLectura(
            mgDl: 120,
            tsUtc: ahora,
            ahora: ahora,
            origen: .fotoGlucometro,
            confirmadaPorUsuario: false
        )
        #expect(rechazo == .ocrSinConfirmar)

        // Confirmado por la persona, el mismo valor sí entra.
        #expect(Validacion.validarLectura(
            mgDl: 120,
            tsUtc: ahora,
            ahora: ahora,
            origen: .fotoGlucometro,
            confirmadaPorUsuario: true
        ) == nil)
    }

    /// P-02. Los extremos 20 y 600 son válidos: el rechazo empieza fuera de ellos.
    @Test("P-02: 900 mg/dL no se guarda; 20 y 600 sí")
    func P02_valorFueraDeRangoNoSeGuarda() {
        #expect(Validacion.validarLectura(
            mgDl: 900, tsUtc: ahora, ahora: ahora, origen: .manual
        ) == .fueraDeRango(valor: 900))

        #expect(Validacion.validarLectura(
            mgDl: 19.9, tsUtc: ahora, ahora: ahora, origen: .manual
        ) == .fueraDeRango(valor: 19.9))

        #expect(Validacion.validarLectura(
            mgDl: 20, tsUtc: ahora, ahora: ahora, origen: .manual
        ) == nil)

        #expect(Validacion.validarLectura(
            mgDl: 600, tsUtc: ahora, ahora: ahora, origen: .manual
        ) == nil)
    }

    @Test("Una lectura del futuro se rechaza: corrompe el orden de la serie")
    func marcaDeTiempoFuturaSeRechaza() {
        #expect(Validacion.validarLectura(
            mgDl: 120,
            tsUtc: ahora.addingTimeInterval(60),
            ahora: ahora,
            origen: .manual
        ) == .marcaDeTiempoFutura)

        // El instante exacto no es futuro.
        #expect(Validacion.validarLectura(
            mgDl: 120, tsUtc: ahora, ahora: ahora, origen: .manual
        ) == nil)
    }

    @Test("El OCR sin confirmar se rechaza antes que el rango: manda D-11")
    func ocrSinConfirmarManda() {
        #expect(Validacion.validarLectura(
            mgDl: 900,
            tsUtc: ahora,
            ahora: ahora,
            origen: .fotoGlucometro,
            confirmadaPorUsuario: false
        ) == .ocrSinConfirmar)
    }

    /// Dos pinchazos separados por horas no forman una tasa de cambio.
    @Test("La tasa de cambio solo aplica a la serie continua del sensor")
    func tasaDeCambioSoloAplicaASerieContinua() {
        let previo = ahora.addingTimeInterval(-5 * 60)

        // 60 → 300 mg/dL en 5 min son 48 mg/dL/min: imposible en serie continua.
        #expect(Validacion.esAtipicaPorTasa(
            mgDlPrevio: 60, tsPrevio: previo, mgDl: 300, ts: ahora, origen: .sensor
        ))

        // El mismo salto entre dos pinchazos no es atípico, es la vida.
        #expect(Validacion.esAtipicaPorTasa(
            mgDlPrevio: 60, tsPrevio: previo, mgDl: 300, ts: ahora, origen: .manual
        ) == false)

        // 4 mg/dL/min exactos no pasa el umbral: es «más de 4».
        #expect(Validacion.esAtipicaPorTasa(
            mgDlPrevio: 100, tsPrevio: previo, mgDl: 120, ts: ahora, origen: .sensor
        ) == false)

        // Sin tiempo transcurrido no hay tasa que calcular.
        #expect(Validacion.esAtipicaPorTasa(
            mgDlPrevio: 60, tsPrevio: ahora, mgDl: 300, ts: ahora, origen: .sensor
        ) == false)
    }

    /// RF-23. Interpolar entre dos lecturas manuales sería inventar datos.
    @Test("Solo se interpola hasta 15 min y solo en serie continua")
    func interpolacionSoloHasta15MinYSoloEnSensor() {
        #expect(Validacion.sePuedeInterpolar(huecoMin: 10, origen: .sensor))
        #expect(Validacion.sePuedeInterpolar(huecoMin: 15, origen: .sensor))
        #expect(Validacion.sePuedeInterpolar(huecoMin: 20, origen: .sensor) == false)
        #expect(Validacion.sePuedeInterpolar(huecoMin: 10, origen: .manual) == false)
        #expect(Validacion.sePuedeInterpolar(huecoMin: 0, origen: .sensor) == false)
    }
}
