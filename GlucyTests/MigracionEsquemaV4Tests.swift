import Foundation
import SwiftData
import Testing
@testable import Glucy

/// La tercera migración del esquema: `motivo` opcional en `DosisInsulina` y
/// `registraInsulina` en `Perfil`.
///
/// Con una base **en disco** y en serie, por lo mismo que las dos anteriores: en memoria no
/// hay nada que migrar, y dos versiones del esquema abiertas a la vez en el mismo proceso se
/// pisan.
@Suite(.serialized)
struct MigracionEsquemaV4Tests {

    private let ahora = Date(timeIntervalSince1970: 1_758_240_000)

    private let uuidBolo = UUID()
    private let uuidBasal = UUID()
    private let uuidPerfil = UUID()
    private let uuidComida = UUID()

    /// Una base de verdad de la V3, con las tablas como eran antes de este paso, y encima
    /// la app de ahora.
    private func baseV3AbiertaConLaV4() throws -> (contenedor: ModelContainer, carpeta: URL) {
        let carpeta = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("glucy-migracion-v4-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: carpeta, withIntermediateDirectories: true)
        let archivo = carpeta.appendingPathComponent("Glucy.store")

        do {
            let esquema = Schema(versionedSchema: EsquemaGlucyV3.self)
            let viejo = ModelContext(try ModelContainer(
                for: esquema, configurations: ModelConfiguration(schema: esquema, url: archivo)
            ))
            viejo.insert(EsquemaGlucyV1.DosisInsulina(
                uuid: uuidBolo, tsUtc: ahora, unidades: 4, tipo: .bolo, motivo: .correccion
            ))
            viejo.insert(EsquemaGlucyV1.DosisInsulina(
                uuid: uuidBasal, tsUtc: ahora.addingTimeInterval(-3600), unidades: 12.5,
                tipo: .basal, motivo: .programada
            ))
            viejo.insert(EsquemaGlucyV1.Perfil(
                uuid: uuidPerfil, fechaNacimiento: Date(timeIntervalSince1970: 800_000_000),
                tipoUsuario: .tipo1
            ))
            viejo.insert(Comida(
                uuid: uuidComida, tsUtc: ahora, carbsG: 45, origen: .barcode,
                porcionG: 30, porciones: 2
            ))
            try viejo.save()
        }

        return (try ContenedorGlucy.crear(url: archivo), carpeta)
    }

    @Test("20: la base V3 se abre con la V4 sin perder filas")
    func laBaseV3SeAbreConLaV4() async throws {
        let (contenedor, carpeta) = try baseV3AbiertaConLaV4()
        defer { try? FileManager.default.removeItem(at: carpeta) }

        #expect(try await DosisSwiftData(modelContainer: contenedor).contar() == 2)
        #expect(try await PerfilSwiftData(modelContainer: contenedor).existe())

        // Lo del paso 6 no se tocó.
        let comida = try #require(
            try await ComidasSwiftData(modelContainer: contenedor).porUuid(uuidComida)
        )
        #expect(comida.carbsG == 45)
        #expect(comida.porciones == 2)

        // El plan llega hasta la V4 con una etapa más, y las versiones anteriores describen
        // la base como era: si dos coinciden, el plan no las distingue y la app se cae al
        // abrir una base vieja.
        #expect(EsquemaGlucyV4.versionIdentifier == Schema.Version(4, 0, 0))
        #expect(EsquemaGlucyV4.models.count == 10)
        #expect(PlanMigracionGlucy.schemas.count == 6)
        #expect(PlanMigracionGlucy.stages.count == 5)
        #expect(EsquemaGlucyV3.models.contains { $0 == EsquemaGlucyV1.DosisInsulina.self })
        #expect(EsquemaGlucyV3.models.contains { $0 == EsquemaGlucyV1.Perfil.self })
        #expect(EsquemaGlucyV4.models.contains { $0 == DosisInsulina.self })
        #expect(EsquemaGlucyV4.models.contains { $0 == EsquemaGlucyV4.Perfil.self })
    }

    @Test("21: una dosis migrada de la V3 conserva su motivo")
    func laDosisConservaSuMotivo() async throws {
        let (contenedor, carpeta) = try baseV3AbiertaConLaV4()
        defer { try? FileManager.default.removeItem(at: carpeta) }
        let dosis = DosisSwiftData(modelContainer: contenedor)

        let bolo = try #require(try await dosis.porUuid(uuidBolo))
        #expect(bolo.motivo == .correccion)
        #expect(bolo.unidades == 4)
        #expect(bolo.tipo == .bolo)
        #expect(bolo.duracionAccionH == 5)

        let basal = try #require(try await dosis.porUuid(uuidBasal))
        #expect(basal.motivo == .programada)
        #expect(basal.unidades == 12.5)

        // Y sobre la base migrada ya se puede guardar una sin motivo.
        let sinMotivo = DosisInsulinaDato(tsUtc: ahora, unidades: 2, tipo: .bolo)
        try await dosis.guardar(sinMotivo)
        let leida = try #require(try await dosis.porUuid(sinMotivo.uuid))
        #expect(leida.motivo == nil)
    }

    @Test("22: un perfil migrado de la V3 queda con registraInsulina en true")
    func elPerfilMigradoRegistraInsulina() async throws {
        let (contenedor, carpeta) = try baseV3AbiertaConLaV4()
        defer { try? FileManager.default.removeItem(at: carpeta) }

        let perfil = try #require(try await PerfilSwiftData(modelContainer: contenedor).actual())
        #expect(perfil.uuid == uuidPerfil)
        #expect(perfil.registraInsulina)
        #expect(perfil.tipoUsuario == .tipo1)
        #expect(perfil.duracionAccionInsulinaH == 5)
    }
}
