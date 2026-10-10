import Foundation
import SwiftData
import Testing
@testable import Glucy

/// La segunda migración del esquema: `porciones` en `Comida`.
///
/// Con una base **en disco**, por lo mismo que la primera: en memoria no hay nada que migrar.
///
/// En serie y no en paralelo: estas pruebas abren la V1, la V2 y la V3 dentro del mismo
/// proceso, y las tres tienen una tabla `Comida` con una clase distinta detrás. SwiftData
/// lleva un solo registro de qué clase es cada tabla, así que dos versiones abiertas a la vez
/// se pisan: en iOS 26 la prueba se cae o relee los campos nuevos en su valor por omisión.
/// La app nunca llega a eso, porque abre un solo contenedor.
@Suite(.serialized)
struct MigracionEsquemaV3Tests {

    private let ahora = Date(timeIntervalSince1970: 1_758_240_000)

    private func carpetaTemporal() throws -> URL {
        let carpeta = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("glucy-migracion-v3-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: carpeta, withIntermediateDirectories: true)
        return carpeta
    }

    /// Una base de verdad de la versión que se pida, con sus diez tablas como eran.
    private func contexto(
        de version: any VersionedSchema.Type, en archivo: URL
    ) throws -> ModelContext {
        let esquema = Schema(versionedSchema: version)
        let contenedor = try ModelContainer(
            for: esquema, configurations: ModelConfiguration(schema: esquema, url: archivo)
        )
        return ModelContext(contenedor)
    }

    /// Prueba 24 — una base **de la V2**, escrita sin la columna `porciones`, se abre con el
    /// esquema de ahora y sus comidas siguen ahí con `porciones: 1`.
    ///
    /// Es la que protege el teléfono de quien ya traía datos del paso 5: si el plan no
    /// supiera llegar de la V2 a la V3, la app se caería al arrancar.
    @Test("24: la base V2 se abre con la V3 sin perder filas, y las viejas quedan con porciones 1")
    func laBaseV2SeAbreConLaV3() async throws {
        let carpeta = try carpetaTemporal()
        defer { try? FileManager.default.removeItem(at: carpeta) }
        let archivo = carpeta.appendingPathComponent("Glucy.store")

        let uuidUna = UUID()
        let uuidOtra = UUID()
        let uuidLectura = UUID()

        do {
            let viejo = try contexto(de: EsquemaGlucyV2.self, en: archivo)
            viejo.insert(EsquemaGlucyV1.Comida(
                uuid: uuidUna, tsUtc: ahora, carbsG: 60, origen: .manual
            ))
            viejo.insert(EsquemaGlucyV1.Comida(
                uuid: uuidOtra, tsUtc: ahora.addingTimeInterval(-3600), carbsG: 22.5,
                origen: .manual, porcionG: 30
            ))
            viejo.insert(EsquemaGlucyV1.ProductoCache(
                codigoBarras: "3017620422003", nombre: "Galletas María", carbsPor100g: 75
            ))
            viejo.insert(LecturaGlucosa(
                uuid: uuidLectura, mgDl: 112, tsUtc: ahora, origen: .fotoGlucometro,
                valorLeidoOcr: 121, fueCorregido: true, confianzaOcr: 0.8
            ))
            try viejo.save()
        }

        // La app de ahora, sobre ese mismo archivo.
        let contenedor = try ContenedorGlucy.crear(url: archivo)
        let comidas = ComidasSwiftData(modelContainer: contenedor)

        #expect(try await comidas.contar() == 2, "se perdieron comidas al migrar")

        let una = try #require(try await comidas.porUuid(uuidUna))
        #expect(una.carbsG == 60)
        #expect(una.porciones == 1)
        #expect(una.tiempoAbsorcionMin == 180)

        let otra = try #require(try await comidas.porUuid(uuidOtra))
        // Con `1` la fila vieja sigue dando el mismo `carbsG` que tenía.
        #expect(otra.carbsG == 22.5)
        #expect(otra.porcionG == 30)
        #expect(otra.porciones == 1)

        // Lo que ya estaba en la caché sigue siendo un producto que sí se encontró.
        let enCache = try await ProductosSwiftData(modelContainer: contenedor)
            .porCodigo("3017620422003")
        #expect(enCache?.encontrado == true)
        #expect(enCache?.producto?.carbsPor100g == 75)

        // Y lo del paso 5 no se tocó.
        let lectura = try #require(
            try await LecturasSwiftData(modelContainer: contenedor).porUuid(uuidLectura)
        )
        #expect(lectura.mgDl == 112)
        #expect(lectura.valorLeidoOcr == 121)
        #expect(lectura.fueCorregido)
    }

    /// Y desde más atrás: una base de la V1 recorre las dos etapas seguidas.
    @Test("24: una base V1 recorre las dos etapas y llega a la V3 con todo")
    func laBaseV1LlegaALaV3() async throws {
        let carpeta = try carpetaTemporal()
        defer { try? FileManager.default.removeItem(at: carpeta) }
        let archivo = carpeta.appendingPathComponent("Glucy.store")

        let uuidLectura = UUID()
        let uuidComida = UUID()

        do {
            let viejo = try contexto(de: EsquemaGlucyV1.self, en: archivo)
            viejo.insert(EsquemaGlucyV1.LecturaGlucosa(
                uuid: uuidLectura, mgDl: 98, tsUtc: ahora, origen: .manual
            ))
            viejo.insert(EsquemaGlucyV1.Comida(
                uuid: uuidComida, tsUtc: ahora, carbsG: 40, origen: .manual
            ))
            try viejo.save()
        }

        let contenedor = try ContenedorGlucy.crear(url: archivo)

        let lectura = try #require(
            try await LecturasSwiftData(modelContainer: contenedor).porUuid(uuidLectura)
        )
        #expect(lectura.mgDl == 98)
        #expect(lectura.valorLeidoOcr == nil)
        #expect(lectura.fueCorregido == false)

        let comida = try #require(
            try await ComidasSwiftData(modelContainer: contenedor).porUuid(uuidComida)
        )
        #expect(comida.carbsG == 40)
        #expect(comida.porciones == 1)
    }

    /// Y lo que se escribe con la V3 se relee con sus porciones.
    @Test("24: las porciones se guardan, se cierran y se releen")
    func lasPorcionesSobrevivenAlCierre() async throws {
        let carpeta = try carpetaTemporal()
        defer { try? FileManager.default.removeItem(at: carpeta) }
        let archivo = carpeta.appendingPathComponent("Glucy.store")
        let uuid = UUID()

        do {
            let comidas = ComidasSwiftData(modelContainer: try ContenedorGlucy.crear(url: archivo))
            try await comidas.guardar(ComidaDato(
                uuid: uuid, tsUtc: ahora, carbsG: 45, origen: .barcode, porcionG: 30, porciones: 2
            ))
        }

        let comidas = ComidasSwiftData(modelContainer: try ContenedorGlucy.crear(url: archivo))
        #expect(try await comidas.porUuid(uuid)?.porciones == 2)
    }

    @Test("24: el plan declara la V3 y una etapa ligera más, sin tocar la del paso 5")
    func elPlanDeclaraLaV3() {
        #expect(EsquemaGlucyV3.versionIdentifier == Schema.Version(3, 0, 0))
        #expect(EsquemaGlucyV3.models.count == 10)
        #expect(PlanMigracionGlucy.schemas.count == 3)
        #expect(PlanMigracionGlucy.stages.count == 2)
        // Cada versión describe la base como era: si dos coinciden, el plan no las
        // distingue y la app se cae al abrir una base vieja.
        #expect(EsquemaGlucyV2.models.contains { $0 == EsquemaGlucyV1.Comida.self })
        #expect(EsquemaGlucyV3.models.contains { $0 == Comida.self })
        #expect(EsquemaGlucyV1.models.contains { $0 == EsquemaGlucyV1.LecturaGlucosa.self })
    }
}
