import Foundation
import Testing
@testable import Glucy

/// Traer de Salud y guardar en el teléfono. Sin dispositivo y sin HealthKit: todo pasa por
/// el doble.
struct SincronizarLecturasDelSensorTests {

    private let ahora = Date(timeIntervalSince1970: 1_758_240_000)

    /// Un dominio por prueba, para que el ancla de una no se cuele en otra ni en la de la
    /// app.
    private func anclaDePrueba() -> AnclaHealthKit {
        AnclaHealthKit(dominio: "glucy.pruebas.\(UUID().uuidString)")
    }

    private func borrar(_ ancla: AnclaHealthKit) {
        ancla.borrar()
    }

    private func muestra(
        mgDl: Double = 120, haceMin: Double = 0, esPropia: Bool = false
    ) -> MuestraGlucosa {
        MuestraGlucosa(
            uuid: UUID(), valor: mgDl, ts: ahora.addingTimeInterval(-haceMin * 60),
            esPropia: esPropia
        )
    }

    /// Prueba 1 · RF-06 — lo que escribió la app del sensor entra con su origen verdadero.
    @Test("1 · RF-06: una muestra del sensor se guarda con origen sensor")
    func muestraDelSensorSeGuardaComoSensor() async throws {
        let salud = HealthKitFalso()
        let repositorio = RepositorioLecturasFalso()
        let ancla = anclaDePrueba()
        defer { borrar(ancla) }
        let dexcom = muestra(mgDl: 134, haceMin: 3)
        await salud.agregar([dexcom])

        let resultado = await SincronizarLecturasDelSensor(
            servicio: salud, lecturas: repositorio, ancla: ancla
        ).ejecutar(ahora: ahora)

        #expect(resultado.guardadas == 1)
        let guardada = try #require(await repositorio.guardadas.first)
        #expect(guardada.uuid == dexcom.uuid)
        #expect(guardada.origen == .sensor)
        #expect(guardada.mgDl == 134)
    }

    /// Prueba 2 · RF-15b — lo que escribió Glucy vuelve en la consulta. Guardarlo otra vez
    /// es el primer paso de la serie duplicada.
    @Test("2 · RF-15b: una muestra propia no se guarda otra vez")
    func muestraPropiaNoSeGuarda() async throws {
        let salud = HealthKitFalso()
        let repositorio = RepositorioLecturasFalso()
        let ancla = anclaDePrueba()
        defer { borrar(ancla) }
        await salud.agregar([muestra(esPropia: true)])

        let resultado = await SincronizarLecturasDelSensor(
            servicio: salud, lecturas: repositorio, ancla: ancla
        ).ejecutar(ahora: ahora)

        #expect(resultado.guardadas == 0)
        #expect(await repositorio.guardadas.isEmpty)
    }

    /// Prueba 3 · RF-36c — HealthKit reentrega la misma muestra. Queda una sola fila.
    @Test("3 · RF-36c: la misma muestra dos veces deja una sola fila")
    func mismaMuestraDosVecesUnaFila() async throws {
        let salud = HealthKitFalso()
        let repositorio = RepositorioLecturasFalso()
        let ancla = anclaDePrueba()
        defer { borrar(ancla) }
        let repetida = muestra(haceMin: 5)
        await salud.agregar([repetida, repetida])

        let caso = SincronizarLecturasDelSensor(servicio: salud, lecturas: repositorio, ancla: ancla)
        _ = await caso.ejecutar(ahora: ahora)
        // Y una pasada sin ancla, como tras perderla: trae todo otra vez.
        ancla.guardar(nil)
        _ = await caso.ejecutar(ahora: ahora)

        #expect(await repositorio.guardadas.count == 1)
    }

    /// Prueba 4 · **RF-06b** — con dos muestras separadas 40 min se guardan dos filas.
    /// Nueve serían una cada cinco minutos, y siete de ellas inventadas.
    @Test("4 · RF-06b: con 40 min entre dos muestras se guardan dos filas, no nueve")
    func noSeRellenanHuecos() async throws {
        let salud = HealthKitFalso()
        let repositorio = RepositorioLecturasFalso()
        let ancla = anclaDePrueba()
        defer { borrar(ancla) }
        let antes = muestra(mgDl: 110, haceMin: 40)
        let despues = muestra(mgDl: 150, haceMin: 0)
        await salud.agregar([antes, despues])

        _ = await SincronizarLecturasDelSensor(
            servicio: salud, lecturas: repositorio, ancla: ancla
        ).ejecutar(ahora: ahora)

        let guardadas = await repositorio.guardadas
        #expect(guardadas.count == 2)
        #expect(Set(guardadas.map(\.uuid)) == [antes.uuid, despues.uuid])
        #expect(Set(guardadas.map(\.mgDl)) == [110, 150])
    }

    /// Prueba 5 · **P-09** — el permiso revocado llega como un error de Salud. No sale del
    /// caso de uso: `ejecutar` ni siquiera se declara `throws`.
    @Test("5 · P-09: si Salud lanza, cero muestras y el error no sube")
    func falloDeSaludNoSube() async throws {
        let salud = HealthKitFalso()
        let repositorio = RepositorioLecturasFalso()
        let ancla = anclaDePrueba()
        defer { borrar(ancla) }
        await salud.agregar([muestra()])
        await salud.fallarLecturas(con: PermisoRevocado())

        let resultado = await SincronizarLecturasDelSensor(
            servicio: salud, lecturas: repositorio, ancla: ancla
        ).ejecutar(ahora: ahora)

        #expect(resultado.guardadas == 0)
        #expect(await repositorio.guardadas.isEmpty)
        // El ancla no avanza con un lote que no se trajo.
        #expect(ancla.leer() == nil)
    }

    /// Prueba 6 · RF-07 — aunque la última lectura del sensor sea de hace cinco minutos, si
    /// Salud dejó de responder no se puede afirmar que siga llegando.
    @Test("6 · RF-07: si Salud lanza, el modo es sin sensor")
    func falloDeSaludDejaSinSensor() async throws {
        let salud = HealthKitFalso()
        let repositorio = RepositorioLecturasFalso()
        let ancla = anclaDePrueba()
        defer { borrar(ancla) }
        try await repositorio.guardar(LecturaGlucosaDato(
            mgDl: 120, tsUtc: ahora.addingTimeInterval(-5 * 60), origen: .sensor
        ))
        await salud.fallarLecturas(con: PermisoRevocado())

        let resultado = await SincronizarLecturasDelSensor(
            servicio: salud, lecturas: repositorio, ancla: ancla
        ).ejecutar(ahora: ahora)

        #expect(resultado.estado.modo == .sinSensor)
        // El histórico previo se conserva: revocar no borra nada (RF-07).
        #expect(await repositorio.guardadas.count == 1)
    }

    /// Prueba 14 · todo en mg/dL — 6 mmol/L entran como 108.1 mg/dL y nunca se guardan en
    /// la unidad de Salud.
    @Test("14 · mg/dL: una muestra en mmol/L entra convertida")
    func mmolLEntraConvertida() async throws {
        let salud = HealthKitFalso()
        let repositorio = RepositorioLecturasFalso()
        let ancla = anclaDePrueba()
        defer { borrar(ancla) }
        await salud.agregar([
            MuestraGlucosa(uuid: UUID(), valor: 6.0, unidad: .mmolL, ts: ahora)
        ])

        _ = await SincronizarLecturasDelSensor(
            servicio: salud, lecturas: repositorio, ancla: ancla
        ).ejecutar(ahora: ahora)

        let guardada = try #require(await repositorio.guardadas.first)
        #expect(abs(guardada.mgDl - 108.1092) < 0.0001)
    }

    /// Prueba 15 · el ancla — se guarda al terminar la pasada, sobrevive a un arranque nuevo
    /// y la siguiente consulta la usa para pedir solo lo nuevo.
    @Test("15 · ancla: se guarda y la siguiente consulta la reutiliza")
    func anclaSeGuardaYSeReutiliza() async throws {
        let salud = HealthKitFalso()
        let repositorio = RepositorioLecturasFalso()
        let ancla = anclaDePrueba()
        defer { borrar(ancla) }
        await salud.agregar([muestra(haceMin: 10), muestra(haceMin: 5)])

        let primera = await SincronizarLecturasDelSensor(
            servicio: salud, lecturas: repositorio, ancla: ancla
        ).ejecutar(ahora: ahora)
        #expect(primera.guardadas == 2)
        let guardada = try #require(ancla.leer())

        // Un arranque nuevo: otro caso de uso y otra `AnclaHealthKit` sobre el mismo dominio.
        await salud.agregar([muestra(haceMin: 0)])
        let tras = AnclaHealthKit(dominio: ancla.dominio)
        let segunda = await SincronizarLecturasDelSensor(
            servicio: salud, lecturas: repositorio, ancla: tras
        ).ejecutar(ahora: ahora)

        #expect(await salud.anclasRecibidas == [nil, guardada])
        #expect(segunda.guardadas == 1)
        #expect(await repositorio.guardadas.count == 3)
    }

    /// RF-07 — apagar la lectura del sensor en Ajustes, o elegir «sin sensor» en el alta, es
    /// de verdad dejar de leer: no se consulta Salud y el modo es sin sensor. Lo que ya
    /// estaba guardado se queda.
    @Test("RF-07: quien eligió «sin sensor» no lee de Salud, y su historial se queda")
    func sinSensorNoSeLeeDeSalud() async throws {
        let salud = HealthKitFalso()
        let repositorio = RepositorioLecturasFalso()
        let ancla = anclaDePrueba()
        defer { borrar(ancla) }
        await salud.agregar([muestra(mgDl: 134, haceMin: 3)])
        try await repositorio.guardar(LecturaGlucosaDato(mgDl: 120, tsUtc: ahora, origen: .manual))

        func pasada(usaSensor: Bool?) async -> ResultadoSincronizacion {
            let perfil = RepositorioPerfilFalso(usaSensor.map {
                PerfilDato(
                    fechaNacimiento: ReglasDePerfil.fechaDeAnio(1990), tipoUsuario: .tipo1,
                    usaSensor: $0, consentimientoTsUtc: ahora
                )
            })
            return await SincronizarLecturasDelSensor(
                servicio: salud, lecturas: repositorio, ancla: ancla, perfil: perfil
            ).ejecutar(ahora: ahora)
        }

        // Sin sensor, y también antes del alta, cuando todavía no hay perfil.
        for usaSensor in [false, nil] {
            let resultado = await pasada(usaSensor: usaSensor)
            #expect(resultado.guardadas == 0)
            #expect(!resultado.saludRespondio)
            #expect(resultado.estado.modo == .sinSensor)
        }
        #expect(await salud.anclasRecibidas.isEmpty)
        #expect(await repositorio.guardadas.count == 1)

        // Al encenderlo, entra lo del sensor y no se pierde nada de lo anterior.
        let conSensor = await pasada(usaSensor: true)
        #expect(conSensor.guardadas == 1)
        #expect(conSensor.saludRespondio)
        #expect(conSensor.estado.modo == .sensor)
        #expect(await repositorio.guardadas.count == 2)
    }

    // MARK: - La entrega en segundo plano (RF-10)

    /// Lo que la app hace al llegar una muestra nueva, anotado para poder contarlo. Es un
    /// `actor` porque el bloque que se registra en Salud es `@Sendable` y puede correr en
    /// cualquier hilo.
    private actor Anotador {
        private(set) var veces = 0
        private(set) var modos: [ModoApp] = []

        init() {}

        func anotar(_ resultado: ResultadoSincronizacion) {
            veces += 1
            modos.append(resultado.estado.modo)
        }
    }

    /// Las muestras de las dos pruebas de abajo van sobre el reloj de verdad y no sobre la
    /// fecha fija de las demás. `iniciar()` no recibe `ahora` a propósito: en la app arranca
    /// con el reloj del teléfono, y es lo que se quiere probar. Con la fecha fija, la muestra
    /// tendría más de un año de antigüedad, no pasaría la regla de frescura y el modo saldría
    /// sin sensor.
    private func muestraDeAhora(mgDl: Double, haceMin: Double) -> MuestraGlucosa {
        MuestraGlucosa(
            uuid: UUID(), valor: mgDl, ts: Date().addingTimeInterval(-haceMin * 60),
            esPropia: false
        )
    }

    @Test("RF-10: cada entrega con muestras nuevas llama a lo que decide si avisar")
    func cadaEntregaConMuestrasNuevasAvisa() async throws {
        let salud = HealthKitFalso()
        let repositorio = RepositorioLecturasFalso()
        let ancla = anclaDePrueba()
        defer { borrar(ancla) }
        await salud.agregar([muestraDeAhora(mgDl: 120, haceMin: 5)])

        let anotador = Anotador()
        let caso = SincronizarLecturasDelSensor(
            servicio: salud,
            lecturas: repositorio,
            ancla: ancla,
            alLlegarMuestrasNuevas: { resultado in
                await anotador.anotar(resultado)
            }
        )
        await caso.iniciar()

        // El observador queda registrado en el arranque: si no, la entrega se pierde y iOS no
        // vuelve a despertar la app por esa muestra.
        #expect(await salud.hayObservador)
        // Y la pasada del arranque ya contó, porque cuando iOS **relanza** la app para
        // entregar puede ser la única pasada que vea esa muestra.
        #expect(await anotador.veces == 1)
        // El modo se escribe aparte y no dentro del `#expect`: ahí dentro el comprobador de
        // tipos tiene que resolver el literal del arreglo a través de la macro.
        let modos: [ModoApp] = await anotador.modos
        #expect(modos == [ModoApp.sensor])

        // Llega otra muestra y iOS entrega.
        await salud.agregar([muestraDeAhora(mgDl: 112, haceMin: 1)])
        await salud.entregar()
        #expect(await anotador.veces == 2)

        // Una reentrega sin nada nuevo no vuelve a calcular: iOS reentrega la misma muestra, y
        // una pasada que no guardó nada no cambió la predicción.
        await salud.entregar()
        #expect(await anotador.veces == 2)
        #expect(await repositorio.guardadas.count == 2)
    }

    @Test("Quien no quiere que se lea su sensor no tiene observador ni vigilancia")
    func sinSensorNoHayObservador() async throws {
        let salud = HealthKitFalso()
        let repositorio = RepositorioLecturasFalso()
        let ancla = anclaDePrueba()
        defer { borrar(ancla) }
        await salud.agregar([muestraDeAhora(mgDl: 120, haceMin: 5)])
        let perfil = RepositorioPerfilFalso(PerfilDato(
            fechaNacimiento: ReglasDePerfil.fechaDeAnio(1990), tipoUsuario: .tipo1,
            usaSensor: false, consentimientoTsUtc: ahora
        ))

        let anotador = Anotador()
        let caso = SincronizarLecturasDelSensor(
            servicio: salud,
            lecturas: repositorio,
            ancla: ancla,
            perfil: perfil,
            alLlegarMuestrasNuevas: { resultado in
                await anotador.anotar(resultado)
            }
        )
        await caso.iniciar()

        #expect(await salud.hayObservador == false)
        #expect(await anotador.veces == 0)
    }
}
