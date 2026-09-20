import Testing
@testable import Glucy

/// TIR, TBR, TAR, promedio, desviación, CV y GMI.
struct IndicadoresTests {

    /// El TIR se mide contra 70–180 fijos: moverlo haría incomparables los números con
    /// cualquier otra fuente clínica.
    @Test("Los umbrales del perfil mueven el TBR y el TAR, nunca el TIR")
    func indicadoresConUmbralesMovidos() throws {
        let i = try #require(
            CalculoIndicadores.calcular(valores: [80, 100, 160], umbralHipo: 90, umbralHiper: 150)
        )
        #expect(i.n == 3)
        #expect(i.tir == 100)                              // los tres están entre 70 y 180
        #expect(abs(i.tbr - 100.0 / 3) < 1e-9)             // solo el 80 está bajo 90
        #expect(abs(i.tar - 100.0 / 3) < 1e-9)             // solo el 160 está sobre 150
        #expect(abs(i.promedio - 113.33333333333333) < 1e-9)
        #expect(abs(i.desviacion - 33.9934634239519) < 1e-9)
        #expect(abs(i.coeficienteVariacion - 29.994232432898738) < 1e-9)
    }

    @Test("El GMI usa la fórmula del consenso: 3.31 + 0.02392 × promedio")
    func gmiUsaLaFormulaDelConsenso() throws {
        let i = try #require(CalculoIndicadores.calcular(valores: [154]))
        #expect(abs(i.gmi - 6.9936799999999995) < 1e-9)
        #expect(abs(i.gmi - 7.0) < 0.01)
    }

    /// Un cero aquí se leería como «todo el tiempo fuera de rango».
    @Test("Sin lecturas no hay indicadores: la pantalla dice que faltan datos")
    func sinLecturasNoHayIndicadores() {
        #expect(CalculoIndicadores.calcular(valores: []) == nil)
    }

    @Test("Con los umbrales por omisión los porcentajes coinciden con la referencia")
    func indicadoresConUmbralesPorOmision() throws {
        let i = try #require(CalculoIndicadores.calcular(valores: [70, 100, 180, 200, 50]))
        #expect(i.n == 5)
        #expect(i.tir == 60)   // 70, 100 y 180 caen dentro del rango objetivo, bordes incluidos
        #expect(i.tbr == 20)   // solo el 50
        #expect(i.tar == 20)   // solo el 200; el 180 no está «por encima» de 180
        #expect(abs(i.promedio - 120) < 1e-9)
        #expect(abs(i.desviacion - 59.665735560705194) < 1e-9)
        #expect(abs(i.coeficienteVariacion - 49.721446300587665) < 1e-9)
        #expect(abs(i.gmi - 6.180400000000001) < 1e-9)
    }

    /// Poblacional: se divide entre n, no entre n − 1, igual que en la referencia.
    @Test("La desviación es poblacional")
    func desviacionPoblacional() throws {
        let i = try #require(CalculoIndicadores.calcular(valores: [100, 200]))
        #expect(abs(i.desviacion - 50) < 1e-9)  // entre n − 1 daría 70.71
    }
}
