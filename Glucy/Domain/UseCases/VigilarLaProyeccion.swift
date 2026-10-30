import Foundation

/// Qué dejó una pasada de vigilancia. Se devuelve en lugar de tragarse el resultado porque
/// esto corre sin pantalla: si no se devuelve, no hay forma de probarlo ni de explicar después
/// por qué una noche no salió el aviso.
nonisolated enum ResultadoDeLaVigilancia: Sendable, Equatable {
    /// Hubo predicción y el aviso decidió. Es el caso normal, incluido «no había nada que
    /// avisar», que es lo que pasa casi siempre.
    case decidido(ResultadoDelAviso)
    /// No había predicción que vigilar, con su motivo.
    case sinPrediccion(SinProyeccion)
    /// El registro de la alerta falló. La base local es la dueña del dato (regla 1), así que
    /// un fallo al escribirla se dice y no se disimula entregando un aviso que no quedó
    /// anotado en ninguna parte.
    case noSePudoRegistrar(detalle: String)
}

/// El aviso de hipoglucemia prevista **cuando no hay ninguna pantalla dibujada** (RF-10).
///
/// Es la pieza que hace que anticipar media hora sirva de algo. Sin esto, el aviso del paso
/// anterior solo salía mientras alguien miraba la pantalla de inicio, y el caso para el que
/// existe el producto es justo el contrario: una hipoglucemia de madrugada, con el teléfono en
/// la mesa de noche y la app cerrada.
///
/// Quien la llama es el observador de Salud: iOS despierta la app cuando la app del sensor
/// escribe una muestra, `SincronizarLecturasDelSensor` la guarda, y entonces esto predice y
/// decide si avisar. **No se programa ningún temporizador**: sin muestra nueva no hay
/// predicción nueva, así que despertar cada cinco minutos solo gastaría batería para volver a
/// calcular lo mismo.
///
/// Dos cosas que son distintas aquí y en la pantalla:
///
/// 1. **No se pide el permiso de avisar.** iOS no puede presentar ese diálogo con la app en
///    segundo plano, y preguntar ahí gasta la única vez que se puede preguntar. Se entrega si
///    ya hay permiso; si no, la alerta queda registrada y el permiso se pide en la pantalla.
/// 2. **El modo llega hecho**, de la misma pasada de sincronización que acaba de guardar la
///    muestra, en lugar de volver a consultarlo. Recalcularlo aquí podría dar otra respuesta
///    que la de la pasada que provocó esto, y entonces la app diría dos cosas distintas del
///    mismo instante.
nonisolated struct VigilarLaProyeccion: Sendable {
    let predecir: CalcularPrediccion
    let avisar: AvisarDeLaProyeccion
    /// Opcional, como en el resto de los casos de uso: sin perfil el umbral es el de por
    /// omisión y la vigilancia sigue funcionando.
    let perfil: (any RepositorioPerfil)?

    /// - Parameter estado: el que devolvió la pasada de sincronización que acaba de guardar la
    ///   muestra nueva.
    /// - Parameter ahora: se pasa, no se toma de `Date()` dentro, para poder probarlo.
    func ejecutar(estado: EstadoModo, ahora: Date = Date()) async -> ResultadoDeLaVigilancia {
        // En modo sin sensor `CalcularPrediccion` ya devuelve `.sinSensor` y aquí no se
        // reimplementa la regla: **la app no anticipa hipoglucemias sin serie continua**
        // (RF-10b, regla 8, caso P-04) y hay un solo lugar que lo decide.
        let proyecciones: [Proyeccion]
        do {
            let resultado = try await predecir.ejecutar(modo: estado.modo, ahora: ahora)
            switch resultado {
            case let .success(lista):
                proyecciones = lista
            case let .failure(motivo):
                return .sinPrediccion(motivo)
            }
        } catch {
            // Sin poder leer la base no se puede predecir, y eso no es una excepción que nadie
            // vaya a ver: no hay pantalla. Se devuelve con el motivo.
            return .sinPrediccion(.sinModelo(detalle: String(describing: error)))
        }

        let delPerfil = try? await perfil?.actual()
        let umbralHipo = delPerfil?.umbralHipo ?? ConfiguracionDominio.umbralHipoPorOmision

        do {
            let decision = try await avisar.ejecutar(
                proyecciones: proyecciones,
                modo: estado.modo,
                umbralHipo: umbralHipo,
                ahora: ahora,
                puedePedirPermiso: false
            )
            return .decidido(decision)
        } catch {
            return .noSePudoRegistrar(detalle: String(describing: error))
        }
    }
}
