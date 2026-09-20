import Foundation
import Testing
@testable import Glucy

/// Idempotencia del lado del teléfono.
///
/// Importa antes de que exista el servidor: HealthKit reentrega las mismas muestras y la
/// persona puede tocar «guardar» dos veces. Un duplicado es normal, no una falla, y por eso
/// `guardar` devuelve `false` en vez de lanzar.
/// `ContenedorDependencias` es `@Observable` y vive en el hilo principal, como corresponde a algo
/// que van a consumir las vistas. Los repositorios de adentro son actores: que la prueba
/// corra en el principal no los ata a él.
@MainActor
struct IdempotenciaTests {

    private let ahora = Date(timeIntervalSince1970: 1_758_240_000)

    /// Prueba 5 · RF-36c — el mismo UUID dos veces deja una sola fila.
    @Test("5 · RF-36c: guardar dos veces el mismo UUID devuelve false y deja una sola fila")
    func mismoUuidDosVecesDejaUnaSolaFila() async throws {
        let dependencias = try ContenedorDependencias.enMemoria()
        let dato = LecturaGlucosaDato(mgDl: 112, tsUtc: ahora, origen: .sensor)

        #expect(try await dependencias.lecturas.guardar(dato))
        #expect(try await dependencias.lecturas.guardar(dato) == false)
        #expect(try await dependencias.lecturas.contar() == 1)
        #expect(try await dependencias.cola.contarPendientes() == 1)
    }

    /// Prueba 5 (continuación) · RF-36c — lo mismo en comidas y en dosis. Si solo lo
    /// cumpliera una de las tres tablas, el duplicado aparecería en la primera captura por
    /// código de barras.
    @Test("5 · RF-36c: la idempotencia vale igual en comidas y en dosis")
    func idempotenciaEnComidasYDosis() async throws {
        let dependencias = try ContenedorDependencias.enMemoria()

        let comida = ComidaDato(tsUtc: ahora, carbsG: 60, origen: .barcode)
        #expect(try await dependencias.comidas.guardar(comida))
        #expect(try await dependencias.comidas.guardar(comida) == false)
        #expect(try await dependencias.comidas.contar() == 1)

        let dosis = DosisInsulinaDato(tsUtc: ahora, unidades: 6, tipo: .bolo, motivo: .comida)
        #expect(try await dependencias.dosis.guardar(dosis))
        #expect(try await dependencias.dosis.guardar(dosis) == false)
        #expect(try await dependencias.dosis.contar() == 1)

        // Dos registros distintos, dos filas en la cola. Ni una más.
        #expect(try await dependencias.cola.contarPendientes() == 2)
    }

    /// Prueba 5 (continuación) · RF-36c — un UUID distinto con el mismo contenido **sí**
    /// se guarda: dos pinchazos iguales a la misma hora son posibles, y decidir que son el
    /// mismo sería perder un dato real.
    @Test("5 · RF-36c: mismo contenido con otro UUID sí se guarda")
    func mismoContenidoConOtroUuidSeGuarda() async throws {
        let dependencias = try ContenedorDependencias.enMemoria()

        try await dependencias.lecturas.guardar(
            LecturaGlucosaDato(mgDl: 112, tsUtc: ahora, origen: .manual))
        try await dependencias.lecturas.guardar(
            LecturaGlucosaDato(mgDl: 112, tsUtc: ahora, origen: .manual))

        #expect(try await dependencias.lecturas.contar() == 2)
        #expect(try await dependencias.cola.contarPendientes() == 2)
    }
}
