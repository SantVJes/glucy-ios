import Foundation

/// En qué estado está el permiso de avisar.
///
/// `sinPreguntar` y `negado` se distinguen porque llevan a cosas distintas: en el primero se
/// puede pedir, en el segundo solo queda decir en pantalla que la app no va a poder avisar.
/// Tratar los dos igual deja a la persona esperando una alerta que el sistema no va a entregar.
nonisolated enum PermisoDeAviso: Sendable, Equatable {
    case sinPreguntar
    case concedido
    case negado
}

/// Un aviso listo para salir del teléfono a la pantalla de bloqueo.
///
/// El texto se arma en el dominio y llega hecho: aquí no se redacta nada. Así la regla de que
/// **ningún aviso da una instrucción de tratamiento** (regla 7) se comprueba en una prueba
/// unitaria del caso de uso, y no depende de leer el código de la capa del sistema.
nonisolated struct AvisoParaEntregar: Sendable, Equatable {
    /// Identificador del aviso en el sistema. Es el UUID de la alerta, así que reemplazar el
    /// aviso de una alerta es entregar otro con el mismo identificador y no apilar dos.
    let identificador: String
    let titulo: String
    let cuerpo: String
    /// Si además de la notificación hay vibración. La alerta vibra porque alguien dormido no
    /// lee una pantalla, y porque el color y el texto no le sirven a quien no los ve.
    let vibra: Bool
}

/// Lo que la app necesita del sistema para avisar, detrás de un protocolo.
///
/// La integración continua no tiene un centro de notificaciones de verdad y el simulador no
/// vibra, así que la decisión de avisar se prueba con un doble y lo que queda detrás de esto
/// es la llamada al sistema, que se comprueba en el iPhone físico.
nonisolated protocol ServicioAvisos: Sendable {
    func permiso() async -> PermisoDeAviso

    /// Pregunta a la persona. Devuelve si quedó concedido. Se llama **cuando ya hay algo que
    /// avisar** y no al abrir la app por primera vez: un permiso que se pide sin contexto se
    /// niega, y negado no se vuelve a preguntar.
    func pedirPermiso() async throws -> Bool

    func entregar(_ aviso: AvisoParaEntregar) async throws
}

/// Por qué no se pudo entregar un aviso.
nonisolated enum ErrorAviso: Error, Equatable {
    /// La persona no dio permiso, o lo quitó desde Ajustes del sistema.
    case sinPermiso
    /// El sistema no aceptó el aviso. Se guarda el motivo para poder diagnosticar; a la
    /// persona se le dice una frase de la app.
    case elSistemaNoLoAcepto(detalle: String)
}
