import Foundation
import SwiftData

/// Las comidas sobre SwiftData.
@ModelActor
actor ComidasSwiftData: RepositorioComidas {

    @discardableResult
    func guardar(_ dato: ComidaDato) throws -> Bool {
        let uuid = dato.uuid
        var descriptor = FetchDescriptor<Comida>(predicate: #Predicate { $0.uuid == uuid })
        descriptor.fetchLimit = 1
        guard try modelContext.fetch(descriptor).isEmpty else { return false }

        modelContext.insert(Comida(dato: dato))
        // Guardar y encolar, en la misma llamada y antes del save.
        try EncoladoLocal.encolar(
            en: modelContext, tipo: TipoRegistro.comida, uuidRegistro: dato.uuid
        )
        try modelContext.save()
        return true
    }

    func porUuid(_ uuid: UUID) throws -> ComidaDato? {
        var descriptor = FetchDescriptor<Comida>(predicate: #Predicate { $0.uuid == uuid })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first?.dato
    }

    func recientes(horas: Double, hasta: Date) throws -> [ComidaDato] {
        // La fecha de corte se calcula antes: dentro de un `#Predicate` no se pueden
        // llamar funciones.
        let corte = hasta.addingTimeInterval(-horas * 3600)
        let descriptor = FetchDescriptor<Comida>(
            predicate: #Predicate { $0.tsUtc >= corte && $0.tsUtc <= hasta },
            sortBy: [SortDescriptor(\.tsUtc, order: .forward)]
        )
        return try modelContext.fetch(descriptor).map(\.dato)
    }

    func contar() throws -> Int {
        try modelContext.fetchCount(FetchDescriptor<Comida>())
    }
}
