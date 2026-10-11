import Foundation

/// Lo que el registro de insulina necesita saber del perfil.
///
/// Mientras no exista el alta del perfil (paso 9) no hay perfil guardado, y los dos valores
/// salen de su valor por omisión. Tampoco lanza: si el perfil no se puede leer, la pantalla
/// de registro tiene que seguir funcionando.
nonisolated struct ConsultarAjustesDeInsulina: Sendable {
    let perfil: any RepositorioPerfil

    /// RF-14: quien no se aplica insulina puede ocultar su registro. Sin perfil se muestra,
    /// porque el usuario principal es quien sí la usa.
    func registraInsulina() async -> Bool {
        (try? await perfil.actual())?.registraInsulina ?? true
    }

    /// La duración de acción vigente hoy, que es la que se guarda con cada dosis nueva.
    func duracionAccionH() async -> Double {
        (try? await perfil.actual())?.duracionAccionInsulinaH
            ?? ConfiguracionDominio.duracionAccionPorOmisionH
    }
}
