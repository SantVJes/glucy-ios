import Foundation
@testable import Glucy

/// Un registro de alertas de mentira, en memoria.
actor RepositorioAlertasFalso: RepositorioAlertas {
    private(set) var guardadas: [AlertaDato] = []

    init() {}

    @discardableResult
    func guardar(_ dato: AlertaDato) async throws -> Bool {
        guard !guardadas.contains(where: { $0.uuid == dato.uuid }) else { return false }
        guardadas.append(dato)
        return true
    }

    func ultima(horizonteMin: Int?) async throws -> AlertaDato? {
        guardadas
            .filter { $0.horizonteMin == horizonteMin }
            .max { $0.tsUtc < $1.tsUtc }
    }

    func entre(desde: Date, hasta: Date) async throws -> [AlertaDato] {
        guardadas
            .filter { $0.tsUtc >= desde && $0.tsUtc <= hasta }
            .sorted { $0.tsUtc < $1.tsUtc }
    }

    func marcarEntregada(uuid: UUID) async throws {
        cambiar(uuid) {
            AlertaDato(
                uuid: $0.uuid, tsUtc: $0.tsUtc, zonaHoraria: $0.zonaHoraria,
                valorMgDl: $0.valorMgDl, umbralMgDl: $0.umbralMgDl,
                horizonteMin: $0.horizonteMin, modo: $0.modo, entregada: true,
                reconocidaTsUtc: $0.reconocidaTsUtc, syncEstado: $0.syncEstado
            )
        }
    }

    func marcarReconocida(uuid: UUID, tsUtc: Date) async throws {
        cambiar(uuid) {
            AlertaDato(
                uuid: $0.uuid, tsUtc: $0.tsUtc, zonaHoraria: $0.zonaHoraria,
                valorMgDl: $0.valorMgDl, umbralMgDl: $0.umbralMgDl,
                horizonteMin: $0.horizonteMin, modo: $0.modo, entregada: $0.entregada,
                reconocidaTsUtc: tsUtc, syncEstado: $0.syncEstado
            )
        }
    }

    func contar() async throws -> Int { guardadas.count }

    func eliminarTodo() async throws { guardadas = [] }

    /// Para preparar el caso de «ya se avisó»: deja una alerta puesta sin pasar por el caso
    /// de uso.
    func sembrar(_ dato: AlertaDato) {
        guardadas.append(dato)
    }

    private func cambiar(_ uuid: UUID, _ nueva: (AlertaDato) -> AlertaDato) {
        guard let indice = guardadas.firstIndex(where: { $0.uuid == uuid }) else { return }
        guardadas[indice] = nueva(guardadas[indice])
    }
}

/// Un servicio de avisos de mentira: se le dice qué permiso hay y después se le pregunta qué
/// avisos recibió.
actor AvisosFalsos: ServicioAvisos {
    private var estado: PermisoDeAviso
    private let respondeAlPedir: Bool
    private let falloAlEntregar: ErrorAviso?

    private(set) var entregados: [AvisoParaEntregar] = []
    private(set) var vecesQueSePidioPermiso = 0

    /// **Sin valores por omisión**, a propósito. Un valor por omisión se evalúa en quien
    /// llama, y llamar ahí al init de un `actor` hace que el compilador quiera marcarlo
    /// `nonisolated`, lo que en un init síncrono de actor no vale. Ya costó dos corridas de
    /// integración continua en el paso 11; cada prueba los pasa los tres.
    init(
        permiso: PermisoDeAviso,
        respondeAlPedir: Bool,
        falloAlEntregar: ErrorAviso?
    ) {
        estado = permiso
        self.respondeAlPedir = respondeAlPedir
        self.falloAlEntregar = falloAlEntregar
    }

    func permiso() async -> PermisoDeAviso { estado }

    func pedirPermiso() async throws -> Bool {
        vecesQueSePidioPermiso += 1
        estado = respondeAlPedir ? .concedido : .negado
        return respondeAlPedir
    }

    func entregar(_ aviso: AvisoParaEntregar) async throws {
        if let falloAlEntregar { throw falloAlEntregar }
        entregados.append(aviso)
    }

    var ultimoEntregado: AvisoParaEntregar? { entregados.last }
}
