import Foundation
@testable import Glucy

/// Lo que comparten las pruebas que miran qué va a dibujar la pantalla de inicio:
/// `ConsultarInicio` montado sobre repositorios de mentira.
///
/// **No se construye aquí ningún doble que sea un `actor` con argumentos por omisión en su
/// init.** `RepositorioPerfilFalso` vive en este mismo lote de compilación, y llamar a su init
/// sin argumentos desde aquí hizo que el compilador quisiera marcarlo `nonisolated`:
/// «'nonisolated' on an actor's synchronous initializer is invalid», señalando el archivo del
/// init y no el de la llamada. Los dobles que estas pruebas necesitan llegan por parámetro.
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
        // El perfil se pasa tal cual, sin fabricar uno de mentira cuando no lo hay: los dos
        // lo reciben opcional. Aquí había un `RepositorioPerfilFalso()` y ese era el error de
        // aislamiento del paso 11 —ver el comentario de arriba del archivo.
        return try await ConsultarInicio(
            lecturas: lecturas,
            modo: ConsultarModo(lecturas: lecturas),
            carbohidratosActivos: CalcularCarbohidratosActivos(comidas: comidas),
            insulinaActiva: CalcularInsulinaActiva(dosis: dosis),
            perfil: perfil,
            predecir: CalcularPrediccion(
                lecturas: lecturas, comidas: comidas, dosis: dosis,
                perfil: perfil, modelos: modelos
            )
        ).ejecutar(lecturaHealthKitActiva: lecturaHealthKitActiva, ahora: ahora)
    }
}
