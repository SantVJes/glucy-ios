import Foundation

/// La última predicción de cada horizonte, con lo que el servidor aportó sobre ella.
///
/// Es caché y se porta como caché: hay **una fila por horizonte** y la nueva reemplaza a la
/// vieja. No es un histórico; el histórico de predicciones vive en el backend, que es quien
/// las compara después contra lo que de verdad pasó (RF-25).
///
/// Lo que gana la pantalla: al siguiente arranque la frase y los factores se pintan al
/// instante, sin red y sin volver a preguntar. Sin esto, abrir la app en el metro deja la
/// explicación en blanco aunque el número salga.
nonisolated protocol RepositorioPrediccionCache: Sendable {
    /// Guarda o reemplaza la fila de ese horizonte.
    func guardar(_ dato: PrediccionGuardadaDato) async throws

    func ultima(horizonteMin: Int) async throws -> PrediccionGuardadaDato?

    func todas() async throws -> [PrediccionGuardadaDato]

    /// Borra todas las filas. Lo llama el borrado de la cuenta, y también sirve cuando el
    /// artefacto cambia de versión: una explicación de un modelo que ya no corre no explica
    /// la predicción que la pantalla enseña.
    func eliminarTodo() async throws
}

/// Una predicción guardada, como valor.
nonisolated struct PrediccionGuardadaDato: Sendable, Equatable {
    let uuid: UUID
    /// Cuándo se calculó, no para cuándo es.
    let tsUtc: Date
    /// Identificador de `TimeZone` (regla 5).
    let zonaHoraria: String
    let horizonteMin: Int
    /// El número del teléfono, que es el que la pantalla enseña (C-16).
    let valorMgDl: Double
    let modo: ModoApp
    let versionModelo: String
    let explicacion: String?
    let factores: [FactorDeLaPrediccion]
    let shap: [ContribucionDeLaPrediccion]

    init(
        uuid: UUID = UUID(),
        tsUtc: Date,
        zonaHoraria: String = TimeZone.current.identifier,
        horizonteMin: Int,
        valorMgDl: Double,
        modo: ModoApp,
        versionModelo: String,
        explicacion: String? = nil,
        factores: [FactorDeLaPrediccion] = [],
        shap: [ContribucionDeLaPrediccion] = []
    ) {
        self.uuid = uuid
        self.tsUtc = tsUtc
        self.zonaHoraria = zonaHoraria
        self.horizonteMin = horizonteMin
        self.valorMgDl = valorMgDl
        self.modo = modo
        self.versionModelo = versionModelo
        self.explicacion = explicacion
        self.factores = factores
        self.shap = shap
    }
}

/// Cómo viajan los factores y las contribuciones dentro del único campo de texto que el
/// modelo ya tenía.
///
/// Van los dos en el mismo JSON porque los dos hacen falta y por una razón que vale decir:
/// **este paso no lleva migración**. `PrediccionCache.shapJson` ya existía, así que las dos
/// listas se serializan ahí en lugar de agregar una columna. Los factores son lo que la
/// pantalla dibuja; las contribuciones son lo que `POST /explain` necesita recibir si hay que
/// volver a pedir la frase.
nonisolated struct FactoresSerializados: Codable, Sendable, Equatable {
    /// Pares nombre/valor. Se guarda como dos listas de lo mismo y no como el tipo del
    /// dominio para que un cambio del tipo no deje ilegible lo que ya está en disco.
    let factores: [Par]
    let shap: [ContribucionDeLaPrediccion]

    struct Par: Codable, Sendable, Equatable {
        let nombre: String
        let mgDl: Double
    }

    init(factores: [FactorDeLaPrediccion], shap: [ContribucionDeLaPrediccion]) {
        self.factores = factores.map { Par(nombre: $0.nombre, mgDl: $0.mgDl) }
        self.shap = shap
    }

    var comoFactores: [FactorDeLaPrediccion] {
        factores.map { FactorDeLaPrediccion(nombre: $0.nombre, mgDl: $0.mgDl) }
    }

    /// El JSON, o `nil` si no hay nada que guardar. Que no se pueda serializar no es motivo
    /// para que la predicción no se guarde: la cifra vale aunque la explicación no esté.
    static func json(factores: [FactorDeLaPrediccion], shap: [ContribucionDeLaPrediccion])
        -> String?
    {
        guard !factores.isEmpty || !shap.isEmpty else { return nil }
        let serializado = FactoresSerializados(factores: factores, shap: shap)
        guard let datos = try? JSONEncoder().encode(serializado) else { return nil }
        return String(data: datos, encoding: .utf8)
    }

    static func desde(json: String?) -> FactoresSerializados? {
        guard let json, let datos = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(FactoresSerializados.self, from: datos)
    }
}
