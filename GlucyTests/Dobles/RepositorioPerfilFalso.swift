import Foundation
@testable import Glucy

/// Un repositorio de perfil de mentira: el perfil que se le dé, o ninguno.
actor RepositorioPerfilFalso: RepositorioPerfil {
    private var guardado: PerfilDato?

    init(_ perfil: PerfilDato? = nil) {
        guardado = perfil
    }

    func actual() async throws -> PerfilDato? {
        guardado
    }

    func guardar(_ dato: PerfilDato) async throws {
        guardado = dato
    }

    func existe() async throws -> Bool {
        guardado != nil
    }

    func eliminarTodo() async throws {
        guardado = nil
    }
}
