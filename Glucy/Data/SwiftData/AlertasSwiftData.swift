import Foundation
import SwiftData

/// Las alertas sobre SwiftData.
///
/// **No encola para subir**, a diferencia de las lecturas, las comidas y las dosis: entre los
/// siete endpoints del contrato no hay uno de alertas, así que una fila en la cola se quedaría
/// ahí sin nadie que la recogiera. Lo que sí hace es guardarlas todas, porque el registro es
/// lo que permite medir el tiempo de anticipación y lo que impide que la app se repita.
@ModelActor
actor AlertasSwiftData: RepositorioAlertas {

    @discardableResult
    func guardar(_ dato: AlertaDato) throws -> Bool {
        let uuid = dato.uuid
        var descriptor = FetchDescriptor<Alerta>(predicate: #Predicate { $0.uuid == uuid })
        descriptor.fetchLimit = 1
        guard try modelContext.fetch(descriptor).isEmpty else { return false }

        modelContext.insert(Alerta(dato: dato))
        try modelContext.save()
        return true
    }

    func ultima(horizonteMin: Int?) throws -> AlertaDato? {
        // El filtro del horizonte va en memoria: comparar un `Int?` contra otro `Int?` dentro
        // de un `#Predicate` compila y después se porta distinto según la versión de
        // SwiftData, y una alerta repetida es justo lo que esto existe para evitar.
        let descriptor = FetchDescriptor<Alerta>(
            sortBy: [SortDescriptor(\.tsUtc, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
            .first { $0.horizonteMin == horizonteMin }?
            .dato
    }

    func entre(desde: Date, hasta: Date) throws -> [AlertaDato] {
        let descriptor = FetchDescriptor<Alerta>(
            predicate: #Predicate { $0.tsUtc >= desde && $0.tsUtc <= hasta },
            sortBy: [SortDescriptor(\.tsUtc, order: .forward)]
        )
        return try modelContext.fetch(descriptor).map(\.dato)
    }

    func marcarEntregada(uuid: UUID) throws {
        guard let fila = try fila(uuid) else { return }
        fila.entregada = true
        try modelContext.save()
    }

    func marcarReconocida(uuid: UUID, tsUtc: Date) throws {
        guard let fila = try fila(uuid) else { return }
        fila.reconocidaTsUtc = tsUtc
        try modelContext.save()
    }

    func contar() throws -> Int {
        try modelContext.fetchCount(FetchDescriptor<Alerta>())
    }

    func eliminarTodo() throws {
        for fila in try modelContext.fetch(FetchDescriptor<Alerta>()) {
            modelContext.delete(fila)
        }
        try modelContext.save()
    }

    private func fila(_ uuid: UUID) throws -> Alerta? {
        var descriptor = FetchDescriptor<Alerta>(predicate: #Predicate { $0.uuid == uuid })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }
}
