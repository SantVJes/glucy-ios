import Foundation
@testable import Glucy

/// Un repositorio de dosis de mentira. Lleva la cuenta de lo que se le pidió: sobre todo
/// **cuántas horas de dosis** le pide el cálculo de insulina activa.
actor RepositorioDosisFalso: RepositorioDosis {
    private(set) var guardadas: [DosisInsulinaDato] = []
    private(set) var horasPedidas: [Double] = []
    private(set) var marcadasEnHealthKit: [UUID] = []

    @discardableResult
    func guardar(_ dato: DosisInsulinaDato) async throws -> Bool {
        guard !guardadas.contains(where: { $0.uuid == dato.uuid }) else { return false }
        guardadas.append(dato)
        return true
    }

    func porUuid(_ uuid: UUID) async throws -> DosisInsulinaDato? {
        guardadas.first { $0.uuid == uuid }
    }

    func recientes(horas: Double, hasta: Date) async throws -> [DosisInsulinaDato] {
        horasPedidas.append(horas)
        let corte = hasta.addingTimeInterval(-horas * 3600)
        return guardadas
            .filter { $0.tsUtc >= corte && $0.tsUtc <= hasta }
            .sorted { $0.tsUtc < $1.tsUtc }
    }

    func contar() async throws -> Int {
        guardadas.count
    }

    func eliminar(uuid: UUID) async throws {
        guardadas.removeAll { $0.uuid == uuid }
    }

    func ultima() async throws -> DosisInsulinaDato? {
        guardadas.max { $0.tsUtc < $1.tsUtc }
    }

    func marcarEscritaEnHealthKit(uuid: UUID) async throws {
        marcadasEnHealthKit.append(uuid)
    }

    func eliminarTodo() async throws {
        guardadas.removeAll()
    }

    private(set) var marcadasSync: [UUID: SyncEstado] = [:]

    func marcarSync(uuids: [UUID], estado: SyncEstado) async throws {
        for uuid in uuids { marcadasSync[uuid] = estado }
    }
}
