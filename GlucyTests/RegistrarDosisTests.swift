import Foundation
import Testing
@testable import Glucy

/// El registro de una dosis. Aquí se comprueba lo que no se negocia: Glucy **anota** lo que
/// la persona dice haberse aplicado, no adivina el motivo, y nada se guarda sin pasar por
/// `RegistrarDosis` (regla 7).
///
/// La prueba 23 —que no exista otra forma de crear una dosis— no está aquí: es un `grep`
/// sobre el código y vive en `scripts/regla-7.sh`, que la integración continua corre antes
/// de compilar.
@MainActor
struct RegistrarDosisTests {

    private let ahora = Date(timeIntervalSince1970: 1_758_240_000)

    private func montar(
        salud: HealthKitFalso = HealthKitFalso()
    ) throws -> ContenedorDependencias {
        ContenedorDependencias(
            contenedor: try ContenedorGlucy.crear(enMemoria: true), salud: salud
        )
    }

    private func pantalla(_ dependencias: ContenedorDependencias) -> RegistroInsulinaViewModel {
        RegistroInsulinaViewModel(
            registrar: dependencias.registrarDosis,
            calcular: dependencias.calcularInsulinaActiva,
            ajustes: dependencias.ajustesDeInsulina
        )
    }

    private func perfil(duracionH: Double, registraInsulina: Bool = true) -> PerfilDato {
        PerfilDato(
            uuid: Self.uuidDelPerfil,
            fechaNacimiento: Date(timeIntervalSince1970: 800_000_000),
            tipoUsuario: .tipo1,
            duracionAccionInsulinaH: duracionH,
            registraInsulina: registraInsulina
        )
    }

    private static let uuidDelPerfil = UUID()

    @Test("1 · RF-14: 4 UI de bolo se guardan con su hora, su tipo y su zona horaria")
    func laDosisSeGuardaCompleta() async throws {
        let dependencias = try montar()
        let hace10min = ahora.addingTimeInterval(-600)

        let dato = try await dependencias.registrarDosis.ejecutar(
            unidades: 4, tsUtc: hace10min, tipo: .bolo, motivo: .comida,
            duracionAccionH: 5, ahora: ahora
        )

        let leida = try #require(try await dependencias.dosis.porUuid(dato.uuid))
        #expect(leida.unidades == 4)
        #expect(leida.tipo == .bolo)
        #expect(leida.tsUtc == hace10min)
        // Las dos cosas, siempre (regla 5).
        #expect(leida.zonaHoraria == TimeZone.current.identifier)
        // El origen lo puso el caso de uso (regla 4).
        #expect(leida.origen == .manual)
        #expect(leida.motivo == .comida)
        #expect(try await dependencias.cola.contarPendientes() == 1)
    }

    @Test("2 · RF-14: el motivo se puede dejar en nil y la dosis se guarda igual")
    func elMotivoSePuedeDejarEnBlanco() async throws {
        let dependencias = try montar()

        let dato = try await dependencias.registrarDosis.ejecutar(
            unidades: 12, tsUtc: ahora, tipo: .basal, motivo: nil,
            duracionAccionH: 5, ahora: ahora
        )
        let leida = try #require(try await dependencias.dosis.porUuid(dato.uuid))
        // Ni «programada» por ser basal, ni ningún otro: no se adivina.
        #expect(leida.motivo == nil)

        // Y desde la pantalla: quien no toca ningún motivo guarda sin motivo.
        let modelo = pantalla(dependencias)
        modelo.textoUnidades = "4"
        modelo.tipo = .bolo
        await modelo.guardar(ahora: ahora)

        let dePantalla = try #require(modelo.ultimaGuardada)
        #expect(dePantalla.motivo == nil)
        #expect(try await dependencias.dosis.contar() == 2)
    }

    @Test("3 · RF-14: 0 unidades no se guarda")
    func ceroUnidadesNoSeGuarda() async throws {
        let dependencias = try montar()

        await #expect(throws: FalloRegistro.unidadesVacias) {
            try await dependencias.registrarDosis.ejecutar(
                unidades: 0, tsUtc: ahora, tipo: .bolo, motivo: nil,
                duracionAccionH: 5, ahora: ahora
            )
        }
        #expect(try await dependencias.dosis.contar() == 0)
        #expect(try await dependencias.cola.contarPendientes() == 0)

        // El mismo mensaje que el campo vacío: cero unidades no es una dosis.
        let modelo = pantalla(dependencias)
        modelo.tipo = .bolo
        await modelo.guardar(ahora: ahora)
        #expect(modelo.fallo?.mensaje == "Escribe cuántas unidades te aplicaste.")
        #expect(FalloRegistro.unidadesVacias.mensaje == modelo.fallo?.mensaje)
    }

    @Test("4 · RF-14: 60 unidades no se guarda")
    func sesentaUnidadesNoSeGuarda() async throws {
        let dependencias = try montar()

        await #expect(throws: FalloRegistro.unidadesFueraDeRango) {
            try await dependencias.registrarDosis.ejecutar(
                unidades: 60, tsUtc: ahora, tipo: .bolo, motivo: nil,
                duracionAccionH: 5, ahora: ahora
            )
        }
        #expect(try await dependencias.dosis.contar() == 0)

        // El límite sí entra, y lo siguiente que la pluma puede dosificar ya no.
        #expect(Validacion.validarDosis(unidades: 50, tsUtc: ahora, ahora: ahora) == nil)
        #expect(Validacion.validarDosis(unidades: 50.5, tsUtc: ahora, ahora: ahora)
            == .fueraDeRango(valor: 50.5))
        // El mensaje dice qué hacer con el campo, no con el cuerpo.
        #expect(FalloRegistro.unidadesFueraDeRango.mensaje
            == "Esa cantidad está fuera de lo que Glucy registra. Revisa el número.")
    }

    @Test("5 · RF-14: 2.3 unidades no se guarda, no es múltiplo de 0.5")
    func fueraDeLaResolucionNoSeGuarda() async throws {
        let dependencias = try montar()

        await #expect(throws: FalloRegistro.unidadesFueraDeResolucion) {
            try await dependencias.registrarDosis.ejecutar(
                unidades: 2.3, tsUtc: ahora, tipo: .bolo, motivo: nil,
                duracionAccionH: 5, ahora: ahora
            )
        }
        #expect(try await dependencias.dosis.contar() == 0)

        #expect(Validacion.validarDosis(unidades: 2.5, tsUtc: ahora, ahora: ahora) == nil)
        #expect(Validacion.validarDosis(unidades: 0.5, tsUtc: ahora, ahora: ahora) == nil)
    }

    @Test("6 · RF-05: una hora futura no se guarda")
    func horaFuturaNoSeGuarda() async throws {
        let dependencias = try montar()

        await #expect(throws: FalloRegistro.horaFutura) {
            try await dependencias.registrarDosis.ejecutar(
                unidades: 4, tsUtc: ahora.addingTimeInterval(60), tipo: .bolo, motivo: nil,
                duracionAccionH: 5, ahora: ahora
            )
        }
        #expect(try await dependencias.dosis.contar() == 0)
    }

    @Test("7 · RF-14: la dosis guarda la duración de acción del momento, no la de después")
    func guardaLaDuracionDelMomento() async throws {
        let dependencias = try montar()
        try await dependencias.perfil.guardar(perfil(duracionH: 6))

        let modelo = pantalla(dependencias)
        modelo.textoUnidades = "4"
        modelo.tipo = .bolo
        await modelo.guardar(ahora: ahora)

        let guardada = try #require(modelo.ultimaGuardada)
        #expect(guardada.duracionAccionH == 6)

        // Mañana el perfil la mueve. La dosis de hoy sigue con la suya.
        try await dependencias.perfil.guardar(perfil(duracionH: 3))
        #expect(try await dependencias.dosis.porUuid(guardada.uuid)?.duracionAccionH == 6)
    }

    @Test("16 · RF-15b: «Deshacer» borra la dosis y la quita de Salud")
    func deshacerLaQuitaDeTodosLados() async throws {
        let salud = HealthKitFalso()
        let dependencias = try montar(salud: salud)

        let dato = try await dependencias.registrarDosis.ejecutar(
            unidades: 4, tsUtc: ahora, tipo: .bolo, motivo: nil,
            duracionAccionH: 5, ahora: ahora
        )
        #expect(await salud.insulinaEnSalud[dato.uuid] != nil)
        #expect(try await dependencias.dosis.porUuid(dato.uuid)?.escritaEnHealthKit == true)

        try await dependencias.registrarDosis.deshacer(dato)

        #expect(try await dependencias.dosis.contar() == 0)
        // La fila de la cola se va con ella: el backend no recibe una dosis que ya no existe.
        #expect(try await dependencias.cola.contarPendientes() == 0)
        #expect(await salud.insulinaEnSalud.isEmpty)
    }

    @Test("17 · regla 1: si Salud lanza, la dosis sigue guardada y no sube el error")
    func siSaludFallaLaDosisSeQueda() async throws {
        let salud = HealthKitFalso()
        await salud.fallarEscrituras(con: PermisoRevocado())
        let dependencias = try montar(salud: salud)

        // No lanza: si lanzara, esta línea tumbaría la prueba.
        let dato = try await dependencias.registrarDosis.ejecutar(
            unidades: 4, tsUtc: ahora, tipo: .bolo, motivo: nil,
            duracionAccionH: 5, ahora: ahora
        )

        let leida = try #require(try await dependencias.dosis.porUuid(dato.uuid))
        #expect(leida.unidades == 4)
        // Y no queda anotada como escrita: no lo está.
        #expect(leida.escritaEnHealthKit == false)
        #expect(await salud.insulinaEnSalud.isEmpty)
    }

    @Test("19 · RF-14: con registraInsulina en false el selector no dibuja la opción")
    func elSelectorEscondeLaInsulina() async throws {
        #expect(TipoDeRegistro.disponibles(registraInsulina: false) == [.glucosa, .comida])
        #expect(TipoDeRegistro.disponibles(registraInsulina: true) == [.glucosa, .comida, .insulina])

        // Sin perfil se muestra: el usuario principal es quien sí la usa.
        let dependencias = try montar()
        #expect(await dependencias.ajustesDeInsulina.registraInsulina())

        try await dependencias.perfil.guardar(perfil(duracionH: 5, registraInsulina: false))
        #expect(await dependencias.ajustesDeInsulina.registraInsulina() == false)
        #expect(try await dependencias.perfil.actual()?.registraInsulina == false)
    }
}
