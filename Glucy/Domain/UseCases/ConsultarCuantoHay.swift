import Foundation

/// Lo que hay guardado, en números. Es lo que el borrado de la cuenta enumera.
nonisolated struct CuantoHay: Sendable, Equatable {
    let lecturas: Int
    let comidas: Int
    let dosis: Int
}

/// Las cifras de verdad, leídas de la base: un «¿estás seguro?» sin cifras no informa de
/// nada.
nonisolated struct ConsultarCuantoHay: Sendable {
    let lecturas: any RepositorioLecturas
    let comidas: any RepositorioComidas
    let dosis: any RepositorioDosis

    func ejecutar() async throws -> CuantoHay {
        CuantoHay(
            lecturas: try await lecturas.contar(),
            comidas: try await comidas.contar(),
            dosis: try await dosis.contar()
        )
    }
}
