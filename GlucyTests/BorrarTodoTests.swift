import Foundation
import Testing
@testable import Glucy

/// Borrar la cuenta: la única acción irreversible de la app. Tiene que borrar de verdad,
/// quitar de Salud lo que Glucy escribió, y decir la verdad si Salud falla.
@MainActor
struct BorrarTodoTests {

    private let ahora = Date(timeIntervalSince1970: 1_758_240_000)
    private let codigo = "3017620422003"

    /// Una app con datos dentro: perfil, dos lecturas, una comida, una dosis y un producto
    /// consultado. Todo sobre SwiftData en memoria, que es lo que se va a borrar.
    private func appConDatos(
        salud: HealthKitFalso
    ) async throws -> (ContenedorDependencias, AnclaHealthKit) {
        let ancla = AnclaHealthKit(dominio: "glucy.pruebas.\(UUID().uuidString)")
        let dependencias = ContenedorDependencias(
            contenedor: try ContenedorGlucy.crear(enMemoria: true), salud: salud, ancla: ancla
        )
        try await dependencias.completarAlta.ejecutar(
            nombre: "Ana", apellidos: "Ruiz", tipoUsuario: .tipo1, anioNacimiento: 1990,
            pesoKg: 62, unidadPreferida: .mgDl, usaSensor: true, aceptaConsentimiento: true,
            ahora: ahora
        )
        _ = try await dependencias.registrarManual.ejecutar(mgDl: 112, tsUtc: ahora, contexto: nil, ahora: ahora)
        _ = try await dependencias.registrarManual.ejecutar(
            mgDl: 140, tsUtc: ahora.addingTimeInterval(-3600), contexto: nil, ahora: ahora
        )
        _ = try await dependencias.registrarComida.ejecutar(carbsG: 45, tsUtc: ahora, origen: .manual, ahora: ahora)
        try await dependencias.registrarDosis.ejecutar(
            unidades: 4, tsUtc: ahora, tipo: .bolo, motivo: nil, duracionAccionH: 5, ahora: ahora
        )
        try await dependencias.productos.guardar(ProductoCacheDato(noEncontrado: codigo, consultadoTsUtc: ahora))
        ancla.guardar(Data("7".utf8))
        return (dependencias, ancla)
    }

    @Test("20 · borrar la cuenta deja los repositorios en cero")
    func borraDeVerdad() async throws {
        let (dependencias, ancla) = try await appConDatos(salud: HealthKitFalso())
        defer { ancla.borrar() }
        #expect(try await dependencias.cola.contarPendientes() == 4)

        try await dependencias.borrarTodo.ejecutar()

        #expect(try await dependencias.lecturas.contar() == 0)
        #expect(try await dependencias.comidas.contar() == 0)
        #expect(try await dependencias.dosis.contar() == 0)
        #expect(try await dependencias.cola.contarPendientes() == 0)
        #expect(try await dependencias.perfil.existe() == false)
        // Lo consultado por código de barras también se va.
        #expect(try await dependencias.productos.porCodigo(codigo) == nil)
        // Y el ancla de Salud: quien vuelva con su sensor recibe otra vez su historial.
        #expect(ancla.leer() == nil)
        // La puerta vuelve a estar cerrada: la app queda como recién instalada.
        #expect(await dependencias.consultarEntrada.ejecutar().consintio == false)
    }

    @Test("21 · RF-15b: borrar la cuenta pide a Salud, una vez, quitar lo que Glucy escribió")
    func quitaLoPropioDeSalud() async throws {
        let salud = HealthKitFalso()
        let (dependencias, ancla) = try await appConDatos(salud: salud)
        defer { ancla.borrar() }
        #expect(await salud.escritas.count == 2)
        #expect(await salud.insulinaEnSalud.count == 1)

        let resultado = try await dependencias.borrarTodo.ejecutar()

        #expect(resultado.saludLimpia)
        #expect(await salud.vecesBorradoLoPropio == 1)
        #expect(await salud.escritas.isEmpty)
        #expect(await salud.carbohidratosEnSalud.isEmpty)
        #expect(await salud.insulinaEnSalud.isEmpty)
    }

    @Test("22 · si Salud falla, lo local se borra igual y el resultado lo dice")
    func saludFallaYSeDice() async throws {
        let salud = HealthKitFalso()
        let (dependencias, ancla) = try await appConDatos(salud: salud)
        defer { ancla.borrar() }
        await salud.fallarEscrituras(con: PermisoRevocado())

        let resultado = try await dependencias.borrarTodo.ejecutar()

        #expect(resultado == ResultadoDeBorrado(saludLimpia: false))
        #expect(await salud.vecesBorradoLoPropio == 1)
        #expect(try await dependencias.lecturas.contar() == 0)
        #expect(try await dependencias.comidas.contar() == 0)
        #expect(try await dependencias.dosis.contar() == 0)
        #expect(try await dependencias.perfil.existe() == false)
    }

    @Test("23 · el borrado enumera cuántas lecturas, comidas y dosis hay de verdad")
    func lasCifrasDelBorrado() async throws {
        let (dependencias, ancla) = try await appConDatos(salud: HealthKitFalso())
        defer { ancla.borrar() }

        let cuanto = try await dependencias.consultarCuantoHay.ejecutar()
        #expect(cuanto == CuantoHay(lecturas: 2, comidas: 1, dosis: 1))

        let modelo = BorrarCuentaViewModel(
            cuantoHay: dependencias.consultarCuantoHay, borrarTodo: dependencias.borrarTodo
        )
        await modelo.cargar()
        #expect(modelo.textoDeLoQueSePierde
            == "Vas a borrar 2 lecturas, 1 comida y 1 dosis, tu perfil y tus ajustes.")

        // Sin teclear la palabra no se borra nada.
        #expect(!modelo.puedeBorrar)
        modelo.textoDeConfirmacion = "si"
        #expect(await modelo.borrar() == false)
        #expect(try await dependencias.lecturas.contar() == 2)

        modelo.textoDeConfirmacion = "Borrar "
        #expect(modelo.puedeBorrar)
        #expect(await modelo.borrar())
        #expect(try await dependencias.consultarCuantoHay.ejecutar() == CuantoHay(lecturas: 0, comidas: 0, dosis: 0))
    }

    /// El token es una credencial para una serie que en el servidor sigue existiendo:
    /// dejarlo en el Keychain de un teléfono que ya no tiene la cuenta es dejar la llave
    /// puesta.
    @Test("Borrar la cuenta también borra el token del backend")
    func borrarTambienBorraElToken() async throws {
        let almacen = AlmacenFalso(token: "un.token.cualquiera")
        let salud = HealthKitFalso()
        let (dependencias, _) = try await appConDatos(salud: salud)
        let borrar = BorrarTodo(
            perfil: dependencias.perfil,
            lecturas: dependencias.lecturas,
            comidas: dependencias.comidas,
            dosis: dependencias.dosis,
            cola: dependencias.cola,
            productos: dependencias.productos,
            salud: salud,
            almacenDeToken: almacen
        )

        #expect(almacen.token() != nil)
        _ = try await borrar.ejecutar()
        #expect(almacen.token() == nil)
    }
}
