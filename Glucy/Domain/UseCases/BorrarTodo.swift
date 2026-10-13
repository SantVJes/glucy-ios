import Foundation

/// Cómo terminó el borrado de la cuenta.
nonisolated struct ResultadoDeBorrado: Sendable, Equatable {
    /// `false` si Salud falló. Lo local ya se borró igual, y la pantalla lo dice.
    let saludLimpia: Bool
}

/// Borrar la cuenta: la única acción irreversible de la app.
///
/// No hay cuenta en ningún servidor: «borrar mi cuenta» borra lo que hay en el teléfono y lo
/// que Glucy escribió en Salud. Lo que escribió la app del sensor no se toca (RF-15b).
nonisolated struct BorrarTodo: Sendable {
    let perfil: any RepositorioPerfil
    let lecturas: any RepositorioLecturas
    let comidas: any RepositorioComidas
    let dosis: any RepositorioDosis
    let cola: any RepositorioCola
    /// Lo consultado por código de barras también dice qué come la persona.
    let productos: any RepositorioProductos
    let salud: any ServicioHealthKit
    /// Hasta dónde se había leído de Salud. Opcional porque las pruebas no siempre la traen.
    var ancla: AnclaHealthKit? = nil

    /// Borra todo lo local y, después, lo que Glucy escribió en Salud. Si Salud falla, **el
    /// borrado local se hace igual** y el resultado lo dice: un borrado a medias en silencio
    /// es peor que uno que se explica.
    ///
    /// - Throws: solo si falla el borrado local. En ese caso el perfil sigue ahí y se puede
    ///   volver a intentar.
    @discardableResult
    func ejecutar() async throws -> ResultadoDeBorrado {
        try await lecturas.eliminarTodo()
        try await comidas.eliminarTodo()
        try await dosis.eliminarTodo()
        try await cola.eliminarTodo()
        try await productos.eliminarTodo()
        // El perfil al final: con él se va el consentimiento, que es la puerta de la app. Si
        // algo de arriba falla, la persona sigue dentro y puede reintentar.
        try await perfil.eliminarTodo()
        // Quien vuelva a dar de alta su sensor tiene que recibir otra vez su historial.
        ancla?.borrar()

        // Sin Salud en el dispositivo no hay nada que Glucy haya podido escribir ahí.
        guard salud.disponible else { return ResultadoDeBorrado(saludLimpia: true) }
        do {
            try await salud.eliminarTodoLoPropio()
            return ResultadoDeBorrado(saludLimpia: true)
        } catch {
            return ResultadoDeBorrado(saludLimpia: false)
        }
    }
}
