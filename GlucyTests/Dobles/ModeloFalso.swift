import Foundation
@testable import Glucy

/// Un modelo de mentira, para probar el caso de uso sin Core ML.
///
/// Lo que importa de él es que **guarda el vector que recibió**: la comprobación que vale en
/// `CalcularPrediccionTests` no es qué número devolvió, es con qué fila se le llamó. Una fila
/// armada en el instante equivocado produce un número plausible, y ese es justo el fallo que
/// no se ve.
actor ModeloFalso: RepositorioModelo {
    nonisolated let descrito: ModeloDescrito
    private let respuesta: Result<Double, ErrorModelo>
    private(set) var recibidos: [[String: Double]] = []

    init(
        horizonteMin: Int = 30,
        version: String = "v0.0.0-prueba",
        devuelve: Result<Double, ErrorModelo> = .success(120)
    ) {
        descrito = ModeloDescrito(
            version: version,
            horizonteMin: horizonteMin,
            caracteristicas: VectorDeCaracteristicas.densas,
            metricasSePuedenReportar: false
        )
        respuesta = devuelve
    }

    func predecir(_ vector: [String: Double]) async throws -> Double {
        recibidos.append(vector)
        return try respuesta.get()
    }

    var ultimoVector: [String: Double]? { recibidos.last }
}
