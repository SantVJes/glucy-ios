import Foundation
@testable import Glucy

/// Un repositorio de comidas de mentira. Lleva la cuenta de lo que se le pidió: **cuántas
/// horas** le pide el cálculo de carbohidratos activos, y **cuántas veces se le guardó
/// algo**, que es como se comprueba que nadie inventó una comida (RF-37).
actor RepositorioComidasFalso: RepositorioComidas {
    private(set) var guardadas: [ComidaDato] = []
    private(set) var vecesGuardado = 0
    private(set) var horasPedidas: [Double] = []
    private(set) var marcadasEnHealthKit: [UUID] = []

    @discardableResult
    func guardar(_ dato: ComidaDato) async throws -> Bool {
        vecesGuardado += 1
        guard !guardadas.contains(where: { $0.uuid == dato.uuid }) else { return false }
        guardadas.append(dato)
        return true
    }

    func porUuid(_ uuid: UUID) async throws -> ComidaDato? {
        guardadas.first { $0.uuid == uuid }
    }

    func recientes(horas: Double, hasta: Date) async throws -> [ComidaDato] {
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

    func ultimaConCodigo(_ codigo: String) async throws -> ComidaDato? {
        guardadas.filter { $0.codigoBarras == codigo }.max { $0.tsUtc < $1.tsUtc }
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
