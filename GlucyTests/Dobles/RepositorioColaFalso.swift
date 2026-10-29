import Foundation
@testable import Glucy

/// La cola de mentira. Guarda las filas en orden y deja ver qué se marcó y qué se borró,
/// que es justo lo que hay que comprobar de una ventana de sincronización.
actor RepositorioColaFalso: RepositorioCola {
    private(set) var filas: [PendienteDato] = []
    private(set) var confirmadas: [UUID] = []
    private(set) var errores: [UUID: String] = [:]
    private(set) var vaciada = false

    init(_ filas: [PendienteDato] = []) {
        self.filas = filas
    }

    /// Mete una fila ya hecha, como si la hubiera encolado un repositorio.
    func sembrar(tipo: String, uuidRegistro: UUID, creado: Date = Date()) -> PendienteDato {
        let fila = PendienteDato(
            tipoRegistro: tipo, uuidRegistro: uuidRegistro, creadoTsUtc: creado
        )
        filas.append(fila)
        return fila
    }

    @discardableResult
    func encolar(tipo: String, uuidRegistro: UUID) async throws -> Bool {
        guard !filas.contains(where: { $0.uuidRegistro == uuidRegistro }) else { return false }
        _ = sembrar(tipo: tipo, uuidRegistro: uuidRegistro)
        return true
    }

    func pendientes(limite: Int) async throws -> [PendienteDato] {
        filas
            .filter { $0.estado == .pendiente }
            .sorted { $0.creadoTsUtc < $1.creadoTsUtc }
            .prefix(limite)
            .map { $0 }
    }

    func marcarEnviado(uuid: UUID) async throws {
        cambiar(uuid: uuid, estado: .enviado, motivo: nil)
    }

    func marcarError(uuid: UUID, motivo: String) async throws {
        errores[uuid] = motivo
        cambiar(uuid: uuid, estado: .error, motivo: motivo)
    }

    func contarPendientes() async throws -> Int {
        filas.filter { $0.estado == .pendiente }.count
    }

    func confirmar(uuids: [UUID]) async throws {
        confirmadas.append(contentsOf: uuids)
        let porBorrar = Set(uuids)
        filas.removeAll { porBorrar.contains($0.uuid) }
    }

    func contarConError() async throws -> Int {
        filas.filter { $0.estado == .error }.count
    }

    func eliminarTodo() async throws {
        filas.removeAll()
        vaciada = true
    }

    /// `PendienteDato` es inmutable, así que la fila se vuelve a armar en lugar de mutarse.
    private func cambiar(uuid: UUID, estado: SyncEstado, motivo: String?) {
        guard let indice = filas.firstIndex(where: { $0.uuid == uuid }) else { return }
        let fila = filas[indice]
        filas[indice] = PendienteDato(
            uuid: fila.uuid,
            tipoRegistro: fila.tipoRegistro,
            uuidRegistro: fila.uuidRegistro,
            creadoTsUtc: fila.creadoTsUtc,
            zonaHoraria: fila.zonaHoraria,
            intentos: fila.intentos + (motivo == nil ? 0 : 1),
            ultimoIntentoTsUtc: Date(),
            ultimoError: motivo,
            estado: estado
        )
    }
}
