import Foundation

/// Un renglón de la pantalla de factores, ya formateado.
nonisolated struct RenglonDeFactor: Sendable, Equatable, Identifiable {
    var id: String { nombre }
    let nombre: String
    /// Por ejemplo «+12 mg/dL» o «−20 mg/dL». Con su signo y su unidad, siempre.
    let cifra: String
    let sube: Bool
    /// Entre 0 y 1, para el ancho de la barra. El más grande llena la barra entera y los
    /// demás se miden contra él.
    let proporcion: Double
    /// Lo que lee VoiceOver, con la palabra en lugar del signo.
    let hablado: String
}

/// Lo que dibuja la pantalla de factores.
///
/// No pide nada: recibe lo que la pantalla de inicio ya tenía. Abrir esta pantalla no hace una
/// llamada más, y por eso se abre al instante incluso sin red.
@Observable
final class FactoresViewModel {
    private let aporte: FactoresYExplicacion?
    private let valorPropioMgDl: Double?
    private let objetivo: Date?

    init(
        aporte: FactoresYExplicacion?,
        valorPropioMgDl: Double? = nil,
        objetivo: Date? = nil
    ) {
        self.aporte = aporte
        self.valorPropioMgDl = valorPropioMgDl
        self.objetivo = objetivo
    }

    /// La cifra protagonista: la estimación del teléfono, que es la que la pantalla de inicio
    /// enseña. Un dato y una acción por pantalla.
    var cifra: String? {
        guard let valorPropioMgDl else { return nil }
        return "\(Int(valorPropioMgDl.rounded())) mg/dL"
    }

    var cuando: String? {
        guard let objetivo else { return nil }
        return "a las \(objetivo.formatted(date: .omitted, time: .shortened))"
    }

    /// La frase en español llano, cuando llegó.
    var explicacion: String? { aporte?.explicacion }

    /// De dónde salió la frase, dicho en una línea. Se dice porque una explicación armada por
    /// plantilla y una escrita por el modelo no valen lo mismo, y la persona tiene derecho a
    /// saber cuál está leyendo.
    var origenDeLaFrase: String? {
        guard aporte?.explicacion != nil else { return nil }
        return aporte?.deLaPlantilla == true
            ? "Texto armado por la app, sin el asistente."
            : "Texto escrito por el asistente a partir de estos números."
    }

    var renglones: [RenglonDeFactor] {
        let factores = aporte?.paraLaPantalla ?? []
        let mayor = factores.map { abs($0.mgDl) }.max() ?? 0
        return factores.map { factor in
            RenglonDeFactor(
                nombre: factor.nombre,
                cifra: Self.cifra(factor.mgDl),
                sube: factor.sube,
                proporcion: mayor > 0 ? abs(factor.mgDl) / mayor : 0,
                hablado: "\(factor.nombre): \(factor.sube ? "sube" : "baja") "
                    + "\(Int(abs(factor.mgDl).rounded())) mg/dL"
            )
        }
    }

    /// La línea que sale cuando no hay factores que enseñar. Dice por qué, en lugar de dejar
    /// la pantalla en blanco: un hueco sin explicación se lee como una falla de la app.
    var porQueNoHayNada: String? {
        guard renglones.isEmpty else { return nil }
        guard let aporte else {
            return "Los factores los calcula el servidor de Glucy. Todavía no han llegado; "
                + "la estimación de arriba no depende de ellos."
        }
        if aporte.factores.isEmpty {
            return "El servidor respondió sin factores esta vez."
        }
        // Llegaron factores y ninguno se puede enseñar: vinieron con el nombre de la columna
        // del modelo en lugar de en palabras. Es un error del servidor y no se disimula
        // inventando una traducción.
        return "El servidor mandó los factores sin traducir, así que no se enseñan."
    }

    /// El desacuerdo entre los dos caminos, cuando lo hay. Se dice en la pantalla de factores
    /// y no en la de inicio: no cambia qué tiene que hacer la persona, y en la pantalla que
    /// alguien mira a las tres de la mañana no cabe nada que no cambie una decisión.
    var desacuerdo: String? {
        guard let diferencia = aporte?.desacuerdoMgDl, let delServidor = aporte?.valorDelServidorMgDl
        else { return nil }
        return "El servidor estimó \(Int(delServidor.rounded())) mg/dL, "
            + "\(Int(diferencia.rounded())) de diferencia. La app enseña su propia "
            + "estimación, que es la que calculó con tus lecturas."
    }

    /// Con signo y con unidad, y el signo menos de verdad y no un guion: se lee distinto en
    /// VoiceOver y se ve distinto en una pantalla chica.
    static func cifra(_ mgDl: Double) -> String {
        let redondeada = Int(abs(mgDl).rounded())
        return "\(mgDl > 0 ? "+" : "−")\(redondeada) mg/dL"
    }
}
