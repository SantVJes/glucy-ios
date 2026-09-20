import Foundation
import SwiftData

/// La cola de sincronización sobre SwiftData.
@ModelActor
actor ColaSwiftData: RepositorioCola {

    @discardableResult
    func encolar(tipo: String, uuidRegistro: UUID) throws -> Bool {
        let encolado = try EncoladoLocal.encolar(
            en: modelContext, tipo: tipo, uuidRegistro: uuidRegistro
        )
        if encolado { try modelContext.save() }
        return encolado
    }

    func pendientes(limite: Int) throws -> [PendienteDato] {
        // El enum no se filtra dentro del `#Predicate`: comparar un enum ahí falla en
        // ejecución, no al compilar. Se trae ordenado por fecha, que sí funciona, y el
        // estado se filtra en memoria.
        //
        // Tampoco se acota el `fetchLimit`: si la cola tuviera muchos enviados por delante,
        // un límite pequeño devolvería menos pendientes de los que hay y el error sería
        // invisible. La cola de una persona no pasa de unos miles de filas.
        let descriptor = FetchDescriptor<ColaSincronizacion>(
            sortBy: [SortDescriptor(\.creadoTsUtc, order: .forward)]
        )
        return try modelContext.fetch(descriptor)
            .filter { $0.estado == .pendiente }
            .prefix(limite)
            .map(\.dato)
    }

    func marcarEnviado(uuid: UUID) throws {
        guard let fila = try fila(uuid: uuid) else { throw ErrorPersistencia.noEncontrado(uuid: uuid) }
        fila.estado = .enviado
        fila.ultimoIntentoTsUtc = Date()
        fila.ultimoError = nil
        try modelContext.save()
    }

    func marcarError(uuid: UUID, motivo: String) throws {
        guard let fila = try fila(uuid: uuid) else { throw ErrorPersistencia.noEncontrado(uuid: uuid) }
        // La fila no se borra: un dato rechazado sin rastro es una falla invisible.
        fila.estado = .error
        fila.ultimoError = motivo
        fila.intentos += 1
        fila.ultimoIntentoTsUtc = Date()
        try modelContext.save()
    }

    func contarPendientes() throws -> Int {
        let descriptor = FetchDescriptor<ColaSincronizacion>()
        return try modelContext.fetch(descriptor).filter { $0.estado == .pendiente }.count
    }

    private func fila(uuid: UUID) throws -> ColaSincronizacion? {
        var descriptor = FetchDescriptor<ColaSincronizacion>(
            predicate: #Predicate { $0.uuid == uuid }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }
}

/// Encolar desde dentro de otro repositorio.
///
/// Guardar y encolar tienen que ocurrir en la **misma llamada y el mismo contexto**: si se
/// separan, un cierre de la app entre las dos deja un registro que nunca va a subir y nadie
/// se entera. Por eso cada repositorio encola con su propio `ModelContext` en vez de
/// llamar al actor de la cola, que tiene el suyo.
nonisolated enum EncoladoLocal {

    /// - Returns: `false` si ese registro ya estaba encolado.
    @discardableResult
    static func encolar(en contexto: ModelContext, tipo: String, uuidRegistro: UUID) throws -> Bool {
        var descriptor = FetchDescriptor<ColaSincronizacion>(
            predicate: #Predicate { $0.uuidRegistro == uuidRegistro }
        )
        descriptor.fetchLimit = 1
        guard try contexto.fetch(descriptor).isEmpty else { return false }

        contexto.insert(ColaSincronizacion(tipoRegistro: tipo, uuidRegistro: uuidRegistro))
        return true
    }
}
