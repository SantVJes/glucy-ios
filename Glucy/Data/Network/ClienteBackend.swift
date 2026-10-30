import Foundation

/// Lo que la app le puede pedir al backend de Glucy.
///
/// Detrás de un protocolo para que el caso de uso de sincronización se pruebe completo sin
/// red: un cliente falso devuelve las tres listas y la prueba comprueba qué hizo la cola con
/// cada una. Nadie fuera de `Data/Network/` sabe que hay `URLSession` del otro lado.
nonisolated protocol ClienteBackend: Sendable {

    /// Sube un lote de lecturas. Devuelve las tres listas tal como las dio el servidor.
    func subirLecturas(_ items: [LecturaSubida]) async throws -> RespuestaLote

    func subirComidas(_ items: [ComidaSubida]) async throws -> RespuestaLote

    func subirDosis(_ items: [DosisSubida]) async throws -> RespuestaLote

    /// Deja los seis parámetros clínicos del perfil. Es un `upsert`: mandarlo dos veces no
    /// crea nada nuevo, así que se puede subir en cada ventana sin llevar la cuenta.
    func subirPerfil(_ perfil: PerfilSubido) async throws

    /// La predicción del servidor con sus factores, de `GET /predict`.
    ///
    /// **No es de donde sale el número que la pantalla enseña**: ese lo calcula Core ML en el
    /// teléfono y sale sin red (C-16). Esto trae lo que el teléfono no puede calcular —las
    /// cinco contribuciones SHAP— y, de paso, el número del servidor, que sirve para comparar
    /// los dos caminos. Responde en menos de 200 ms.
    func pedirPrediccion() async throws -> PrediccionRemota

    /// La frase que explica una predicción, de `POST /explain`.
    ///
    /// Tarda de 1 a 3 segundos, así que se pide **en segundo plano** y no bloquea ninguna
    /// pantalla. Siempre contesta algo: si el modelo de lenguaje no responde en diez
    /// segundos, llega la plantilla determinista y `origen` lo dice (P-13).
    func pedirExplicacion(_ entrada: ExplicacionPedida) async throws -> ExplicacionRemota
}

/// Por qué no se pudo subir un lote, en los términos en los que la app tiene que decidir.
///
/// No es una traducción del código HTTP: es **qué hace el teléfono con él**, que es lo que
/// cambia el comportamiento de la cola (tabla de errores del paso 1 del backend).
nonisolated enum ErrorBackend: Error, Equatable {
    /// `400`. El sobre no sirve y mandarlo otra vez daría el mismo `400`: el lote **no se
    /// reintenta**. Es el único caso en el que la cola marca error sin haber hablado con el
    /// servidor sobre renglones concretos.
    case sobreInvalido(detalle: String)

    /// `401`. El token venció o no se verifica. Se renueva y se reintenta **una vez**; si
    /// vuelve a pasar, el lote se queda en la cola y no se repite el ciclo.
    case tokenRechazado

    /// `5xx`. El servidor está mal, no el dato: el lote se queda en la cola hasta la
    /// siguiente ventana de wifi.
    case servidorFallo(codigoHttp: Int)

    /// Sin red, se agotó el tiempo, o la respuesta no se pudo leer. Igual que el `5xx`: el
    /// lote espera. En modo avión esto es lo normal, no una falla (caso P-07).
    case sinRed

    case respuestaIlegible

    /// No hay backend configurado, o no hay token guardado. No es un error de red: es que
    /// la sincronización no está encendida, y la app funciona igual (regla 1).
    case sinConfiguracion

    /// `true` si el lote tiene sentido reintentarlo en la siguiente ventana.
    var seReintenta: Bool {
        switch self {
        case .servidorFallo, .sinRed, .respuestaIlegible, .tokenRechazado:
            true
        case .sobreInvalido, .sinConfiguracion:
            false
        }
    }
}
