import Foundation
import SwiftData
import Testing
@testable import Glucy

/// La primera migración del esquema.
///
/// Se hace con una base **en disco** porque en memoria no hay nada que migrar: el punto de
/// la prueba es que un archivo que ya existía se abra con el esquema nuevo sin perder filas.
/// Si el modelo cambiara sin plan de migración, SwiftData borraría la base al arrancar, y en
/// las pruebas de campo de la fase 7 eso son semanas de datos de una persona real.
struct MigracionEsquemaTests {

    private let ahora = Date(timeIntervalSince1970: 1_758_240_000)

    /// Prueba 14 — se escribe, se cierra, se vuelve a abrir, y las filas siguen ahí con los
    /// campos nuevos en su valor por omisión.
    @Test("14: la base se abre con el esquema nuevo sin perder filas")
    func laBaseSeAbreSinPerderFilas() async throws {
        let carpeta = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("glucy-migracion-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: carpeta, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: carpeta) }

        let archivo = carpeta.appendingPathComponent("Glucy.store")
        let uuidDeLaLectura = UUID()

        // Primera apertura: se guardan tres lecturas y se cierra todo.
        do {
            let contenedor = try ContenedorGlucy.crear(url: archivo)
            let lecturas = LecturasSwiftData(modelContainer: contenedor)
            try await lecturas.guardar(LecturaGlucosaDato(
                uuid: uuidDeLaLectura, mgDl: 112, tsUtc: ahora, origen: .manual
            ))
            try await lecturas.guardar(LecturaGlucosaDato(
                mgDl: 98, tsUtc: ahora.addingTimeInterval(-3600), origen: .sensor
            ))
            try await lecturas.guardar(LecturaGlucosaDato(
                mgDl: 143, tsUtc: ahora.addingTimeInterval(-7200), origen: .manual
            ))
            #expect(try await lecturas.contar() == 3)
        }

        // Segunda apertura, contenedor nuevo sobre el mismo archivo.
        let contenedor = try ContenedorGlucy.crear(url: archivo)
        let lecturas = LecturasSwiftData(modelContainer: contenedor)

        #expect(try await lecturas.contar() == 3, "se perdieron filas al reabrir la base")

        let recuperada = try #require(try await lecturas.porUuid(uuidDeLaLectura))
        #expect(recuperada.mgDl == 112)
        #expect(recuperada.origen == .manual)
        // Los tres campos de RF-05b existen y traen su valor por omisión en lo que se
        // guardó antes de que existieran.
        #expect(recuperada.valorLeidoOcr == nil)
        #expect(recuperada.confianzaOcr == nil)
        #expect(recuperada.fueCorregido == false)

        // Y la cola, que se llenó en el primer arranque, también sobrevivió.
        let cola = ColaSwiftData(modelContainer: contenedor)
        #expect(try await cola.contarPendientes() == 3)
    }

    /// El plan declara las dos versiones y el camino entre ellas. Sin la etapa, SwiftData no
    /// sabe llegar de la V1 a la V2.
    @Test("14: el plan de migración declara la V1, la V2 y la etapa entre las dos")
    func elPlanDeclaraElCamino() {
        #expect(PlanMigracionGlucy.schemas.count == 2)
        #expect(EsquemaGlucyV1.versionIdentifier == Schema.Version(1, 0, 0))
        #expect(EsquemaGlucyV2.versionIdentifier == Schema.Version(2, 0, 0))
        #expect(PlanMigracionGlucy.stages.count == 1)
        #expect(EsquemaGlucyV2.models.count == 10)
    }
}
