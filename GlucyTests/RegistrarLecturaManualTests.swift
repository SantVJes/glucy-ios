import Foundation
import Testing
@testable import Glucy

/// El caso de uso de la captura manual. Aquí vive la única llamada a la validación, así
/// que aquí se comprueba que la regla del paso 1 se está usando de verdad.
struct RegistrarLecturaManualTests {

    private let ahora = Date(timeIntervalSince1970: 1_758_240_000)

    /// Prueba 1 · RF-01 — el criterio de «hecho»: se guarda y vuelve con su UUID.
    @Test("1 · RF-01: una lectura válida se guarda y vuelve con su UUID")
    func lecturaValidaSeGuarda() async throws {
        let repositorio = RepositorioLecturasFalso()
        let caso = RegistrarLecturaManual(repositorio: repositorio)

        let guardada = try await caso.ejecutar(
            mgDl: 112, tsUtc: ahora, contexto: .enAyunas, ahora: ahora
        )

        #expect(guardada.mgDl == 112)
        let enRepositorio = await repositorio.guardadas
        #expect(enRepositorio.count == 1)
        #expect(enRepositorio.first?.uuid == guardada.uuid)
    }

    /// Prueba 2 · RF-01 — el contexto es opcional: con etiqueta y sin ella.
    @Test("2 · RF-01: se guarda con el contexto elegido, y también sin ninguno")
    func contextoEsOpcional() async throws {
        let repositorio = RepositorioLecturasFalso()
        let caso = RegistrarLecturaManual(repositorio: repositorio)

        let conEtiqueta = try await caso.ejecutar(
            mgDl: 112, tsUtc: ahora, contexto: .dosHorasDespues, ahora: ahora
        )
        #expect(conEtiqueta.contexto == .dosHorasDespues)

        let sinEtiqueta = try await caso.ejecutar(
            mgDl: 98, tsUtc: ahora, contexto: nil, ahora: ahora
        )
        #expect(sinEtiqueta.contexto == nil)

        // Las cinco etiquetas son las del paso 1: ni una más, ni una menos (RF-01).
        #expect(ContextoComida.allCases.count == 5)
    }

    /// Prueba 3 · RF-04 — el origen lo pone el caso de uso, no quien lo llama. Es la única
    /// forma de garantizar que ninguna lectura entre sin él.
    @Test("3 · RF-04: lo guardado por esta pantalla siempre lleva origen manual")
    func siempreOrigenManual() async throws {
        let repositorio = RepositorioLecturasFalso()
        let caso = RegistrarLecturaManual(repositorio: repositorio)

        let guardada = try await caso.ejecutar(
            mgDl: 112, tsUtc: ahora, contexto: nil, ahora: ahora
        )

        #expect(guardada.origen == .manual)
        #expect(await repositorio.guardadas.allSatisfy { $0.origen == .manual })
    }

    /// Prueba 4 · RF-05, caso **P-02** — el que no puede fallar. Y no basta con que
    /// devuelva el mensaje: el repositorio **no se toca**, porque lo que no es válido no
    /// llega ni a la base ni a la cola.
    @Test("4 · RF-05 (P-02): 900 mg/dL no se guarda y devuelve el mensaje del rango")
    func P02_novecientosNoSeGuarda() async throws {
        let repositorio = RepositorioLecturasFalso()
        let caso = RegistrarLecturaManual(repositorio: repositorio)

        await #expect(throws: FalloRegistro.fueraDeRango) {
            try await caso.ejecutar(mgDl: 900, tsUtc: ahora, contexto: nil, ahora: ahora)
        }

        #expect(await repositorio.guardadas.isEmpty)

        // El texto, palabra por palabra: es el que se lee a las tres de la mañana.
        #expect(FalloRegistro.fueraDeRango.mensaje == "Ese valor está fuera de lo que un "
            + "medidor puede leer. Anota un número entre 20 y 600 mg/dL.")
        #expect(FalloRegistro.fueraDeRango.campo == .valor)
    }

    /// Prueba 5 · RF-05 — los extremos son válidos y no hay que apretarlos.
    @Test("5 · RF-05: 20 y 600 sí se guardan")
    func losExtremosSeGuardan() async throws {
        let repositorio = RepositorioLecturasFalso()
        let caso = RegistrarLecturaManual(repositorio: repositorio)

        let minimo = try await caso.ejecutar(mgDl: 20, tsUtc: ahora, contexto: nil, ahora: ahora)
        let maximo = try await caso.ejecutar(mgDl: 600, tsUtc: ahora, contexto: nil, ahora: ahora)

        #expect(minimo.mgDl == 20)
        #expect(maximo.mgDl == 600)
        #expect(await repositorio.guardadas.count == 2)
    }

    /// Prueba 6 · RF-05 — una hora futura no se guarda, y el mensaje señala la fecha, no el
    /// valor: llevar a corregir al campo equivocado es peor que no decir nada.
    @Test("6 · RF-05: una hora futura no se guarda y señala el campo de la fecha")
    func horaFuturaNoSeGuarda() async throws {
        let repositorio = RepositorioLecturasFalso()
        let caso = RegistrarLecturaManual(repositorio: repositorio)

        await #expect(throws: FalloRegistro.horaFutura) {
            try await caso.ejecutar(
                mgDl: 112,
                tsUtc: ahora.addingTimeInterval(60),
                contexto: nil,
                ahora: ahora
            )
        }

        #expect(await repositorio.guardadas.isEmpty)
        #expect(FalloRegistro.horaFutura.campo == .fecha)
        #expect(FalloRegistro.horaFutura.mensaje == "Esa hora todavía no llega. Revisa la fecha.")
    }

    /// Prueba 7 · RF-20 y RF-36b, caso **P-07** — lo guardado nace en `pendiente` y queda
    /// en la cola. Esta va contra los repositorios de verdad, no contra el doble: es la
    /// prueba de que las tres capas están unidas.
    @Test("7 · RF-20 (P-07): lo guardado nace en pendiente y queda en la cola")
    @MainActor
    func loGuardadoQuedaEnLaCola() async throws {
        let dependencias = try ContenedorDependencias.enMemoria()
        let caso = RegistrarLecturaManual(repositorio: dependencias.lecturas)

        let guardada = try await caso.ejecutar(
            mgDl: 112, tsUtc: ahora, contexto: .enAyunas, ahora: ahora
        )

        #expect(guardada.syncEstado == .pendiente)
        #expect(try await dependencias.lecturas.contar() == 1)
        #expect(try await dependencias.cola.contarPendientes() == 1)

        let enCola = try await dependencias.cola.pendientes(limite: 10)
        #expect(enCola.first?.uuidRegistro == guardada.uuid)
        #expect(enCola.first?.tipoRegistro == TipoRegistro.lecturaGlucosa)
    }

    /// Prueba 8 · regla 5 — UTC **y** zona horaria, siempre las dos.
    @Test("8 · RF-01: lo guardado conserva tsUtc y zonaHoraria")
    func seConservanFechaYZona() async throws {
        let repositorio = RepositorioLecturasFalso()
        let caso = RegistrarLecturaManual(repositorio: repositorio)

        let guardada = try await caso.ejecutar(
            mgDl: 112, tsUtc: ahora, contexto: nil, ahora: ahora
        )

        #expect(guardada.tsUtc == ahora)
        #expect(guardada.zonaHoraria == TimeZone.current.identifier)
        #expect(guardada.zonaHoraria.isEmpty == false)
    }

    /// Deshacer borra la lectura y su fila de la cola: una lectura borrada que dejara su
    /// fila subiría al backend un registro que en el teléfono ya no existe.
    @Test("RF-20: deshacer borra la lectura y la saca de la cola")
    @MainActor
    func deshacerBorraLaLecturaYLaCola() async throws {
        let dependencias = try ContenedorDependencias.enMemoria()
        let caso = RegistrarLecturaManual(repositorio: dependencias.lecturas)

        let guardada = try await caso.ejecutar(
            mgDl: 112, tsUtc: ahora, contexto: nil, ahora: ahora
        )
        try await caso.deshacer(guardada)

        #expect(try await dependencias.lecturas.contar() == 0)
        #expect(try await dependencias.cola.contarPendientes() == 0)
    }
}
