import Foundation

/// Las alertas que la app emitió.
///
/// Se guardan aunque nadie las vuelva a leer en la pantalla, por dos razones que no son
/// decorativas: sin el registro no se puede saber **si se avisó a tiempo** —el tiempo de
/// anticipación es una de las métricas que el reporte tiene que dar— y sin él la app no tiene
/// forma de no repetirse, porque la pantalla se recalcula cada minuto y el mismo descenso
/// dispararía la misma alerta sesenta veces por hora.
nonisolated protocol RepositorioAlertas: Sendable {
    /// Guarda y encola en la misma llamada. `false` si ese UUID ya existía (RF-36c).
    @discardableResult
    func guardar(_ dato: AlertaDato) async throws -> Bool

    /// La última alerta emitida para ese horizonte, que es contra la que se decide si hay
    /// que volver a avisar. `nil` para las alertas sobre el valor de ahora.
    func ultima(horizonteMin: Int?) async throws -> AlertaDato?

    func entre(desde: Date, hasta: Date) async throws -> [AlertaDato]

    /// Que el sistema aceptó entregarla.
    func marcarEntregada(uuid: UUID) async throws

    /// Que la persona la dio por vista.
    func marcarReconocida(uuid: UUID, tsUtc: Date) async throws

    func contar() async throws -> Int

    /// Borra todas las filas. Solo lo llama el borrado de la cuenta.
    func eliminarTodo() async throws
}
