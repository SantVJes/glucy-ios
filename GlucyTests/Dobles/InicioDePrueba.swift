import Foundation
@testable import Glucy

/// Lo que comparten las pruebas que miran qué va a dibujar la pantalla de inicio:
/// `ConsultarInicio` montado sobre repositorios de mentira.
enum InicioDePrueba {
    static let ahora = Date(timeIntervalSince1970: 1_758_240_000)

    static func guardar(
        _ mgDl: Double, haceMin minutos: Double, origen: Origen, en lecturas: RepositorioLecturasFalso
    ) async throws {
        try await lecturas.guardar(LecturaGlucosaDato(
            mgDl: mgDl, tsUtc: ahora.addingTimeInterval(-minutos * 60), origen: origen
        ))
    }

    /// - Parameter modelos: vacío por omisión, y entonces no hay predicción y el estado lo
    ///   dice. Las pruebas que miran la línea punteada pasan un `ModeloFalso`.
    static func estado(
        lecturas: any RepositorioLecturas,
        comidas: any RepositorioComidas,
        dosis: any RepositorioDosis,
        lecturaHealthKitActiva: Bool,
        modelos: [any RepositorioModelo] = [],
        perfil: (any RepositorioPerfil)? = nil
    ) async throws -> EstadoInicio {
        try await ConsultarInicio(
            lecturas: lecturas,
            modo: ConsultarModo(lecturas: lecturas),
            carbohidratosActivos: CalcularCarbohidratosActivos(comidas: comidas),
            insulinaActiva: CalcularInsulinaActiva(dosis: dosis),
            perfil: perfil,
            predecir: CalcularPrediccion(
                lecturas: lecturas, comidas: comidas, dosis: dosis,
                perfil: perfil ?? RepositorioPerfilFalso(), modelos: modelos
            )
        ).ejecutar(lecturaHealthKitActiva: lecturaHealthKitActiva, ahora: ahora)
    }
}
