import Foundation
import Testing
@testable import Glucy

/// El repositorio de lecturas de glucosa.
/// `ContenedorDependencias` es `@Observable` y vive en el hilo principal, como corresponde a algo
/// que van a consumir las vistas. Los repositorios de adentro son actores: que la prueba
/// corra en el principal no los ata a él.
@MainActor
struct LecturasSwiftDataTests {

    private let ahora = Date(timeIntervalSince1970: 1_758_240_000)

    /// Prueba 2 · RF-36b — es el criterio de «hecho» del plan: se guarda, se vuelve a leer
    /// con su UUID y nace en `pendiente`.
    @Test("2 · RF-36b: la lectura se guarda y se relee con su UUID, en pendiente")
    func lecturaSeGuardaYSeRelee() async throws {
        let dependencias = try ContenedorDependencias.enMemoria()
        let dato = LecturaGlucosaDato(mgDl: 112, tsUtc: ahora, origen: .manual)

        let guardada = try await dependencias.lecturas.guardar(dato)
        #expect(guardada)

        let leida = try await dependencias.lecturas.porUuid(dato.uuid)
        #expect(leida?.uuid == dato.uuid)
        #expect(leida?.mgDl == 112)
        #expect(leida?.origen == .manual)
        #expect(leida?.syncEstado == .pendiente)
        #expect(try await dependencias.lecturas.contar() == 1)
    }

    /// Prueba 10 · RF-20 — HealthKit entrega en bloques y con retraso, así que lo último
    /// que llega no es lo último que ocurrió (RF-06b). `ultima()` va por `tsUtc`.
    @Test("10 · RF-20: ultima() devuelve la de tsUtc mayor, no la insertada al último")
    func ultimaVaPorFechaNoPorInsercion() async throws {
        let dependencias = try ContenedorDependencias.enMemoria()

        // Se inserta primero la más nueva y después una vieja, como haría un bloque
        // retrasado de HealthKit.
        let nueva = LecturaGlucosaDato(mgDl: 145, tsUtc: ahora, origen: .sensor)
        let vieja = LecturaGlucosaDato(
            mgDl: 90, tsUtc: ahora.addingTimeInterval(-3600), origen: .sensor
        )
        try await dependencias.lecturas.guardar(nueva)
        try await dependencias.lecturas.guardar(vieja)

        let ultima = try await dependencias.lecturas.ultima()
        #expect(ultima?.uuid == nueva.uuid)
        #expect(ultima?.mgDl == 145)
    }

    /// Prueba 11 · RF-20 — el historial se lee del teléfono, sin red, y los extremos del
    /// rango entran.
    @Test("11 · RF-20: entre(desde:hasta:) respeta los extremos y devuelve en orden")
    func entreRespetaExtremosYOrden() async throws {
        let dependencias = try ContenedorDependencias.enMemoria()

        let hace2h = ahora.addingTimeInterval(-7200)
        let hace1h = ahora.addingTimeInterval(-3600)
        let hace3h = ahora.addingTimeInterval(-10_800)

        // Se insertan desordenadas a propósito.
        try await dependencias.lecturas.guardar(
            LecturaGlucosaDato(mgDl: 100, tsUtc: hace1h, origen: .sensor))
        try await dependencias.lecturas.guardar(
            LecturaGlucosaDato(mgDl: 200, tsUtc: hace3h, origen: .sensor))
        try await dependencias.lecturas.guardar(
            LecturaGlucosaDato(mgDl: 150, tsUtc: hace2h, origen: .sensor))

        let rango = try await dependencias.lecturas.entre(desde: hace2h, hasta: hace1h)
        #expect(rango.count == 2)                       // la de hace 3 h queda fuera
        #expect(rango.map(\.mgDl) == [150, 100])        // de la más vieja a la más nueva
        #expect(rango.first?.tsUtc == hace2h)           // el extremo inferior entra
        #expect(rango.last?.tsUtc == hace1h)            // el superior también
    }

    /// Prueba 14 · RF-36b — regla 5: UTC **y** zona horaria, siempre las dos. Sin la zona,
    /// «las 3 de la mañana» de un viaje deja de poder reconstruirse.
    @Test("14 · RF-36b: lo guardado conserva la zona horaria además del tsUtc")
    func seConservaLaZonaHoraria() async throws {
        let dependencias = try ContenedorDependencias.enMemoria()
        let dato = LecturaGlucosaDato(
            mgDl: 112, tsUtc: ahora, zonaHoraria: "America/Mexico_City", origen: .manual
        )
        try await dependencias.lecturas.guardar(dato)

        let leida = try await dependencias.lecturas.porUuid(dato.uuid)
        #expect(leida?.tsUtc == ahora)
        #expect(leida?.zonaHoraria == "America/Mexico_City")

        // Y lo mismo en comidas y dosis, que también viajan.
        let comida = ComidaDato(
            tsUtc: ahora, zonaHoraria: "Europe/Madrid", carbsG: 40, origen: .manual
        )
        try await dependencias.comidas.guardar(comida)
        #expect(try await dependencias.comidas.porUuid(comida.uuid)?.zonaHoraria == "Europe/Madrid")

        let dosis = DosisInsulinaDato(
            tsUtc: ahora, zonaHoraria: "America/Tijuana", unidades: 4, tipo: .bolo, motivo: .comida
        )
        try await dependencias.dosis.guardar(dosis)
        #expect(try await dependencias.dosis.porUuid(dosis.uuid)?.zonaHoraria == "America/Tijuana")
    }

    /// Prueba 15 · RF-36c — si la conversión pierde un campo, se pierde en silencio y el
    /// backend recibe un registro incompleto meses después.
    @Test("15 · RF-36c: el Dato convertido a @Model y de vuelta da lo mismo")
    func idaYVueltaNoPierdeNada() throws {
        let original = LecturaGlucosaDato(
            mgDl: 137.5,
            tsUtc: ahora,
            zonaHoraria: "America/Mexico_City",
            origen: .fotoGlucometro,
            contexto: .antesDeComer,
            confirmadaPorUsuario: true,
            atipica: true,
            escritaEnHealthKit: true,
            nota: "después de caminar",
            syncEstado: .enviado
        )

        let idaYVuelta = LecturaGlucosa(dato: original).dato
        #expect(idaYVuelta == original)
    }
}
