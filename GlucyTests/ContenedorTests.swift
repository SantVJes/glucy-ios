import Foundation
import SwiftData
import Testing
@testable import Glucy

/// El contenedor de SwiftData. Todas las pruebas del paso 2 levantan el suyo **en
/// memoria**: no tocan el disco y no dependen del orden en que corran.
/// `ContenedorDependencias` es `@Observable` y vive en el hilo principal, como corresponde a algo
/// que van a consumir las vistas. Los repositorios de adentro son actores: que la prueba
/// corra en el principal no los ata a él.
@MainActor
struct ContenedorTests {

    /// Prueba 1 · RF-20 — la app funciona completa sin conexión, y eso empieza por tener
    /// base local. Una tabla que falta no falla al arrancar: falla lejos, al primer acceso.
    @Test("1 · RF-20: el contenedor se crea en memoria con las diez tablas")
    func contenedorTieneLasDiezTablas() throws {
        let contenedor = try ContenedorGlucy.crear(enMemoria: true)
        let entidades = contenedor.schema.entities.map(\.name).sorted()

        #expect(entidades.count == 10)
        #expect(entidades == [
            "Alerta", "ColaSincronizacion", "ColaXapi", "Comida", "DosisInsulina",
            "EventoContexto", "LecturaGlucosa", "Perfil", "PrediccionCache", "ProductoCache"
        ])
    }

    /// Prueba 7 · RF-36b — lo que identifica a la persona nace `local` y no entra a la
    /// cola. Es la regla 3 hecha comprobación.
    @Test("7 · RF-36b: el perfil nace local y no aparece en la cola")
    func perfilNaceLocalYNoSeEncola() async throws {
        let dependencias = try ContenedorDependencias.enMemoria()

        // Aunque quien llama insista en `pendiente`, el repositorio lo deja en `local`.
        let dato = PerfilDato(
            nombre: "Santiago",
            apellidos: "Velasco",
            pesoKg: 70,
            fechaNacimiento: Date(timeIntervalSince1970: 800_000_000),
            tipoUsuario: .tipo1,
            syncEstado: .pendiente
        )
        try await dependencias.perfil.guardar(dato)

        let guardado = try await dependencias.perfil.actual()
        #expect(guardado?.syncEstado == .local)
        #expect(guardado?.nombre == "Santiago")
        #expect(try await dependencias.perfil.existe())
        #expect(try await dependencias.cola.contarPendientes() == 0)
    }

    /// Prueba 8 · RF-36b — el caché de Open Food Facts es dato de un tercero, no de la
    /// persona (grupo C): nace `local` y no se encola.
    @Test("8 · RF-36b: ProductoCache nace local y no aparece en la cola")
    func productoCacheNaceLocalYNoSeEncola() async throws {
        // Un solo contenedor: el mismo que ven los repositorios, o la comprobación de la
        // cola no diría nada.
        let contenedor = try ContenedorGlucy.crear(enMemoria: true)
        let dependencias = ContenedorDependencias(contenedor: contenedor)
        let contexto = ModelContext(contenedor)

        let producto = ProductoCache(
            codigoBarras: "7501055310005",
            nombre: "Galletas de avena",
            carbsPor100g: 68
        )
        contexto.insert(producto)
        try contexto.save()

        #expect(producto.syncEstado == .local)
        #expect(try await dependencias.cola.contarPendientes() == 0)
    }
}
