import Foundation

/// Lo que la raíz de la app necesita saber para decidir qué enseña.
nonisolated struct EstadoDeEntrada: Sendable, Equatable {
    /// La puerta de la app. **No es «existe un perfil»**: un perfil sin consentimiento no
    /// deja entrar, porque guardar datos de salud sin él no tiene base legal (LFPDPPP).
    let consintio: Bool
    let bloqueoBiometrico: Bool
}

/// Si la persona ya dio su consentimiento y si pidió el candado.
nonisolated struct ConsultarEntrada: Sendable {
    let perfil: any RepositorioPerfil

    /// No lanza. Si el perfil no se puede leer, no se puede afirmar que haya consentido.
    func ejecutar() async -> EstadoDeEntrada {
        let actual = try? await perfil.actual()
        return EstadoDeEntrada(
            consintio: actual?.consentimientoTsUtc != nil,
            bloqueoBiometrico: actual?.bloqueoBiometrico ?? false
        )
    }
}
