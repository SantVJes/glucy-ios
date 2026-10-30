import Foundation
import Testing
@testable import Glucy

/// Lo que dibuja la pantalla de factores: la cifra, la frase y los cinco renglones.
@MainActor
struct FactoresViewModelTests {

    private let base = Date(timeIntervalSince1970: 1_758_240_000)

    private func aporte(
        factores: [(String, Double)],
        explicacion: String? = "Vas a bajar un poco.",
        deLaPlantilla: Bool = false,
        desacuerdoMgDl: Double? = nil,
        valorDelServidorMgDl: Double = 142
    ) -> FactoresYExplicacion {
        FactoresYExplicacion(
            horizonteMin: 30,
            valorDelServidorMgDl: valorDelServidorMgDl,
            tsBase: base,
            factores: factores.map { FactorDeLaPrediccion(nombre: $0.0, mgDl: $0.1) },
            shap: [],
            explicacion: explicacion,
            deLaPlantilla: deLaPlantilla,
            desacuerdoMgDl: desacuerdoMgDl
        )
    }

    @Test("Cada factor sale con su signo, su unidad y su proporción")
    func cadaFactorConSuSignoYSuUnidad() {
        let modelo = FactoresViewModel(
            aporte: aporte(factores: [
                ("tu glucosa de ahora", 20),
                ("la insulina que sigue activa", -10),
                ("cómo venías hace 5 minutos", 5),
            ]),
            valorPropioMgDl: 139.4,
            objetivo: base.addingTimeInterval(1800)
        )

        #expect(modelo.cifra == "139 mg/dL")
        #expect(modelo.cuando?.hasPrefix("a las ") == true)
        #expect(modelo.renglones.count == 3)

        let primero = modelo.renglones[0]
        #expect(primero.cifra == "+20 mg/dL")
        #expect(primero.sube)
        // El más grande llena la barra entera y los demás se miden contra él.
        #expect(primero.proporcion == 1)

        let segundo = modelo.renglones[1]
        // Signo menos de verdad, no un guion: se lee distinto en VoiceOver.
        #expect(segundo.cifra == "−10 mg/dL")
        #expect(segundo.sube == false)
        #expect(segundo.proporcion == 0.5)
        // Lo hablado lleva la palabra y no el signo, porque VoiceOver no lee «+».
        #expect(segundo.hablado == "la insulina que sigue activa: baja 10 mg/dL")

        #expect(modelo.renglones[2].proporcion == 0.25)
        #expect(modelo.porQueNoHayNada == nil)
    }

    @Test("La pantalla dice de dónde salió la frase")
    func diceDeDondeSalioLaFrase() {
        let delModelo = FactoresViewModel(
            aporte: aporte(factores: [("tu glucosa de ahora", 12)]),
            valorPropioMgDl: 142,
            objetivo: base
        )
        #expect(delModelo.explicacion == "Vas a bajar un poco.")
        #expect(delModelo.origenDeLaFrase?.contains("asistente") == true)

        let deLaPlantilla = FactoresViewModel(
            aporte: aporte(
                factores: [("tu glucosa de ahora", 12)], deLaPlantilla: true
            ),
            valorPropioMgDl: 142,
            objetivo: base
        )
        #expect(deLaPlantilla.origenDeLaFrase?.contains("la app") == true)

        // Sin frase no se dice de dónde no salió.
        let sinFrase = FactoresViewModel(
            aporte: aporte(factores: [("tu glucosa de ahora", 12)], explicacion: nil),
            valorPropioMgDl: 142,
            objetivo: base
        )
        #expect(sinFrase.explicacion == nil)
        #expect(sinFrase.origenDeLaFrase == nil)
    }

    @Test("Cuando no hay factores, la pantalla dice por qué en lugar de quedarse en blanco")
    func dicePorQueNoHayNada() {
        // Nada llegó todavía.
        let sinNada = FactoresViewModel(aporte: nil, valorPropioMgDl: 142, objetivo: base)
        #expect(sinNada.renglones.isEmpty)
        #expect(sinNada.porQueNoHayNada?.contains("servidor") == true)

        // Llegó la respuesta y venía sin factores.
        let sinFactores = FactoresViewModel(
            aporte: aporte(factores: []), valorPropioMgDl: 142, objetivo: base
        )
        #expect(sinFactores.porQueNoHayNada?.contains("sin factores") == true)

        // Llegaron con el nombre de la columna del modelo: es un error del servidor y no se
        // disimula inventando una traducción.
        let sinTraducir = FactoresViewModel(
            aporte: aporte(factores: [("rezago_45", -3), ("iob", -8)]),
            valorPropioMgDl: 142,
            objetivo: base
        )
        #expect(sinTraducir.renglones.isEmpty)
        #expect(sinTraducir.porQueNoHayNada?.contains("sin traducir") == true)
    }

    @Test("El desacuerdo entre los dos caminos se dice aquí y no en la pantalla de inicio")
    func elDesacuerdoSeDiceAqui() {
        let conDesacuerdo = FactoresViewModel(
            aporte: aporte(
                factores: [("tu glucosa de ahora", 12)],
                desacuerdoMgDl: 4,
                valorDelServidorMgDl: 146
            ),
            valorPropioMgDl: 142,
            objetivo: base
        )
        let texto = conDesacuerdo.desacuerdo
        #expect(texto?.contains("146 mg/dL") == true)
        #expect(texto?.contains("4 de diferencia") == true)
        // Y dice cuál se enseña, que es la propia.
        #expect(texto?.contains("su propia") == true)

        // Sin desacuerdo no se dice nada: no hay nada que contar.
        let sinDesacuerdo = FactoresViewModel(
            aporte: aporte(factores: [("tu glucosa de ahora", 12)]),
            valorPropioMgDl: 142,
            objetivo: base
        )
        #expect(sinDesacuerdo.desacuerdo == nil)
    }

    @Test("La cifra con signo se arma en un solo lugar")
    func laCifraConSigno() {
        #expect(FactoresViewModel.cifra(12.5) == "+13 mg/dL")
        #expect(FactoresViewModel.cifra(-20) == "−20 mg/dL")
        // Una contribución diminuta sale como «+0 mg/dL» y no se esconde: que el modelo
        // apenas la tomara en cuenta es información, no un hueco.
        #expect(FactoresViewModel.cifra(0.4) == "+0 mg/dL")
        #expect(FactoresViewModel.cifra(-0.4) == "−0 mg/dL")
    }
}
