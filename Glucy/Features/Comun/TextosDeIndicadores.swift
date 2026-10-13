import Foundation

/// Las frases que acompañan a las tres cifras del periodo. Viven juntas porque la pantalla de
/// Historial y el informe tienen que decir exactamente lo mismo ante el mismo dato.
nonisolated enum TextosDeIndicadores {
    static let faltanDias = "Necesito al menos tres días de datos para calcular tu tiempo en rango."

    static var gmiNoFiable: String {
        "Esta estimación necesita al menos \(ConfiguracionDominio.diasMinimosGmi) "
            + "días de mediciones para significar algo."
    }

    static func diasQueLlevas(_ dias: Int) -> String {
        dias == 1 ? "Llevas 1 día con mediciones." : "Llevas \(dias) días con mediciones."
    }

    static func sobre(_ mediciones: Int) -> String {
        mediciones == 1 ? "sobre 1 medición" : "sobre \(mediciones) mediciones"
    }

    static func dias(_ dias: Int) -> String {
        dias == 1 ? "1 día" : "\(dias) días"
    }

    static func entero(_ valor: Double) -> String {
        String(Int(valor.rounded()))
    }
}
