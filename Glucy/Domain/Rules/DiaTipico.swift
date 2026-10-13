import Foundation

/// Lo que pasa en una hora del día a lo largo del periodo.
nonisolated struct HoraTipica: Sendable, Equatable, Identifiable {
    var id: Int { hora }
    /// 0 a 23, hora local de la zona guardada en cada lectura.
    let hora: Int
    let mediana: Double
    let p25: Double
    let p75: Double
    let n: Int
}

/// El día típico: mediana y cuartiles de la glucosa, hora por hora (RF-16).
///
/// Es la única regla clínica que no tiene todavía su par en `referencia/reglas_clinicas.py`:
/// cuando la fase 2 la escriba en Python tiene que dar estos mismos números.
nonisolated enum DiaTipico {

    /// Las horas que tienen suficientes lecturas, ordenadas. Las que no, no aparecen: un
    /// hueco en el día típico es información, y rellenarlo sería inventar.
    ///
    /// Cada lectura cae en la hora local **de la zona que se guardó con ella**, no en la de
    /// UTC ni en la de hoy (regla 5): si no, un viaje movería el historial entero y el día
    /// típico de quien viajó dejaría de describir su día.
    static func calcular(
        lecturas: [LecturaGlucosaDato],
        minimoPorHora: Int = ConfiguracionDominio.lecturasMinimasPorHora
    ) -> [HoraTipica] {
        var porHora: [Int: [Double]] = [:]
        for lectura in lecturas {
            porHora[horaLocal(de: lectura), default: []].append(lectura.mgDl)
        }

        return porHora
            // Con menos del mínimo no hay cuartil que valga. No se interpola con la hora de
            // al lado ni se arrastra la anterior.
            .filter { $0.value.count >= max(minimoPorHora, 1) }
            .compactMap { hora, valores in
                guard let mediana = percentil(50, de: valores),
                      let p25 = percentil(25, de: valores),
                      let p75 = percentil(75, de: valores) else { return nil }
                return HoraTipica(hora: hora, mediana: mediana, p25: p25, p75: p75, n: valores.count)
            }
            .sorted { $0.hora < $1.hora }
    }

    /// Percentil con interpolación lineal, la definición por omisión de `numpy.percentile`.
    /// Expuesto porque es lo que las pruebas fijan contra valores calculados a mano.
    ///
    /// Hay nueve definiciones de percentil en uso y con listas cortas no dan lo mismo: esta
    /// ordena, toma la posición `p / 100 × (n − 1)` y, si cae entre dos índices, interpola.
    ///
    /// - Parameter p: de 0 a 100.
    static func percentil(_ p: Double, de valores: [Double]) -> Double? {
        guard !valores.isEmpty, (0...100).contains(p) else { return nil }
        let ordenados = valores.sorted()
        let posicion = p / 100 * Double(ordenados.count - 1)
        let abajo = Int(posicion.rounded(.down))
        let arriba = Int(posicion.rounded(.up))
        guard abajo != arriba else { return ordenados[abajo] }
        return ordenados[abajo] + (ordenados[arriba] - ordenados[abajo]) * (posicion - Double(abajo))
    }

    /// El día local de una lectura, en su propia zona. Sirve para contar en cuántos días
    /// distintos hay mediciones.
    static func diaLocal(de lectura: LecturaGlucosaDato) -> DateComponents {
        calendario(de: lectura).dateComponents([.year, .month, .day], from: lectura.tsUtc)
    }

    private static func horaLocal(de lectura: LecturaGlucosaDato) -> Int {
        calendario(de: lectura).component(.hour, from: lectura.tsUtc)
    }

    private static func calendario(de lectura: LecturaGlucosaDato) -> Calendar {
        var calendario = Calendar(identifier: .gregorian)
        // Un identificador ilegible no puede tumbar el historial: esa lectura se agrupa por
        // UTC, que es lo único que se sabe de ella con certeza.
        calendario.timeZone = TimeZone(identifier: lectura.zonaHoraria) ?? .gmt
        return calendario
    }
}
