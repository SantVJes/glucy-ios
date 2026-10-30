import Foundation
@testable import Glucy

/// Un backend de mentira: se le dice qué va a contestar y después se le pregunta qué recibió.
///
/// Con esto la ventana de sincronización se prueba completa —las tres listas, los códigos de
/// error, el orden de los lotes— sin servidor y sin red. Lo que no se prueba aquí es el
/// cliente HTTP; eso lleva su propia prueba con un `URLProtocol` falso.
actor BackendFalso: ClienteBackend {
    /// Lo que va a contestar cada endpoint, en orden. Si se acaban, contesta «todo aceptado».
    var respuestasLecturas: [Result<RespuestaLote, ErrorBackend>] = []
    var respuestasComidas: [Result<RespuestaLote, ErrorBackend>] = []
    var respuestasDosis: [Result<RespuestaLote, ErrorBackend>] = []
    var respuestaPerfil: Result<Void, ErrorBackend> = .success(())

    private(set) var lecturasRecibidas: [[LecturaSubida]] = []
    private(set) var comidasRecibidas: [[ComidaSubida]] = []
    private(set) var dosisRecibidas: [[DosisSubida]] = []
    private(set) var perfilesRecibidos: [PerfilSubido] = []

    /// Lo de `/predict` y `/explain`. Por omisión, `sinConfiguracion`: una prueba que no se
    /// ocupa de esto no debe recibir una predicción de regalo.
    var respuestaPrediccion: Result<PrediccionRemota, ErrorBackend> = .failure(.sinConfiguracion)
    var respuestaExplicacion: Result<ExplicacionRemota, ErrorBackend> =
        .failure(.sinConfiguracion)
    private(set) var pedidosDePrediccion = 0
    private(set) var explicacionesPedidas: [ExplicacionPedida] = []

    func responder(lecturas: [Result<RespuestaLote, ErrorBackend>]) {
        respuestasLecturas = lecturas
    }

    func responder(comidas: [Result<RespuestaLote, ErrorBackend>]) {
        respuestasComidas = comidas
    }

    func responder(dosis: [Result<RespuestaLote, ErrorBackend>]) {
        respuestasDosis = dosis
    }

    func responder(perfil: Result<Void, ErrorBackend>) {
        respuestaPerfil = perfil
    }

    func responder(prediccion: Result<PrediccionRemota, ErrorBackend>) {
        respuestaPrediccion = prediccion
    }

    func responder(explicacion: Result<ExplicacionRemota, ErrorBackend>) {
        respuestaExplicacion = explicacion
    }

    func subirLecturas(_ items: [LecturaSubida]) async throws -> RespuestaLote {
        lecturasRecibidas.append(items)
        return try Self.resolver(&respuestasLecturas, uuids: items.map(\.uuid))
    }

    func subirComidas(_ items: [ComidaSubida]) async throws -> RespuestaLote {
        comidasRecibidas.append(items)
        return try Self.resolver(&respuestasComidas, uuids: items.map(\.uuid))
    }

    func subirDosis(_ items: [DosisSubida]) async throws -> RespuestaLote {
        dosisRecibidas.append(items)
        return try Self.resolver(&respuestasDosis, uuids: items.map(\.uuid))
    }

    func subirPerfil(_ perfil: PerfilSubido) async throws {
        perfilesRecibidos.append(perfil)
        try respuestaPerfil.get()
    }

    func pedirPrediccion() async throws -> PrediccionRemota {
        pedidosDePrediccion += 1
        return try respuestaPrediccion.get()
    }

    func pedirExplicacion(_ entrada: ExplicacionPedida) async throws -> ExplicacionRemota {
        explicacionesPedidas.append(entrada)
        return try respuestaExplicacion.get()
    }

    private static func resolver(
        _ cola: inout [Result<RespuestaLote, ErrorBackend>], uuids: [UUID]
    ) throws -> RespuestaLote {
        guard !cola.isEmpty else {
            return RespuestaLote(aceptados: uuids, duplicados: [], cuarentena: [])
        }
        return try cola.removeFirst().get()
    }
}

/// La red de mentira: se le dice si hay wifi y ya.
nonisolated struct RedFalsa: EstadoDeRed {
    let hayWifi: Bool
}

/// Un almacén de token en memoria, para no tocar el Keychain del simulador.
final class AlmacenFalso: AlmacenDeToken, @unchecked Sendable {
    private var guardado: String?

    init(token: String? = nil) {
        guardado = token
    }

    func token() -> String? { guardado }
    func guardar(token: String) throws { guardado = token }
    func borrar() throws { guardado = nil }
}
