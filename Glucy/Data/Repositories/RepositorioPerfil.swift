import Foundation

/// El perfil de la persona. Hay uno solo.
///
/// No tiene `encolar` ni devuelve `Bool`: el perfil nace `local` y no sube nunca, porque
/// lo que identifica a la persona no sale del teléfono (regla 3).
nonisolated protocol RepositorioPerfil: Sendable {
    /// `nil` mientras la persona no haya pasado por el alta.
    func actual() async throws -> PerfilDato?

    /// Crea el perfil o actualiza el que ya existe. Siempre queda en `.local`.
    func guardar(_ dato: PerfilDato) async throws

    func existe() async throws -> Bool
}
