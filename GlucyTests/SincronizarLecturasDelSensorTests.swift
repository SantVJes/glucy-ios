import Foundation
import Testing
@testable import Glucy

/// Traer de Salud y guardar en el teléfono. Sin dispositivo y sin HealthKit: todo pasa por
/// el doble.
struct SincronizarLecturasDelSensorTests {

    private let ahora = Date(timeIntervalSince1970: 1_758_240_000)

    /// Un dominio de `UserDefaults` por prueba, para que el ancla de una no se cuele en otra
    /// ni en la de la app.
    private func anclaDePrueba() -> AnclaHealthKit {
        AnclaHealthKit(dominio: "glucy.pruebas.\(UUID().uuidString)")
    }

    private func borrar(_ ancla: AnclaHealthKit) {
        if let dominio = ancla.dominio {
            UserDefaults.standard.removePersistentDomain(forName: dominio)
        }
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
}
