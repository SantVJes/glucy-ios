import Foundation
import SwiftData

/// Las dosis de insulina sobre SwiftData.
@ModelActor
actor DosisSwiftData: RepositorioDosis {

    @discardableResult
    func guardar(_ dato: DosisInsulinaDato) throws -> Bool {
        let uuid = dato.uuid
        var descriptor = FetchDescriptor<DosisInsulina>(predicate: #Predicate { $0.uuid == uuid })
        descriptor.fetchLimit = 1
        guard try modelContext.fetch(descriptor).isEmpty else { return false }

        modelContext.insert(DosisInsulina(dato: dato))
        // Guardar y encolar, en la misma llamada y antes del save.
        try EncoladoLocal.encolar(
            en: modelContext, tipo: TipoRegistro.dosisInsulina, uuidRegistro: dato.uuid
        )
        try modelContext.save()
        return true
    }

    func porUuid(_ uuid: UUID) throws -> DosisInsulinaDato? {
        var descriptor = FetchDescriptor<DosisInsulina>(predicate: #Predicate { $0.uuid == uuid })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first?.dato
    }

    func recientes(horas: Double, hasta: Date) throws -> [DosisInsulinaDato] {
        let corte = hasta.addingTimeInterval(-horas * 3600)
        let descriptor = FetchDescriptor<DosisInsulina>(
            predicate: #Predicate { $0.tsUtc >= corte && $0.tsUtc <= hasta },
            sortBy: [SortDescriptor(\.tsUtc, order: .forward)]
        )
        return try modelContext.fetch(descriptor).map(\.dato)
    }

    func contar() throws -> Int {
        try modelContext.fetchCount(FetchDescriptor<DosisInsulina>())
    }

    func marcarSync(uuids: [UUID], estado: SyncEstado) throws {
        guard !uuids.isEmpty else { return }
        // Se filtra en memoria: comparar contra una colección dentro de un `#Predicate`
        // compila pero falla en ejecución en más de una versión de SwiftData.
        let porMarcar = Set(uuids)
        let filas = try modelContext.fetch(FetchDescriptor<DosisInsulina>())
            .filter { porMarcar.contains($0.uuid) }
        for fila in filas { fila.syncEstado = estado }
        try modelContext.save()
    }

    func eliminar(uuid: UUID) throws {
        var descriptor = FetchDescriptor<DosisInsulina>(predicate: #Predicate { $0.uuid == uuid })
        descriptor.fetchLimit = 1
        guard let fila = try modelContext.fetch(descriptor).first else { return }
        modelContext.delete(fila)

        // La fila de la cola se va con ella, en la misma llamada (RF-36b).
        var enCola = FetchDescriptor<ColaSincronizacion>(
            predicate: #Predicate { $0.uuidRegistro == uuid }
        )
        enCola.fetchLimit = 1
        if let filaCola = try modelContext.fetch(enCola).first {
            modelContext.delete(filaCola)
        }
        try modelContext.save()
    }

    func ultima() throws -> DosisInsulinaDato? {
        var descriptor = FetchDescriptor<DosisInsulina>(
            sortBy: [SortDescriptor(\.tsUtc, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first?.dato
    }

    func marcarEscritaEnHealthKit(uuid: UUID) throws {
        var descriptor = FetchDescriptor<DosisInsulina>(predicate: #Predicate { $0.uuid == uuid })
        descriptor.fetchLimit = 1
        guard let fila = try modelContext.fetch(descriptor).first else { return }
        fila.escritaEnHealthKit = true
        try modelContext.save()
    }

    func eliminarTodo() throws {
        try modelContext.delete(model: DosisInsulina.self)
        try modelContext.save()
    }
}
