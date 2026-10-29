import Foundation
import Testing
@testable import Glucy

/// Una ventana de sincronización completa, sin red y sin servidor (RF-35, RF-36, RF-22).
struct SincronizarConBackendTests {

    private let ahora = Date(timeIntervalSince1970: 1_793_232_000)

    private func perfil(sincronizacionActiva: Bool = true) -> PerfilDato {
        PerfilDato(
            nombre: "Ana",
            apellidos: "Ruiz Soto",
            pesoKg: 62.5,
            fechaNacimiento: ReglasDePerfil.fechaDeAnio(1990),
            tipoUsuario: .tipo1,
            umbralHipo: 75,
            umbralHiper: 170,
            duracionAccionInsulinaH: 4,
            consentimientoTsUtc: ahora,
            tipoInsulinaRapida: "lispro",
            sincronizacionActiva: sincronizacionActiva
        )
    }

    private func lectura(_ mgDl: Double, haceMin: Double = 0) -> LecturaGlucosaDato {
        LecturaGlucosaDato(
            mgDl: mgDl,
            tsUtc: ahora.addingTimeInterval(-haceMin * 60),
            zonaHoraria: "America/Monterrey",
            origen: .sensor,
            nota: "esto no debe salir del teléfono"
        )
    }

    /// Arma el caso de uso con todo falso, y siembra la cola con las lecturas dadas.
    private func armar(
        lecturas lista: [LecturaGlucosaDato] = [],
        comidas listaComidas: [ComidaDato] = [],
        dosis listaDosis: [DosisInsulinaDato] = [],
        hayWifi: Bool = true,
        perfilGuardado: PerfilDato? = nil,
        cliente: BackendFalso = BackendFalso(),
        renglonesPorLote: Int = 500
    ) async -> (
        caso: SincronizarConBackend,
        cola: RepositorioColaFalso,
        lecturas: RepositorioLecturasFalso,
        comidas: RepositorioComidasFalso,
        dosis: RepositorioDosisFalso,
        cliente: BackendFalso
    ) {
        let cola = RepositorioColaFalso()
        let repoLecturas = RepositorioLecturasFalso()
        let repoComidas = RepositorioComidasFalso()
        let repoDosis = RepositorioDosisFalso()

        for (indice, dato) in lista.enumerated() {
            _ = try? await repoLecturas.guardar(dato)
            _ = await cola.sembrar(
                tipo: TipoRegistro.lecturaGlucosa,
                uuidRegistro: dato.uuid,
                creado: ahora.addingTimeInterval(Double(indice))
            )
        }
        for dato in listaComidas {
            _ = try? await repoComidas.guardar(dato)
            _ = await cola.sembrar(tipo: TipoRegistro.comida, uuidRegistro: dato.uuid)
        }
        for dato in listaDosis {
            _ = try? await repoDosis.guardar(dato)
            _ = await cola.sembrar(tipo: TipoRegistro.dosisInsulina, uuidRegistro: dato.uuid)
        }

        let caso = SincronizarConBackend(
            cola: cola,
            lecturas: repoLecturas,
            comidas: repoComidas,
            dosis: repoDosis,
            perfil: RepositorioPerfilFalso(perfilGuardado ?? perfil()),
            cliente: cliente,
            red: RedFalsa(hayWifi: hayWifi),
            renglonesPorLote: renglonesPorLote
        )
        return (caso, cola, repoLecturas, repoComidas, repoDosis, cliente)
    }

    // MARK: - Cuándo sí y cuándo no

    /// P-08. Con datos móviles la cola no se toca, y con el botón manual sí.
    @Test("P-08: con datos móviles no sube nada; forzado por la persona, sí")
    func P08_datosMoviles() async {
        let sinWifi = await armar(lecturas: [lectura(120)], hayWifi: false)
        let quieto = await sinWifi.caso.ejecutar()
        #expect(quieto.subidos == 0)
        #expect(quieto.perfilSubido == false)
        #expect(await sinWifi.cliente.lecturasRecibidas.isEmpty)
        #expect(quieto.pendientes == 1)

        let forzado = await sinWifi.caso.ejecutar(forzadoPorUsuario: true)
        #expect(forzado.subidos == 1)
    }

    /// P-07. En modo avión no hay nada que reportar y la cola se queda completa.
    @Test("P-07: sin red el lote se queda en la cola y no se marca error")
    func P07_sinRed() async {
        let cliente = BackendFalso()
        await cliente.responder(lecturas: [.failure(.sinRed)])
        let todo = await armar(lecturas: [lectura(120)], cliente: cliente)

        let resumen = await todo.caso.ejecutar()
        #expect(resumen.motivo == .sinRed)
        #expect(resumen.subidos == 0)
        #expect(resumen.enCuarentena == 0)
        #expect(resumen.pendientes == 1)
        #expect(await todo.cola.errores.isEmpty)
    }

    @Test("Si la persona apagó la sincronización, no sube nada, ni el perfil")
    func apagadaNoSubeNada() async {
        let todo = await armar(
            lecturas: [lectura(120)], perfilGuardado: perfil(sincronizacionActiva: false)
        )
        let resumen = await todo.caso.ejecutar(forzadoPorUsuario: true)
        #expect(resumen.perfilSubido == false)
        #expect(resumen.subidos == 0)
        #expect(await todo.cliente.perfilesRecibidos.isEmpty)
    }

    @Test("Sin nada pendiente no se abre ninguna conexión")
    func sinPendientes() async {
        let todo = await armar()
        let resumen = await todo.caso.ejecutar()
        #expect(resumen.huboTrabajo == false)
        #expect(await todo.cliente.perfilesRecibidos.isEmpty)
    }

    // MARK: - Lo que viaja y lo que no

    /// Regla 3. La nota está en el registro y **no** en lo que se sube.
    @Test("Regla 3: la nota se queda en el teléfono")
    func laNotaNoViaja() async throws {
        let dato = lectura(120)
        #expect(dato.nota != nil)
        let todo = await armar(lecturas: [dato])
        _ = await todo.caso.ejecutar()

        let enviado = try #require(await todo.cliente.lecturasRecibidas.first?.first)
        let json = try GlucyHTTP.codificador.encode(enviado)
        let texto = try #require(String(data: json, encoding: .utf8))
        #expect(texto.contains("esto no debe salir") == false)
        #expect(texto.contains("nota") == false)
    }

    /// Regla 3. Del perfil suben seis valores; nombre, apellidos y peso no están.
    @Test("Regla 3: del perfil no suben nombre, apellidos ni peso")
    func elPerfilSubeSoloLosSeis() async throws {
        let todo = await armar(lecturas: [lectura(120)])
        _ = await todo.caso.ejecutar()

        let enviado = try #require(await todo.cliente.perfilesRecibidos.first)
        #expect(enviado.umbralHipo == 75)
        #expect(enviado.umbralHiper == 170)
        #expect(enviado.duracionAccionInsulina == 4)
        #expect(enviado.anioNacimiento == 1990)

        let texto = try #require(
            String(data: try GlucyHTTP.codificador.encode(enviado), encoding: .utf8)
        )
        for prohibido in ["Ana", "Ruiz", "62.5", "peso", "nombre", "apellidos", "uuid"] {
            #expect(texto.contains(prohibido) == false, "subió «\(prohibido)»")
        }
    }

    // MARK: - Las tres listas

    @Test("Aceptado y duplicado terminan igual: la fila sale de la cola")
    func aceptadoYDuplicadoSalenDeLaCola() async {
        let primera = lectura(120, haceMin: 10)
        let segunda = lectura(130, haceMin: 5)
        let cliente = BackendFalso()
        await cliente.responder(lecturas: [
            .success(RespuestaLote(
                aceptados: [primera.uuid], duplicados: [segunda.uuid], cuarentena: []
            ))
        ])
        let todo = await armar(lecturas: [primera, segunda], cliente: cliente)

        let resumen = await todo.caso.ejecutar()
        #expect(resumen.subidos == 2)
        #expect(resumen.pendientes == 0)
        #expect(await todo.cola.filas.isEmpty)
        #expect(await todo.lecturas.marcadasSync[primera.uuid] == .confirmado)
        #expect(await todo.lecturas.marcadasSync[segunda.uuid] == .confirmado)
    }

    /// RF-22. Un renglón rechazado se queda en la cola con su motivo, no se borra.
    @Test("RF-22: la cuarentena deja el motivo en la cola y no borra la fila")
    func cuarentenaDejaRastro() async throws {
        let buena = lectura(120, haceMin: 10)
        let mala = lectura(900, haceMin: 5)
        let cliente = BackendFalso()
        await cliente.responder(lecturas: [
            .success(RespuestaLote(
                aceptados: [buena.uuid],
                duplicados: [],
                cuarentena: [
                    RenglonEnCuarentena(uuid: mala.uuid, motivo: "mg_dl fuera de 20–600")
                ]
            ))
        ])
        let todo = await armar(lecturas: [buena, mala], cliente: cliente)

        let resumen = await todo.caso.ejecutar()
        #expect(resumen.subidos == 1)
        #expect(resumen.enCuarentena == 1)

        let filas = await todo.cola.filas
        let enError = try #require(filas.first { $0.uuidRegistro == mala.uuid })
        #expect(enError.estado == .error)
        #expect(enError.ultimoError == "mg_dl fuera de 20–600")
        #expect(await todo.lecturas.marcadasSync[mala.uuid] == .error)
        // Y ya no cuenta como pendiente, así que no vuelve a salir cada ventana.
        #expect(resumen.pendientes == 0)
    }

    // MARK: - Los códigos

    @Test("400: el lote no se reintenta y queda marcado con su motivo")
    func sobreInvalidoNoSeReintenta() async {
        let dato = lectura(120)
        let cliente = BackendFalso()
        await cliente.responder(lecturas: [.failure(.sobreInvalido(detalle: "campo no permitido"))])
        let todo = await armar(lecturas: [dato], cliente: cliente)

        let resumen = await todo.caso.ejecutar()
        #expect(resumen.motivo == .sobreInvalido(detalle: "campo no permitido"))
        #expect(resumen.enCuarentena == 1)
        #expect(await todo.cola.errores.values.contains("campo no permitido"))
        #expect(resumen.pendientes == 0)
    }

    @Test("5xx: el lote espera la siguiente ventana, sin marcar nada")
    func servidorFalloEspera() async {
        let cliente = BackendFalso()
        await cliente.responder(lecturas: [.failure(.servidorFallo(codigoHttp: 503))])
        let todo = await armar(lecturas: [lectura(120)], cliente: cliente)

        let resumen = await todo.caso.ejecutar()
        #expect(resumen.motivo == .servidorFallo(codigoHttp: 503))
        #expect(resumen.pendientes == 1)
        #expect(await todo.cola.errores.isEmpty)
    }

    @Test("401: se detiene y la fila se queda pendiente")
    func tokenRechazadoSeDetiene() async {
        let cliente = BackendFalso()
        await cliente.responder(perfil: .failure(.tokenRechazado))
        let todo = await armar(lecturas: [lectura(120)], cliente: cliente)

        let resumen = await todo.caso.ejecutar()
        #expect(resumen.motivo == .tokenRechazado)
        #expect(resumen.perfilSubido == false)
        #expect(resumen.pendientes == 1)
        #expect(await todo.cliente.lecturasRecibidas.isEmpty)
    }

    @Test("Los tres códigos que esperan se distinguen de los que no")
    func quienSeReintenta() {
        #expect(ErrorBackend.sinRed.seReintenta)
        #expect(ErrorBackend.servidorFallo(codigoHttp: 500).seReintenta)
        #expect(ErrorBackend.tokenRechazado.seReintenta)
        #expect(ErrorBackend.sobreInvalido(detalle: "x").seReintenta == false)
        #expect(ErrorBackend.sinConfiguracion.seReintenta == false)
    }

    // MARK: - El orden y los lotes

    @Test("Lo más antiguo primero, y en lotes del tamaño configurado")
    func ordenYLotes() async throws {
        let lista = (0..<5).map { lectura(100 + Double($0), haceMin: Double(50 - $0 * 10)) }
        let todo = await armar(lecturas: lista, renglonesPorLote: 2)

        let resumen = await todo.caso.ejecutar()
        #expect(resumen.subidos == 5)

        let lotes = await todo.cliente.lecturasRecibidas
        #expect(lotes.count == 3)
        #expect(lotes.map(\.count) == [2, 2, 1])
        // El primero del primer lote es el más viejo de los cinco.
        let primero = try #require(lotes.first?.first)
        #expect(primero.uuid == lista[0].uuid)
    }

    @Test("Los tres tipos suben cada uno a su endpoint en la misma ventana")
    func losTresTipos() async {
        let comida = ComidaDato(tsUtc: ahora, carbsG: 45, origen: .manual, nota: "privado")
        let dosis = DosisInsulinaDato(tsUtc: ahora, unidades: 4, tipo: .bolo, nota: "privado")
        let todo = await armar(lecturas: [lectura(120)], comidas: [comida], dosis: [dosis])

        let resumen = await todo.caso.ejecutar()
        #expect(resumen.subidos == 3)
        #expect(await todo.cliente.lecturasRecibidas.count == 1)
        #expect(await todo.cliente.comidasRecibidas.count == 1)
        #expect(await todo.cliente.dosisRecibidas.count == 1)
        #expect(await todo.comidas.marcadasSync[comida.uuid] == .confirmado)
        #expect(await todo.dosis.marcadasSync[dosis.uuid] == .confirmado)
    }

    // MARK: - Los casos raros

    /// El «Deshacer» de la pantalla de registro borra el registro; su fila no debe subir.
    @Test("Una fila cuyo registro ya no existe sale de la cola y no se sube")
    func filaHuerfana() async {
        let cola = RepositorioColaFalso()
        _ = await cola.sembrar(tipo: TipoRegistro.lecturaGlucosa, uuidRegistro: UUID())
        let caso = SincronizarConBackend(
            cola: cola,
            lecturas: RepositorioLecturasFalso(),
            comidas: RepositorioComidasFalso(),
            dosis: RepositorioDosisFalso(),
            perfil: RepositorioPerfilFalso(perfil()),
            cliente: BackendFalso(),
            red: RedFalsa(hayWifi: true)
        )

        let resumen = await caso.ejecutar()
        #expect(resumen.huerfanas == 1)
        #expect(resumen.subidos == 0)
        #expect(resumen.pendientes == 0)
        #expect(await cola.filas.isEmpty)
    }

    /// Una fila de un tipo sin endpoint no puede quedarse al frente de la cola tapando lo
    /// que sí sube: se marca con su motivo y deja pasar al resto.
    @Test("Un tipo sin endpoint no tapa la cola")
    func tipoSinEndpointNoTapa() async {
        let dato = lectura(120, haceMin: 1)
        let cola = RepositorioColaFalso()
        _ = await cola.sembrar(
            tipo: TipoRegistro.eventoContexto,
            uuidRegistro: UUID(),
            creado: ahora.addingTimeInterval(-3600)
        )
        let repoLecturas = RepositorioLecturasFalso()
        _ = try? await repoLecturas.guardar(dato)
        _ = await cola.sembrar(tipo: TipoRegistro.lecturaGlucosa, uuidRegistro: dato.uuid)

        let cliente = BackendFalso()
        let caso = SincronizarConBackend(
            cola: cola,
            lecturas: repoLecturas,
            comidas: RepositorioComidasFalso(),
            dosis: RepositorioDosisFalso(),
            perfil: RepositorioPerfilFalso(perfil()),
            cliente: cliente,
            red: RedFalsa(hayWifi: true),
            renglonesPorLote: 1
        )

        let resumen = await caso.ejecutar()
        #expect(resumen.sinDestino == 1)
        #expect(resumen.subidos == 1, "la lectura de atrás no subió: la cola quedó tapada")
        #expect(await cliente.lecturasRecibidas.count == 1)
    }

    @Test("Una ventana no da vueltas sin fin")
    func ventanaAcotada() async {
        // Más filas que rondas permitidas, con lotes de uno.
        let lista = (0..<(SincronizarConBackend.maximoLotesPorVentana + 5)).map {
            lectura(100 + Double($0), haceMin: Double(100 - $0))
        }
        let todo = await armar(lecturas: lista, renglonesPorLote: 1)

        let resumen = await todo.caso.ejecutar()
        #expect(resumen.subidos == SincronizarConBackend.maximoLotesPorVentana)
        #expect(resumen.pendientes == 5, "la siguiente ventana continúa donde quedó esta")
    }

    // MARK: - Lo que lee la persona

    /// Regla 7 y RF-30: ni la pantalla de errores puede insinuar un tratamiento, y un número
    /// de error HTTP no le dice nada a nadie.
    @Test("Ningún mensaje de sincronización da una instrucción ni enseña jerga")
    func losMensajesSonParaPersonas() {
        let motivos: [ErrorBackend] = [
            .sinRed, .servidorFallo(codigoHttp: 500), .tokenRechazado,
            .sobreInvalido(detalle: "items: campo no permitido"), .sinConfiguracion,
            .respuestaIlegible,
        ]
        for motivo in motivos {
            let texto = AjustesViewModel.mensaje(de: motivo, subidos: 3).lowercased()
            #expect(texto.isEmpty == false)
            for prohibido in ["unidades", " ui", "inyect", "aplícate", "dosis", "carbohidratos"] {
                #expect(texto.contains(prohibido) == false, "«\(prohibido)» en «\(texto)»")
            }
            for jerga in ["500", "token", "http", "json", "null", "items:"] {
                #expect(texto.contains(jerga) == false, "«\(jerga)» en «\(texto)»")
            }
        }
    }
}
