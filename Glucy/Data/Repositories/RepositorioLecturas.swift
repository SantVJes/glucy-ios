import Foundation

/// Las lecturas de glucosa guardadas en el teléfono.
///
/// Todo es `async throws` porque del otro lado hay un actor, y todo habla de structs: un
/// objeto `@Model` no es `Sendable` y no puede cruzar de un actor a otro.
nonisolated protocol RepositorioLecturas: Sendable {
    /// Guarda la lectura y la encola, en la misma llamada. Devuelve `false` si ya existía
    /// una con ese UUID.
    ///
    /// No lanza error al duplicado: HealthKit reentrega las mismas muestras y el usuario
    /// puede tocar «guardar» dos veces. Un duplicado es normal, no una falla (RF-36c).
    @discardableResult
    func guardar(_ dato: LecturaGlucosaDato) async throws -> Bool

    func porUuid(_ uuid: UUID) async throws -> LecturaGlucosaDato?

    /// La más reciente por `tsUtc`, no por orden de inserción: HealthKit entrega en bloques
    /// y con retraso, así que lo último que llega no es lo último que ocurrió (RF-06b).
    func ultima() async throws -> LecturaGlucosaDato?

    /// La más reciente de ese origen, por `tsUtc`. La decisión de modo necesita la última
    /// del **sensor**: un pinchazo capturado a mano hace dos minutos no vuelve fresca una
    /// serie continua que dejó de llegar hace una hora (RF-06c).
    func ultima(origen: Origen) async throws -> LecturaGlucosaDato?

    /// Anota que la lectura ya está en Salud. No lanza si no la encuentra: pudo borrarse
    /// con «Deshacer» mientras se escribía.
    func marcarEscritaEnHealthKit(uuid: UUID) async throws

    /// Rango cerrado, ordenado de la más vieja a la más nueva.
    func entre(desde: Date, hasta: Date) async throws -> [LecturaGlucosaDato]

    func contar() async throws -> Int

    /// Borra la lectura y, con ella, su fila de la cola.
    ///
    /// Existe por el «Deshacer» de la pantalla de registro: una lectura borrada que dejara
    /// su fila en la cola subiría al backend un registro que en el teléfono ya no existe.
    /// No lanza si no encuentra nada: deshacer dos veces no es una falla.
    func eliminar(uuid: UUID) async throws
}
