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
}
