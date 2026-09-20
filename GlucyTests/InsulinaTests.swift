import Testing
@testable import Glucy

/// Insulina activa. La curva tiene que dar exactamente lo mismo que
/// `fraccion_insulina_activa` de `referencia/reglas_clinicas.py`.
struct InsulinaTests {

    @Test("La fracción activa decrece y se agota al llegar a la DIA")
    func iobDecreceYSeAgotaEnLaDIA() {
        #expect(Insulina.fraccionActiva(minutos: 0) == 1)
        #expect(Insulina.fraccionActiva(minutos: 300) == 0)
        #expect(Insulina.fraccionActiva(minutos: 400) == 0)

        // Monótona decreciente a lo largo de toda la DIA.
        var anterior = 1.0
        for minutos in stride(from: 5.0, through: 300.0, by: 5.0) {
            let actual = Insulina.fraccionActiva(minutos: minutos)
            #expect(actual <= anterior)
            #expect(actual >= 0)
            anterior = actual
        }
    }

    @Test("Con una DIA más larga queda más insulina activa a la misma hora")
    func diaMasLargaDejaMasInsulinaActiva() {
        let conCinco = Insulina.fraccionActiva(minutos: 120, diaH: 5)
        let conOcho = Insulina.fraccionActiva(minutos: 120, diaH: 8)
        #expect(conOcho > conCinco)
    }

    /// Si estos números se mueven, el Swift y la referencia dejaron de coincidir.
    @Test("La curva coincide valor por valor con la referencia de glucy-backend")
    func curvaIdenticaALaReferencia() {
        let esperados: [(minutos: Double, fraccion: Double)] = [
            (30, 0.9249701856314995),
            (75, 0.6726398904581075),
            (120, 0.41057994214803406),
            (180, 0.15879641537283806),
            (240, 0.032924868796628814)
        ]
        for caso in esperados {
            let obtenido = Insulina.fraccionActiva(minutos: caso.minutos)
            #expect(abs(obtenido - caso.fraccion) < 1e-12)
        }

        #expect(abs(Insulina.fraccionActiva(minutos: 120, diaH: 8) - 0.48820220735619757) < 1e-12)
    }

    @Test("El IOB suma cada dosis por su fracción restante")
    func iobSumaCadaDosis() {
        // Referencia: iob([(6, 60), (2, 120)]) = 5.405194105642365
        let total = Insulina.iob(dosis: [(unidades: 6, minutos: 60), (unidades: 2, minutos: 120)])
        #expect(abs(total - 5.405194105642365) < 1e-12)
    }

    @Test("Sin dosis registradas el IOB es cero")
    func iobSinDosisEsCero() {
        #expect(Insulina.iob(dosis: []) == 0)
    }
}
