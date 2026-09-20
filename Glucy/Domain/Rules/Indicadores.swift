import Foundation

/// Indicadores clínicos de un periodo. Se calculan en el teléfono, sin backend.
nonisolated struct Indicadores: Equatable, Sendable {
    /// Sobre cuántas lecturas se calculó. La pantalla lo dice siempre: una cifra sobre
    /// cuatro lecturas engaña.
    let n: Int
    let tir: Double          // % dentro del rango objetivo 70–180
    let tbr: Double          // % por debajo del umbral de hipoglucemia del perfil
    let tar: Double          // % por encima del umbral de hiperglucemia del perfil
    let promedio: Double
    let desviacion: Double
    let coeficienteVariacion: Double
    let gmi: Double
}

nonisolated enum CalculoIndicadores {

    /// Devuelve `nil` con la lista vacía: la pantalla tiene que decir que faltan datos,
    /// no mostrar cero. Un cero aquí se lee como «todo el tiempo fuera de rango».
    ///
    /// El TIR se mide siempre contra el rango objetivo fijo 70–180 aunque el perfil haya
    /// movido sus umbrales; los umbrales del perfil solo mueven el TBR y el TAR.
    ///
    /// La desviación es **poblacional** (se divide entre `n`, no entre `n − 1`), igual que
    /// en la referencia de glucy-backend.
    static func calcular(
        valores: [Double],
        umbralHipo: Double = ConfiguracionDominio.umbralHipoPorOmision,
        umbralHiper: Double = ConfiguracionDominio.umbralHiperPorOmision
    ) -> Indicadores? {
        guard !valores.isEmpty else { return nil }

        let n = valores.count
        let cuenta = Double(n)
        let promedio = valores.reduce(0, +) / cuenta
        let varianza = valores.reduce(0) { $0 + ($1 - promedio) * ($1 - promedio) } / cuenta
        let desviacion = varianza.squareRoot()

        let objetivo = ConfiguracionDominio.rangoObjetivo
        // `count(where:)` pide iOS 18; el objetivo mínimo es 17.0.
        let enRango = valores.filter { objetivo.contains($0) }.count
        let porDebajo = valores.filter { $0 < umbralHipo }.count
        let porEncima = valores.filter { $0 > umbralHiper }.count

        return Indicadores(
            n: n,
            tir: 100 * Double(enRango) / cuenta,
            tbr: 100 * Double(porDebajo) / cuenta,
            tar: 100 * Double(porEncima) / cuenta,
            promedio: promedio,
            desviacion: desviacion,
            coeficienteVariacion: promedio == 0 ? 0 : 100 * desviacion / promedio,
            gmi: ConfiguracionDominio.gmiIntercepto
                + ConfiguracionDominio.gmiPendiente * promedio
        )
    }
}
