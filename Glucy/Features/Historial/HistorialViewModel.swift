import Foundation

/// El estado de la pantalla de historial.
///
/// **No decide cuándo se enseña cada cifra**: eso viene resuelto de `ConsultarHistorial`.
/// Aquí solo se elige el periodo y se le da forma de texto a lo que llega.
@Observable
final class HistorialViewModel {

    private(set) var periodoDias = ConfiguracionDominio.periodosHistorialDias[0]
    /// `nil` hasta la primera respuesta. Al cambiar de periodo se queda el anterior hasta
    /// que llega el nuevo: la pantalla no se vacía para volver a llenarse.
    private(set) var estado: EstadoHistorial?
    private(set) var cargado = false

    let periodos = ConfiguracionDominio.periodosHistorialDias

    private let consultar: ConsultarHistorial

    init(consultar: ConsultarHistorial) {
        self.consultar = consultar
    }

    func elegir(periodo: Int, ahora: Date = Date()) async {
        periodoDias = periodo
        await ponerAlDia(ahora: ahora)
    }

    func ponerAlDia(ahora: Date = Date()) async {
        defer { cargado = true }
        if let nuevo = try? await consultar.ejecutar(periodoDias: periodoDias, ahora: ahora) {
            estado = nuevo
        }
    }

    var sinRespuesta: Bool {
        cargado && estado == nil
    }

    // MARK: - Textos

    /// Cuando no se llega a los tres días: qué falta y cuánto se lleva. Ningún cero.
    var textoDiasQueLlevas: String {
        let dias = estado?.diasConLecturas ?? 0
        return dias == 1 ? "Llevas 1 día con mediciones." : "Llevas \(dias) días con mediciones."
    }

    var textoTiempoEnRango: String? {
        estado?.indicadores.map { "\(Self.entero($0.tir)) %" }
    }

    var pieTiempoEnRango: String {
        "\(sobreCuantas) de \(textoDias(estado?.diasConLecturas ?? 0))"
    }

    var textoPromedio: String? {
        estado?.indicadores.map { Self.entero($0.promedio) }
    }

    var piePromedio: String { sobreCuantas }

    /// El GMI o, mientras no signifique nada, cuántos días le faltan.
    var textoGmi: String? {
        guard let estado, let indicadores = estado.indicadores else { return nil }
        guard estado.gmiEsFiable else {
            let faltan = ConfiguracionDominio.diasMinimosGmi - estado.diasConLecturas
            return faltan == 1 ? "Me falta 1 día" : "Me faltan \(faltan) días"
        }
        return "\(String(format: "%.1f", indicadores.gmi)) %"
    }

    var pieGmi: String {
        guard estado?.gmiEsFiable == true else {
            return "Esta estimación necesita al menos \(ConfiguracionDominio.diasMinimosGmi) "
                + "días de mediciones para significar algo."
        }
        return "estimación de tu A1c · \(sobreCuantas)"
    }

    var contenidoDelDiaTipico: ContenidoGrafica {
        .diaTipico(estado?.diaTipico ?? [])
    }

    /// `nil` cuando las 24 horas tienen datos: no hay nada que advertir.
    var pieDelDiaTipico: String? {
        guard let horas = estado?.horasSinDatos, horas > 0 else { return nil }
        let primera = horas == 1
            ? "1 de las 24 horas no tiene suficientes mediciones y se queda en blanco."
            : "\(horas) de las 24 horas no tienen suficientes mediciones y se quedan en blanco."
        return "\(primera) No las relleno: sería inventar."
    }

    var resumenDelDiaTipico: String {
        let horas = estado?.diaTipico ?? []
        let periodo = "Tu día típico de los últimos \(periodoDias) días"
        guard let minimo = horas.map(\.mediana).min(), let maximo = horas.map(\.mediana).max() else {
            return "\(periodo): ninguna hora tiene suficientes mediciones todavía."
        }
        let pie = pieDelDiaTipico.map { " \($0)" } ?? ""
        return "\(periodo): la mediana va de \(Self.entero(minimo)) a \(Self.entero(maximo)) "
            + "miligramos por decilitro.\(pie)"
    }

    func titulo(delPeriodo dias: Int) -> String {
        "\(dias) días"
    }

    // MARK: - Formato

    private var sobreCuantas: String {
        let n = estado?.indicadores?.n ?? 0
        return n == 1 ? "sobre 1 medición" : "sobre \(n) mediciones"
    }

    private func textoDias(_ dias: Int) -> String {
        dias == 1 ? "1 día" : "\(dias) días"
    }

    static func entero(_ valor: Double) -> String {
        String(Int(valor.rounded()))
    }
}
