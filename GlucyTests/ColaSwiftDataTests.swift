import Foundation
import SwiftData
import Testing
@testable import Glucy

/// La cola de sincronización. En el paso 2 **se llena y no se vacía**: no hay servidor
/// hasta la fase 2.
/// `ContenedorDependencias` es `@Observable` y vive en el hilo principal, como corresponde a algo
/// que van a consumir las vistas. Los repositorios de adentro son actores: que la prueba
/// corra en el principal no los ata a él.
@MainActor
struct ColaSwiftDataTests {

    private let ahora = Date(timeIntervalSince1970: 1_758_240_000)

    /// Prueba 6 · RF-20 — la app funciona completa sin conexión y lo capturado se queda
    /// esperando en la cola (caso P-07, modo avión). Guardar y encolar ocurren en la misma
    /// llamada: si se separaran, un cierre de la app entre las dos dejaría un registro que
    /// nunca sube y nadie se entera.
    @Test("6 · RF-20: guardar una lectura la deja encolada, una sola vez")
    func guardarEncolaUnaSolaVez() async throws {
        let dependencias = try ContenedorDependencias.enMemoria()
        let dato = LecturaGlucosaDato(mgDl: 112, tsUtc: ahora, origen: .manual)

        try await dependencias.lecturas.guardar(dato)
        #expect(try await dependencias.cola.contarPendientes() == 1)

        let pendientes = try await dependencias.cola.pendientes(limite: 10)
        #expect(pendientes.count == 1)
        #expect(pendientes.first?.uuidRegistro == dato.uuid)
        #expect(pendientes.first?.tipoRegistro == TipoRegistro.lecturaGlucosa)
        #expect(pendientes.first?.estado == .pendiente)
        #expect(pendientes.first?.intentos == 0)

        // Guardar el mismo UUID otra vez no agrega una segunda fila a la cola.
        try await dependencias.lecturas.guardar(dato)
        #expect(try await dependencias.cola.contarPendientes() == 1)
    }

    /// Prueba 9 · RF-20 — la cola se vacía en el orden en que se llenó, o el backend
    /// reconstruiría la serie desordenada.
    @Test("9 · RF-20: pendientes(limite:) entrega lo más antiguo primero")
    func pendientesEntregaLoMasAntiguoPrimero() async throws {
        let dependencias = try ContenedorDependencias.enMemoria()

        let primera = UUID()
        let segunda = UUID()
        let tercera = UUID()
        try await dependencias.cola.encolar(tipo: TipoRegistro.lecturaGlucosa, uuidRegistro: primera)
        try await dependencias.cola.encolar(tipo: TipoRegistro.comida, uuidRegistro: segunda)
        try await dependencias.cola.encolar(tipo: TipoRegistro.dosisInsulina, uuidRegistro: tercera)

        let todas = try await dependencias.cola.pendientes(limite: 10)
        #expect(todas.map(\.uuidRegistro) == [primera, segunda, tercera])

        // El límite corta por el final, no por el principio.
        let dos = try await dependencias.cola.pendientes(limite: 2)
        #expect(dos.map(\.uuidRegistro) == [primera, segunda])

        // Encolar el mismo registro dos veces no lo duplica.
        #expect(try await dependencias.cola.encolar(
            tipo: TipoRegistro.lecturaGlucosa, uuidRegistro: primera) == false)
        #expect(try await dependencias.cola.contarPendientes() == 3)
    }

    /// Prueba 13 · RF-36b — un fallo deja el motivo y se reintenta; la fila **no** se
    /// borra. Un dato rechazado sin rastro es una falla invisible (RF-22).
    ///
    /// La comprobación mira la base directamente, porque una fila en error ya no aparece
    /// entre las pendientes y el protocolo no tiene —ni debe tener— un método que exista
    /// solo para las pruebas.
    @Test("13 · RF-36b: marcarError guarda el motivo, sube intentos y no borra la fila")
    func marcarErrorDejaRastro() async throws {
        let contenedor = try ContenedorGlucy.crear(enMemoria: true)
        let dependencias = ContenedorDependencias(contenedor: contenedor)
        let dato = LecturaGlucosaDato(mgDl: 112, tsUtc: ahora, origen: .manual)
        try await dependencias.lecturas.guardar(dato)

        let fila = try #require(try await dependencias.cola.pendientes(limite: 1).first)
        try await dependencias.cola.marcarError(uuid: fila.uuid, motivo: "401 del servidor")

        // Ya no cuenta como pendiente...
        #expect(try await dependencias.cola.contarPendientes() == 0)

        // ...pero la fila sigue ahí, con su motivo y su intento.
        let contexto = ModelContext(contenedor)
        let filas = try contexto.fetch(FetchDescriptor<ColaSincronizacion>())
        #expect(filas.count == 1)
        let trasElError = try #require(filas.first)
        #expect(trasElError.estado == .error)
        #expect(trasElError.ultimoError == "401 del servidor")
        #expect(trasElError.intentos == 1)
        #expect(trasElError.ultimoIntentoTsUtc != nil)
        #expect(trasElError.uuidRegistro == dato.uuid)

        // Y la lectura original sigue en su tabla, intacta.
        #expect(try await dependencias.lecturas.contar() == 1)
    }

    /// Prueba 13 (continuación) · RF-36b — `marcarEnviado` la saca de pendientes sin
    /// borrarla: solo sale de la cola cuando el servidor confirma.
    @Test("13 · RF-36b: marcarEnviado saca la fila de pendientes sin borrarla")
    func marcarEnviadoNoBorra() async throws {
        let contenedor = try ContenedorGlucy.crear(enMemoria: true)
        let dependencias = ContenedorDependencias(contenedor: contenedor)
        try await dependencias.comidas.guardar(ComidaDato(tsUtc: ahora, carbsG: 45, origen: .manual))

        let fila = try #require(try await dependencias.cola.pendientes(limite: 1).first)
        try await dependencias.cola.marcarEnviado(uuid: fila.uuid)

        #expect(try await dependencias.cola.contarPendientes() == 0)

        let contexto = ModelContext(contenedor)
        let filas = try contexto.fetch(FetchDescriptor<ColaSincronizacion>())
        #expect(filas.count == 1)
        #expect(filas.first?.estado == .enviado)
        #expect(try await dependencias.comidas.contar() == 1)
    }
}
