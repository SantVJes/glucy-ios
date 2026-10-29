import Foundation

/// Lo que pasó en una ventana de sincronización.
///
/// Se devuelve completo, con los cuatro números y el motivo, porque la pantalla de Ajustes
/// tiene que poder decir qué ocurrió sin volver a preguntar. Un «listo» sin números no
/// permite distinguir «no había nada que subir» de «no se pudo subir nada».
nonisolated struct ResumenSincronizacion: Sendable, Equatable {
    /// Aceptados más duplicados: el dato ya está del otro lado.
    var subidos = 0
    /// Renglones que el servidor rechazó, con su motivo guardado en la cola (RF-22).
    var enCuarentena = 0
    /// Lo que sigue esperando turno al terminar.
    var pendientes = 0
    /// Filas de la cola cuyo tipo todavía no tiene endpoint en el servidor (C-10, C-11).
    /// Se quedan pendientes a propósito; no se marcan como error porque no fallaron.
    var sinDestino = 0
    /// Filas cuyo registro ya no existe en el teléfono: se sacaron de la cola.
    var huerfanas = 0
    var perfilSubido = false
    /// Por qué se detuvo, si se detuvo. `nil` es que terminó la ventana.
    var motivo: ErrorBackend?

    var huboTrabajo: Bool { subidos > 0 || enCuarentena > 0 || perfilSubido }
}

/// Vaciar la cola hacia el backend: una ventana de sincronización completa.
///
/// Es el caso de uso que cierra la fase 2 del lado del teléfono, y el que concentra las
/// reglas que pueden hacer daño si se escriben mal:
///
/// - **Solo con wifi**, salvo que la persona toque «sincronizar ahora» (RF-35, RF-36,
///   caso P-08). La decisión la toma `DecisionSincronizacion`, no este archivo.
/// - **Lo más antiguo primero**, o el backend reconstruiría la serie desordenada.
/// - **Aceptado y duplicado terminan igual de bien.** Un uuid repetido es un duplicado, no
///   un conflicto: la app reintenta lotes a propósito, y si un duplicado contara como error
///   un reintento normal dejaría media cola en rojo (RF-36c).
/// - **Nada se borra en silencio.** Un renglón en cuarentena se queda en la cola con su
///   motivo, para poder mostrarlo (RF-22).
/// - **Si la persona apagó la sincronización, no se sube nada.** Ni siquiera el perfil.
nonisolated struct SincronizarConBackend: Sendable {
    let cola: any RepositorioCola
    let lecturas: any RepositorioLecturas
    let comidas: any RepositorioComidas
    let dosis: any RepositorioDosis
    let perfil: any RepositorioPerfil
    let cliente: any ClienteBackend
    let red: any EstadoDeRed
    let renglonesPorLote: Int

    /// Cuántas rondas como máximo en una ventana. Con una cola de ocho semanas de sensor son
    /// miles de filas, y subirlas todas de un tirón tendría la app ocupada mucho tiempo; la
    /// ventana siguiente continúa donde quedó esta.
    static let maximoLotesPorVentana = 20

    /// Los tipos de la cola que hoy tienen endpoint.
    ///
    /// `evento_contexto` y `alerta` no lo tienen: el servidor no ofrece endpoint para el
    /// contexto (C-10, C-11) y de las alertas es él la autoridad, no el teléfono. Hoy nadie
    /// encola esos tipos, así que esto es una red por si alguien lo hace mañana.
    static let tiposQueSuben: Set<String> = [
        TipoRegistro.lecturaGlucosa,
        TipoRegistro.comida,
        TipoRegistro.dosisInsulina,
    ]

    /// Lo que se le anota a una fila de un tipo que no tiene a dónde ir.
    ///
    /// Se marca como error **en lugar de dejarla pendiente**, aunque el dato no tenga nada
    /// malo. Una fila que nadie puede subir y que se queda al frente de la cola la tapa:
    /// `pendientes(limite:)` devuelve lo más antiguo primero, y con el tope lleno de filas
    /// intocables las lecturas de hoy no subirían nunca y nada fallaría. Marcada, se ve en
    /// Ajustes con su motivo y no estorba (RF-22).
    static let sinEndpoint = "este tipo de registro todavía no tiene endpoint en el servidor"

    init(
        cola: any RepositorioCola,
        lecturas: any RepositorioLecturas,
        comidas: any RepositorioComidas,
        dosis: any RepositorioDosis,
        perfil: any RepositorioPerfil,
        cliente: any ClienteBackend,
        red: any EstadoDeRed,
        renglonesPorLote: Int = 500
    ) {
        self.cola = cola
        self.lecturas = lecturas
        self.comidas = comidas
        self.dosis = dosis
        self.perfil = perfil
        self.cliente = cliente
        self.red = red
        self.renglonesPorLote = max(1, renglonesPorLote)
    }

    /// - Parameter forzadoPorUsuario: `true` solo cuando la persona toca «sincronizar
    ///   ahora». Es lo único que permite subir con datos móviles (caso P-08).
    func ejecutar(forzadoPorUsuario: Bool = false) async -> ResumenSincronizacion {
        var resumen = ResumenSincronizacion()

        let pendientesAlInicio = (try? await cola.contarPendientes()) ?? 0
        resumen.pendientes = pendientesAlInicio

        guard
            DecisionSincronizacion.debeSincronizar(
                hayWifi: red.hayWifi,
                pendientes: pendientesAlInicio,
                forzadoPorUsuario: forzadoPorUsuario
            )
        else {
            return resumen
        }

        // La preferencia de la persona manda sobre todo lo demás. Se lee aquí y no en la
        // pantalla: una ventana automática no pasa por ninguna pantalla.
        let perfilActual = try? await perfil.actual()
        guard let perfilActual, perfilActual.sincronizacionActiva else {
            return resumen
        }

        // El perfil primero: sin sus umbrales y su duración de acción, el pipeline del
        // servidor calcularía el IOB y la alerta con los valores por omisión en lugar de
        // con los de esta persona. Es un `upsert`, así que mandarlo en cada ventana no
        // cuesta más que una petición.
        do {
            try await cliente.subirPerfil(PerfilSubido(perfilActual))
            resumen.perfilSubido = true
        } catch let error as ErrorBackend {
            resumen.motivo = error
            return resumen
        } catch {
            resumen.motivo = .respuestaIlegible
            return resumen
        }

        for _ in 0..<Self.maximoLotesPorVentana {
            let filas = (try? await cola.pendientes(limite: renglonesPorLote)) ?? []
            guard !filas.isEmpty else { break }

            for fila in filas where !Self.tiposQueSuben.contains(fila.tipoRegistro) {
                try? await cola.marcarError(uuid: fila.uuid, motivo: Self.sinEndpoint)
                resumen.sinDestino += 1
            }
            let porSubir = filas.filter { Self.tiposQueSuben.contains($0.tipoRegistro) }
            guard !porSubir.isEmpty else { continue }

            let detener = await procesar(porSubir, en: &resumen)
            if detener { break }
        }

        resumen.pendientes = (try? await cola.contarPendientes()) ?? resumen.pendientes
        return resumen
    }

    // MARK: - Una ronda

    /// - Returns: `true` si hay que detener la ventana.
    private func procesar(
        _ filas: [PendienteDato], en resumen: inout ResumenSincronizacion
    ) async -> Bool {
        // Se agrupa por tipo porque cada tipo tiene su endpoint, pero el orden dentro de
        // cada grupo sigue siendo el de la cola: lo más antiguo primero.
        let lecturasPorSubir = filas.filter { $0.tipoRegistro == TipoRegistro.lecturaGlucosa }
        let comidasPorSubir = filas.filter { $0.tipoRegistro == TipoRegistro.comida }
        let dosisPorSubir = filas.filter { $0.tipoRegistro == TipoRegistro.dosisInsulina }

        if !lecturasPorSubir.isEmpty {
            let detener = await subirGrupo(
                lecturasPorSubir,
                en: &resumen,
                cargar: { try await lecturas.porUuid($0).map(LecturaSubida.init) },
                enviar: { try await cliente.subirLecturas($0) },
                marcar: { try await lecturas.marcarSync(uuids: $0, estado: $1) }
            )
            if detener { return true }
        }
        if !comidasPorSubir.isEmpty {
            let detener = await subirGrupo(
                comidasPorSubir,
                en: &resumen,
                cargar: { try await comidas.porUuid($0).map(ComidaSubida.init) },
                enviar: { try await cliente.subirComidas($0) },
                marcar: { try await comidas.marcarSync(uuids: $0, estado: $1) }
            )
            if detener { return true }
        }
        if !dosisPorSubir.isEmpty {
            let detener = await subirGrupo(
                dosisPorSubir,
                en: &resumen,
                cargar: { try await dosis.porUuid($0).map(DosisSubida.init) },
                enviar: { try await cliente.subirDosis($0) },
                marcar: { try await dosis.marcarSync(uuids: $0, estado: $1) }
            )
            if detener { return true }
        }
        return false
    }

    /// Un grupo de un solo tipo: cargar, enviar y repartir las tres listas.
    ///
    /// - Returns: `true` si hay que detener la ventana.
    private func subirGrupo<Renglon: Encodable & Sendable>(
        _ filas: [PendienteDato],
        en resumen: inout ResumenSincronizacion,
        cargar: (UUID) async throws -> Renglon?,
        enviar: ([Renglon]) async throws -> RespuestaLote,
        marcar: ([UUID], SyncEstado) async throws -> Void
    ) async -> Bool {
        var renglones: [Renglon] = []
        // Del uuid del registro al uuid de su fila en la cola: la respuesta del servidor
        // habla de registros y la cola se marca por fila.
        var filaDeRegistro: [UUID: UUID] = [:]
        var huerfanas: [UUID] = []

        for fila in filas {
            guard let renglon = try? await cargar(fila.uuidRegistro) else {
                // El registro ya no existe: lo borró el «Deshacer» de la pantalla de
                // registro. Su fila sale de la cola, porque subirla mandaría al servidor
                // un dato que en el teléfono ya no existe.
                huerfanas.append(fila.uuid)
                continue
            }
            renglones.append(renglon)
            filaDeRegistro[fila.uuidRegistro] = fila.uuid
        }

        if !huerfanas.isEmpty {
            try? await cola.confirmar(uuids: huerfanas)
            resumen.huerfanas += huerfanas.count
        }
        guard !renglones.isEmpty else { return false }

        let respuesta: RespuestaLote
        do {
            respuesta = try await enviar(renglones)
        } catch let error as ErrorBackend {
            resumen.motivo = error
            if case .sobreInvalido(let detalle) = error {
                // Mandarlo otra vez daría el mismo 400: el lote no se reintenta. Se marca
                // con su motivo en lugar de dejarlo girando en cada ventana.
                for fila in Set(filaDeRegistro.values) {
                    try? await cola.marcarError(uuid: fila, motivo: detalle)
                }
                resumen.enCuarentena += renglones.count
            }
            return true
        } catch {
            resumen.motivo = .respuestaIlegible
            return true
        }

        let resueltos = respuesta.resueltos
        if !resueltos.isEmpty {
            try? await marcar(resueltos, .confirmado)
            let filasResueltas = resueltos.compactMap { filaDeRegistro[$0] }
            try? await cola.confirmar(uuids: filasResueltas)
            resumen.subidos += resueltos.count
        }

        for renglon in respuesta.cuarentena {
            guard let uuidRegistro = renglon.uuid, let fila = filaDeRegistro[uuidRegistro] else {
                continue
            }
            try? await cola.marcarError(uuid: fila, motivo: renglon.motivo)
            try? await marcar([uuidRegistro], .error)
            resumen.enCuarentena += 1
        }

        return false
    }
}
