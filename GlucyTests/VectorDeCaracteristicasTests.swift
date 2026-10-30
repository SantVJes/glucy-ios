import Foundation
import Testing
@testable import Glucy

/// El contrato entre el modelo y la app, fijado.
///
/// Un desajuste aquí no revienta: el modelo recibe quince números válidos en el orden
/// equivocado, o uno bien calculado con otra fórmula, y devuelve una cifra plausible que la
/// pantalla dibuja. Así que estas pruebas no comprueban que el código corra, comprueban que
/// **cada número sea el mismo que calculó el pipeline que entrenó el modelo**, que es
/// `app/services/pipeline/caracteristicas.py` de glucy-backend.
///
/// Los repositorios no se pueden importar entre sí, así que los valores van **literales**.
/// Viernes 19 de septiembre de 2025, 00:00:00 UTC. Es el mismo instante que usa
/// `InicioDePrueba`, y cae en medianoche exacta, que es el caso que más vale: es cuando la hora
/// cíclica tiene que portarse bien, y es la hora de la hipoglucemia nocturna.
private let ahora = Date(timeIntervalSince1970: 1_758_240_000)
private let utc = TimeZone(identifier: "UTC")!

private func lectura(_ mgDl: Double, haceMin minutos: Double, atipica: Bool = false)
    -> LecturaGlucosaDato {
    LecturaGlucosaDato(
        mgDl: mgDl,
        tsUtc: ahora.addingTimeInterval(-minutos * 60),
        zonaHoraria: "UTC",
        origen: .sensor,
        atipica: atipica
    )
}

/// Una serie continua de cinco minutos que llega hasta `ahora`.
private func serieDeCincoMinutos(_ valores: [Double]) -> [LecturaGlucosaDato] {
    valores.enumerated().map { i, v in
        lectura(v, haceMin: Double(valores.count - 1 - i) * 5)
    }
}

private func denso(
    _ serie: [LecturaGlucosaDato],
    comidas: [ComidaDato] = [],
    dosis: [DosisInsulinaDato] = []
) -> [String: Double] {
    VectorDeCaracteristicas.denso(
        serie: serie, comidas: comidas, dosis: dosis, ahora: ahora, zona: utc
    )
}

struct VectorDeCaracteristicasTests {

    // MARK: - El orden, que es lo que no se puede derivar

    @Test("Los quince nombres y su orden son los del contrato, literales")
    func elOrdenEsElDelContrato() {
        // Copiados de CARACTERISTICAS_DENSAS del backend. Si alguien agrega, quita o mueve
        // uno, esta prueba lo dice; sin ella el cambio sale en silencio y el modelo recibe
        // las columnas cambiadas de lugar.
        #expect(VectorDeCaracteristicas.densas == [
            "mg_dl", "rezago_5", "rezago_10", "rezago_15", "rezago_30", "rezago_60",
            "derivada_1", "derivada_2", "media_30", "media_60",
            "cob", "iob", "hora_sin", "hora_cos", "dia_semana",
        ])
    }

    @Test("El vector para Core ML va por nombre y cuantizado a 32 bits")
    func elVectorParaCoreMLVaPorNombreYEn32Bits() throws {
        let vector = denso(serieDeCincoMinutos([100, 110, 120]))
        let paraModelo = try VectorDeCaracteristicas.paraCoreML(vector)

        // Por nombre, porque así está declarado el artefacto: quince entradas `double`
        // nombradas, no un arreglo. El orden de `densas` sirve para presentar los factores;
        // para alimentar el modelo lo que tiene que cuadrar son los nombres.
        #expect(Set(paraModelo.keys) == Set(VectorDeCaracteristicas.densas))
        #expect(paraModelo["mg_dl"] == 120)
        #expect(paraModelo["rezago_5"] == 110)

        // Cuantizado a 32 bits y entregado como `Double`: los umbrales del árbol son de 32
        // bits y XGBoost compara contra ellos con esa precisión, mientras Core ML pide
        // `double`. Medido sobre `m1-v0.2.0-simulador`, mandar la doble precisión sin
        // redondear desvía la predicción hasta 1.57 mg/dL en 450 de 2 000 filas. Que el valor
        // pierda los dígitos que `Float` no puede guardar es la prueba de que ocurre.
        let conMuchosDigitos = denso(
            serieDeCincoMinutos([100, 120]),
            dosis: [DosisInsulinaDato(
                tsUtc: ahora.addingTimeInterval(-180 * 60), unidades: 6, tipo: .bolo
            )]
        )
        let iobDoble = conMuchosDigitos["iob"]!
        let iobCuantizado = try VectorDeCaracteristicas.paraCoreML(conMuchosDigitos)["iob"]!
        #expect(iobCuantizado != iobDoble)
        #expect(iobCuantizado == Double(Float(iobDoble)))
    }

    @Test("Un hueco llega al modelo como `NaN` y no relleno")
    func unHuecoLlegaComoNaN() throws {
        // Serie de dos lecturas: no hay rezago de 60 minutos. El árbol trae 498 nodos con
        // `missingValueTracksTrueChild`, o sea que Core ML sabe para qué lado mandar la fila
        // con el hueco, igual que XGBoost. Rellenarlo desvía hasta 19.8 mg/dL, así que la
        // cuantización a 32 bits no puede convertir el `NaN` en un número.
        let paraModelo = try VectorDeCaracteristicas.paraCoreML(
            denso(serieDeCincoMinutos([100, 120]))
        )
        #expect(paraModelo["rezago_60"]!.isNaN)
        #expect(paraModelo["mg_dl"] == 120)
    }

    @Test("Un nombre de más o de menos revienta en lugar de ignorarse")
    func unNombreQueNoCuadraRevienta() {
        var vector = denso(serieDeCincoMinutos([100, 110]))
        vector["rezago_5"] = nil
        vector["rezago_cinco"] = 110
        #expect(throws: ErrorDeCaracteristicas.noEsDelJuego(
            sobran: ["rezago_cinco"], faltan: ["rezago_5"]
        )) {
            try VectorDeCaracteristicas.paraCoreML(vector)
        }
    }

    // MARK: - Los rezagos

    @Test("Los rezagos se buscan por tiempo y no por posición")
    func losRezagosSeBuscanPorTiempo() {
        // Serie con un hueco: hay lectura a 0, 5 y 60 minutos, y nada en medio. Buscando por
        // posición, «la de una atrás» de la de 60 sería la de 5, y saldría como rezago_5.
        let serie = [lectura(90, haceMin: 60), lectura(110, haceMin: 5), lectura(120, haceMin: 0)]
        let vector = denso(serie)
        #expect(vector["mg_dl"] == 120)
        #expect(vector["rezago_5"] == 110)
        #expect(vector["rezago_60"] == 90)
        // Los de en medio no existen y por eso son NaN, no el valor más próximo que haya.
        #expect(vector["rezago_10"]!.isNaN)
        #expect(vector["rezago_15"]!.isNaN)
        #expect(vector["rezago_30"]!.isNaN)
    }

    @Test("Un rezago que no existe es NaN y nunca cero")
    func unRezagoQueFaltaEsNaN() {
        // Serie de diez minutos: el rezago de 60 no puede existir.
        let vector = denso(serieDeCincoMinutos([100, 110, 120]))
        #expect(vector["rezago_60"]!.isNaN)
        // Un cero aquí sería una glucosa de cero, que el modelo leería como un valor real y
        // arrastraría la predicción hacia abajo.
        #expect(vector["rezago_60"] != 0)
    }

    @Test("Una lectura a media muestra todavía sirve; más lejos no")
    func laToleranciaEsMediaMuestra() {
        let justo = [lectura(95, haceMin: 7.5), lectura(120, haceMin: 0)]
        #expect(denso(justo)["rezago_5"] == 95)

        let pasado = [lectura(95, haceMin: 7.6), lectura(120, haceMin: 0)]
        #expect(denso(pasado)["rezago_5"]!.isNaN)
    }

    @Test("Un empate exacto se queda con la lectura más antigua")
    func unEmpateSeQuedaConLaMasAntigua() {
        // Las dos a 2.5 minutos del instante pedido (hace 5 min).
        let serie = [
            lectura(111, haceMin: 7.5), lectura(222, haceMin: 2.5), lectura(120, haceMin: 0),
        ]
        // Es lo que hace el `min` del backend sobre una lista ordenada por tiempo. No es que
        // la antigua sea mejor: es que las dos implementaciones tienen que elegir igual.
        #expect(denso(serie)["rezago_5"] == 111)
    }

    // MARK: - Las derivadas

    @Test("La primera derivada es mg/dL por minuto")
    func laPrimeraDerivadaEsPorMinuto() {
        let vector = denso(serieDeCincoMinutos([100, 110]))
        #expect(vector["derivada_1"] == 2)  // 10 mg/dL en 5 min
    }

    @Test("La segunda derivada es la del backend: (actual − 2·r5 + r10) / 25")
    func laSegundaDerivadaEsLaDelBackend() {
        // 100, 110, 125: la pendiente pasa de 2 a 3 mg/dL por minuto.
        let vector = denso(serieDeCincoMinutos([100, 110, 125]))
        #expect(vector["derivada_2"] == (125 - 2 * 110 + 100) / 25)
        #expect(vector["derivada_2"] == 0.2)
    }

    @Test("Las derivadas son NaN cuando falta el rezago que hace falta")
    func lasDerivadasSonNaNSinSusRezagos() {
        // Una sola lectura: no hay rezago de 5 ni de 10.
        let vector = denso([lectura(120, haceMin: 0)])
        #expect(vector["derivada_1"]!.isNaN)
        #expect(vector["derivada_2"]!.isNaN)

        // Con rezago de 5 pero sin el de 10, la primera existe y la segunda no.
        let dos = denso(serieDeCincoMinutos([110, 120]))
        #expect(dos["derivada_1"] == 2)
        #expect(dos["derivada_2"]!.isNaN)
    }

    // MARK: - Los promedios móviles

    @Test("La ventana de los promedios es (desde, ahora] y no incluye su borde")
    func laVentanaNoIncluyeSuBordeInferior() {
        // Siete lecturas de 5 en 5: la primera cae exactamente a 30 minutos de la última.
        let vector = denso(serieDeCincoMinutos([100, 110, 120, 130, 140, 150, 160]))
        // Seis y no siete. Con el borde incluido, este promedio daría 130 donde el servidor
        // da 135, en cada fila y sin que nada falle.
        #expect(vector["media_30"] == (110.0 + 120 + 130 + 140 + 150 + 160) / 6)
        #expect(vector["media_30"] == 135)
        #expect(vector["media_30"] != (100.0 + 110 + 120 + 130 + 140 + 150 + 160) / 7)
    }

    @Test("Sin lecturas en la ventana el promedio es NaN")
    func sinLecturasElPromedioEsNaN() {
        // Una lectura de hace 90 minutos: no cae ni en la ventana de 30 ni en la de 60, y
        // tampoco en la tolerancia de `mg_dl`.
        let vector = denso([lectura(120, haceMin: 90)])
        #expect(vector["media_30"]!.isNaN)
        #expect(vector["media_60"]!.isNaN)
        #expect(vector["mg_dl"]!.isNaN)
    }

    // MARK: - COB e IOB, que son los que ya tienen regla propia

    @Test("El COB del vector es el caso P-11: 60 g con 180 min, a los 90 min son 30 g")
    func elCobEsElCasoP11() {
        let comida = ComidaDato(
            tsUtc: ahora.addingTimeInterval(-90 * 60),
            carbsG: 60,
            tiempoAbsorcionMin: 180,
            origen: .manual
        )
        let vector = denso(serieDeCincoMinutos([100, 120]), comidas: [comida])
        #expect(vector["cob"] == 30)
    }

    @Test("Sin comidas el COB es cero y no NaN")
    func sinComidasElCobEsCero() {
        // No hay nada que absorber. No es un dato que falte, y por eso no es NaN.
        #expect(denso(serieDeCincoMinutos([100, 120]))["cob"] == 0)
        #expect(denso(serieDeCincoMinutos([100, 120]))["iob"] == 0)
    }

    @Test("A las tres horas de un bolo queda el 15.9 % y no el 40 %")
    func elIobEsElDeLaReferencia() {
        let dosis = DosisInsulinaDato(
            tsUtc: ahora.addingTimeInterval(-180 * 60), unidades: 6, tipo: .bolo
        )
        let vector = denso(serieDeCincoMinutos([100, 120]), dosis: [dosis])
        // 6 UI × 0.158796… El número literal es el que delató que glucy-ml calculaba esta
        // columna con una recta: decía 40 %, o sea 2.4 UI, 1.45 de más.
        #expect(abs(vector["iob"]! - 6 * 0.15879641537283806) < 1e-9)
        #expect(abs(vector["iob"]! - 6 * 0.40) > 1.4)
    }

    @Test("La basal no cuenta como insulina activa")
    func laBasalNoCuentaComoActiva() {
        let basal = DosisInsulinaDato(
            tsUtc: ahora.addingTimeInterval(-30 * 60), unidades: 20, tipo: .basal
        )
        #expect(denso(serieDeCincoMinutos([100, 120]), dosis: [basal])["iob"] == 0)
    }

    @Test("Cada dosis usa la duración de acción que tenía guardada")
    func cadaDosisConSuDuracion() {
        let hace = ahora.addingTimeInterval(-120 * 60)
        let deCinco = DosisInsulinaDato(tsUtc: hace, unidades: 5, tipo: .bolo, duracionAccionH: 5)
        let deOcho = DosisInsulinaDato(tsUtc: hace, unidades: 5, tipo: .bolo, duracionAccionH: 8)
        let conCinco = denso(serieDeCincoMinutos([100, 120]), dosis: [deCinco])["iob"]!
        let conOcho = denso(serieDeCincoMinutos([100, 120]), dosis: [deOcho])["iob"]!
        // Con una duración más larga queda más insulina trabajando a la misma hora.
        #expect(conOcho > conCinco)
    }

    // MARK: - La hora y el día

    @Test("El día de la semana es lunes = 0 y domingo = 6, como en el entrenamiento")
    func elDiaDeLaSemanaEsLunesCero() {
        // `Calendar` numera domingo = 1 y sábado = 7; el modelo aprendió la convención de
        // Python, lunes = 0. Sin convertir, el modelo recibiría un lunes donde aprendió un
        // domingo: un número válido, en la columna correcta, y equivocado.
        var calendario = Calendar(identifier: .gregorian)
        calendario.timeZone = utc
        let lunes = calendario.date(from: DateComponents(
            timeZone: utc, year: 2026, month: 10, day: 26, hour: 12
        ))!
        let domingo = calendario.date(from: DateComponents(
            timeZone: utc, year: 2026, month: 11, day: 1, hour: 12
        ))!
        #expect(VectorDeCaracteristicas.diaSemana(lunes, zona: utc) == 0)
        #expect(VectorDeCaracteristicas.diaSemana(domingo, zona: utc) == 6)
    }

    @Test("La hora del día cuenta los segundos")
    func laHoraCuentaLosSegundos() {
        let enPunto = VectorDeCaracteristicas.minutosDelDia(ahora, zona: utc)
        let conMedio = VectorDeCaracteristicas.minutosDelDia(
            ahora.addingTimeInterval(30), zona: utc
        )
        // El backend los cuenta, así que aquí también: una muestra que no cae en el minuto
        // exacto daría otro ángulo que en producción.
        #expect(conMedio == enPunto + 0.5)
    }

    @Test("La medianoche y las 23:50 quedan cerca en el seno y el coseno")
    func lasHorasExtremasQuedanCerca() {
        // Es para lo que existe la hora cíclica: como números están a 23 horas y en realidad
        // son veinte minutos, y la madrugada es cuando pasa lo que más importa.
        let (sinA, cosA) = VectorDeCaracteristicas.horaCiclica(23 * 60 + 50)
        let (sinB, cosB) = VectorDeCaracteristicas.horaCiclica(10)
        let distancia = ((sinA - sinB) * (sinA - sinB) + (cosA - cosB) * (cosA - cosB)).squareRoot()
        #expect(distancia < 0.1)
    }

    @Test("La hora se lee en la zona del dato y no en la del teléfono de hoy")
    func laHoraSeLeeEnLaZonaDelDato() {
        let mexico = TimeZone(identifier: "America/Mexico_City")!
        let enUtc = VectorDeCaracteristicas.minutosDelDia(ahora, zona: utc)
        let enMexico = VectorDeCaracteristicas.minutosDelDia(ahora, zona: mexico)
        // Alguien que viajó tiene lecturas de dos zonas, y la hora que vale es la que era
        // para esa persona en ese momento (regla 5).
        #expect(enUtc != enMexico)
    }

    // MARK: - Nada del futuro, nada que la persona no registró

    @Test("Una lectura posterior al instante que se predice no entra")
    func unaLecturaDelFuturoNoEntra() {
        // En producción no existe: a las 14:00 el teléfono no tiene las 14:05. Si entrara,
        // el modelo se mediría con información del futuro y el error saldría buenísimo.
        let conFuturo = [
            lectura(100, haceMin: 5), lectura(120, haceMin: 0), lectura(300, haceMin: -5),
        ]
        #expect(denso(conFuturo)["mg_dl"] == 120)
        #expect(denso(conFuturo)["media_30"] == (100.0 + 120) / 2)
    }

    @Test("Una comida o una dosis futuras no cuentan")
    func loFuturoNoCuenta() {
        let comida = ComidaDato(
            tsUtc: ahora.addingTimeInterval(30 * 60), carbsG: 60, origen: .manual
        )
        let dosis = DosisInsulinaDato(
            tsUtc: ahora.addingTimeInterval(30 * 60), unidades: 6, tipo: .bolo
        )
        let vector = denso(serieDeCincoMinutos([100, 120]), comidas: [comida], dosis: [dosis])
        // Las reglas de registro tratan una comida futura como entera y activa, que es
        // correcto para registrar y sería mirar hacia adelante al armar una fila.
        #expect(vector["cob"] == 0)
        #expect(vector["iob"] == 0)
    }

    @Test("Una lectura marcada como atípica no entra al vector")
    func lasAtipicasNoEntran() {
        let serie = [
            lectura(100, haceMin: 10), lectura(400, haceMin: 5, atipica: true),
            lectura(120, haceMin: 0),
        ]
        let vector = denso(serie)
        #expect(vector["rezago_5"]!.isNaN)
        #expect(vector["media_30"] == (100.0 + 120) / 2)
    }

    // MARK: - Una fila entera, calculada a mano

    @Test("Una fila completa coincide número por número con el cálculo a mano")
    func unaFilaEnteraCalculadaAMano() throws {
        // Trece lecturas de 5 en 5 = 60 minutos de serie, subiendo 5 mg/dL cada vez.
        let valores = (0..<13).map { 100.0 + Double($0) * 5 }
        let comida = ComidaDato(
            tsUtc: ahora.addingTimeInterval(-90 * 60),
            carbsG: 60, tiempoAbsorcionMin: 180, origen: .manual
        )
        let dosis = DosisInsulinaDato(
            tsUtc: ahora.addingTimeInterval(-180 * 60), unidades: 6, tipo: .bolo
        )
        let paraModelo = try VectorDeCaracteristicas.paraCoreML(
            denso(serieDeCincoMinutos(valores), comidas: [comida], dosis: [dosis])
        )
        let fila = VectorDeCaracteristicas.densas.map { paraModelo[$0]! }

        // Medianoche exacta: el ángulo es 0, así que el seno es 0 y el coseno es 1. Van
        // literales para fijar también que el ángulo se cuenta desde medianoche.
        let esperada: [Double] = [
            160,            // mg_dl
            155, 150, 145,  // rezago_5, 10, 15
            130, 100,       // rezago_30, 60
            1,              // derivada_1: 5 mg/dL en 5 min
            0,              // derivada_2: la pendiente no cambia
            147.5,          // media_30: las seis de (ahora−30, ahora], de 135 a 160
            132.5,          // media_60: las doce de (ahora−60, ahora], de 105 a 160
            30,             // cob: caso P-11
            Double(Float(6 * 0.15879641537283806)),  // iob: la curva de la referencia
            0, 1,           // hora_sin, hora_cos: medianoche
            4,              // dia_semana: viernes, con lunes = 0
        ]
        #expect(fila.count == esperada.count)
        for (i, (dio, debia)) in zip(fila, esperada).enumerated() {
            #expect(
                abs(dio - debia) < 1e-4,
                "\(VectorDeCaracteristicas.densas[i]): dio \(dio) y debía dar \(debia)"
            )
        }
    }
}
