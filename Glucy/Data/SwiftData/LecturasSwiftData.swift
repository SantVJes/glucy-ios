import Foundation
import SwiftData

/// Las lecturas de glucosa sobre SwiftData.
///
/// El macro `@ModelActor` genera el `init(modelContainer:)` y el `modelContext` aislado en
/// este actor. Al ser actor, lo que entra y sale son structs `Sendable`, y por eso puede
/// escribir desde la entrega en segundo plano de HealthKit sin tocar el hilo principal.
@ModelActor
actor LecturasSwiftData: RepositorioLecturas {

    @discardableResult
    func guardar(_ dato: LecturaGlucosaDato) throws -> Bool {
        // La idempotencia se comprueba antes de insertar. El `@Attribute(.unique)` también
        // lo evitaría, pero lanzando; aquí se quiere un `false` tranquilo (RF-36c).
        let uuid = dato.uuid
        var descriptor = FetchDescriptor<LecturaGlucosa>(predicate: #Predicate { $0.uuid == uuid })
        descriptor.fetchLimit = 1
        guard try modelContext.fetch(descriptor).isEmpty else { return false }

        modelContext.insert(LecturaGlucosa(dato: dato))
        // Guardar y encolar, en la misma llamada y antes del save.
        try EncoladoLocal.encolar(
            en: modelContext, tipo: TipoRegistro.lecturaGlucosa, uuidRegistro: dato.uuid
        )
        try modelContext.save()
        return true
    }

    func porUuid(_ uuid: UUID) throws -> LecturaGlucosaDato? {
        var descriptor = FetchDescriptor<LecturaGlucosa>(predicate: #Predicate { $0.uuid == uuid })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first?.dato
    }

    func ultima() throws -> LecturaGlucosaDato? {
        // Por `tsUtc`, no por orden de inserción: HealthKit entrega en bloques y con
        // retraso, así que lo último que llega no es lo último que ocurrió (RF-06b).
        var descriptor = FetchDescriptor<LecturaGlucosa>(
            sortBy: [SortDescriptor(\.tsUtc, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first?.dato
    }

    func entre(desde: Date, hasta: Date) throws -> [LecturaGlucosaDato] {
        // Los extremos se capturan antes: dentro de un `#Predicate` no se pueden llamar
        // funciones.
        let descriptor = FetchDescriptor<LecturaGlucosa>(
            predicate: #Predicate { $0.tsUtc >= desde && $0.tsUtc <= hasta },
            sortBy: [SortDescriptor(\.tsUtc, order: .forward)]
        )
        return try modelContext.fetch(descriptor).map(\.dato)
    }

    func contar() throws -> Int {
        try modelContext.fetchCount(FetchDescriptor<LecturaGlucosa>())
    }

    func eliminar(uuid: UUID) throws {
        var descriptor = FetchDescriptor<LecturaGlucosa>(predicate: #Predicate { $0.uuid == uuid })
        descriptor.fetchLimit = 1
        guard let fila = try modelContext.fetch(descriptor).first else { return }
        modelContext.delete(fila)

        // La fila de la cola se va con ella, en la misma llamada: si se quedara, el backend
        // recibiría un registro que en el teléfono ya no existe.
        var enCola = FetchDescriptor<ColaSincronizacion>(
            predicate: #Predicate { $0.uuidRegistro == uuid }
        )
        enCola.fetchLimit = 1
        if let filaCola = try modelContext.fetch(enCola).first {
            modelContext.delete(filaCola)
        }
        try modelContext.save()
    }
}
