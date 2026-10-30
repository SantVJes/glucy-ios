import Foundation
import SwiftData
import Testing
@testable import Glucy

/// La cuarta migración del esquema: los cinco campos que el formulario F-1 pide en `Perfil`.
///
/// Con una base **en disco** y en serie, por lo mismo que las tres anteriores: en memoria no
/// hay nada que migrar, y dos versiones del esquema abiertas a la vez en el mismo proceso se
/// pisan.
@Suite(.serialized)
struct MigracionEsquemaV5Tests {

    private let ahora = Date(timeIntervalSince1970: 1_758_240_000)
    private let uuidPerfil = UUID()
    private let uuidLectura = UUID()
    private let nacimiento = Date(timeIntervalSince1970: 800_000_000)

    private func carpetaNueva() throws -> URL {
        let carpeta = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("glucy-migracion-v5-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: carpeta, withIntermediateDirectories: true)
        return carpeta
    }

    /// Una base de verdad de la V4, con el perfil como era antes de este paso, y encima la
    /// app de ahora.
    private func baseV4AbiertaConLaV5() throws -> (contenedor: ModelContainer, carpeta: URL) {
        let carpeta = try carpetaNueva()
        let archivo = carpeta.appendingPathComponent("Glucy.store")

        do {
            let esquema = Schema(versionedSchema: EsquemaGlucyV4.self)
            let viejo = ModelContext(try ModelContainer(
                for: esquema, configurations: ModelConfiguration(schema: esquema, url: archivo)
            ))
            viejo.insert(EsquemaGlucyV4.Perfil(
                uuid: uuidPerfil, nombre: "Ana", pesoKg: 62, fechaNacimiento: nacimiento,
                tipoUsuario: .tipo2Insulinodependiente, umbralHipo: 75,
                duracionAccionInsulinaH: 6, usaSensor: true, registraInsulina: false
            ))
            viejo.insert(LecturaGlucosa(uuid: uuidLectura, mgDl: 112, tsUtc: ahora, origen: .manual))
            try viejo.save()
        }

        return (try ContenedorGlucy.crear(url: archivo), carpeta)
    }

    @Test("1: la V5 abre una base V4 con un perfil dentro y conserva sus valores")
    func elPerfilSigueAhi() async throws {
        let (contenedor, carpeta) = try baseV4AbiertaConLaV5()
        defer { try? FileManager.default.removeItem(at: carpeta) }

        let perfil = try #require(try await PerfilSwiftData(modelContainer: contenedor).actual())
        #expect(perfil.uuid == uuidPerfil)
        #expect(perfil.nombre == "Ana")
        #expect(perfil.pesoKg == 62)
        #expect(perfil.fechaNacimiento == nacimiento)
        #expect(perfil.tipoUsuario == .tipo2Insulinodependiente)
        #expect(perfil.umbralHipo == 75)
        #expect(perfil.umbralHiper == 180)
        #expect(perfil.duracionAccionInsulinaH == 6)
        #expect(perfil.usaSensor)
        #expect(!perfil.registraInsulina)

        // Y lo demás tampoco se tocó.
        let lectura = try #require(
            try await LecturasSwiftData(modelContainer: contenedor).porUuid(uuidLectura)
        )
        #expect(lectura.mgDl == 112)
    }

    @Test("2: un perfil migrado no queda consentido, y los otros cuatro campos traen su omisión")
    func elPerfilViejoNoConsintio() async throws {
        let (contenedor, carpeta) = try baseV4AbiertaConLaV5()
        defer { try? FileManager.default.removeItem(at: carpeta) }
        let repositorio = PerfilSwiftData(modelContainer: contenedor)

        let perfil = try #require(try await repositorio.actual())
        #expect(perfil.consentimientoTsUtc == nil)
        #expect(perfil.unidadPreferida == .mgDl)
        #expect(perfil.tipoInsulinaRapida == nil)
        #expect(!perfil.sincronizacionActiva)
        #expect(!perfil.bloqueoBiometrico)

        // Existe un perfil, pero la puerta sigue cerrada: hay que pasar por el alta.
        #expect(try await repositorio.existe())
        #expect(await ConsultarEntrada(perfil: repositorio).ejecutar().consintio == false)

        // Y el alta completa esa misma fila en lugar de crear otra.
        let completado = try await CompletarAlta(perfil: repositorio, salud: HealthKitFalso()).ejecutar(
            nombre: "Ana", apellidos: "", tipoUsuario: .tipo2Insulinodependiente,
            anioNacimiento: 1995, pesoKg: 62, unidadPreferida: .mmolL, usaSensor: true,
            aceptaConsentimiento: true, ahora: ahora
        )
        #expect(completado.uuid == uuidPerfil)
        let leido = try #require(try await repositorio.actual())
        #expect(leido.consentimientoTsUtc == ahora)
        #expect(leido.unidadPreferida == .mmolL)
        #expect(await ConsultarEntrada(perfil: repositorio).ejecutar().consintio)
    }

    @Test("3: se agrega una etapa y las de la V2, la V3 y la V4 siguen como estaban")
    func lasEtapasAnterioresNoSeTocaron() async throws {
        #expect(EsquemaGlucyV5.versionIdentifier == Schema.Version(5, 0, 0))
        #expect(EsquemaGlucyV5.models.count == 10)
        #expect(PlanMigracionGlucy.schemas.count == 6)
        #expect(PlanMigracionGlucy.stages.count == 5)

        // Cada versión sigue describiendo la base como era: si dos coinciden, el plan no las
        // distingue y la app se cae al abrir una base vieja.
        #expect(EsquemaGlucyV1.versionIdentifier == Schema.Version(1, 0, 0))
        #expect(EsquemaGlucyV2.versionIdentifier == Schema.Version(2, 0, 0))
        #expect(EsquemaGlucyV3.versionIdentifier == Schema.Version(3, 0, 0))
        #expect(EsquemaGlucyV4.versionIdentifier == Schema.Version(4, 0, 0))
        #expect(EsquemaGlucyV2.models.contains { $0 == EsquemaGlucyV1.Perfil.self })
        #expect(EsquemaGlucyV3.models.contains { $0 == EsquemaGlucyV1.Perfil.self })
        #expect(EsquemaGlucyV3.models.contains { $0 == EsquemaGlucyV1.DosisInsulina.self })
        #expect(EsquemaGlucyV4.models.contains { $0 == EsquemaGlucyV4.Perfil.self })
        #expect(EsquemaGlucyV4.models.contains { $0 == DosisInsulina.self })
        // La V5 pasó a describir su propio `Perfil` congelado cuando nació la V6: ya no es
        // el de hoy, que es lo que la distingue de la siguiente.
        #expect(EsquemaGlucyV5.models.contains { $0 == EsquemaGlucyV5.Perfil.self })
        #expect(!EsquemaGlucyV5.models.contains { $0 == EsquemaGlucyV4.Perfil.self })
        #expect(!EsquemaGlucyV5.models.contains { $0 == Perfil.self })

        // Y la cadena entera sigue funcionando: una base de la V3 llega hasta la V5 con sus
        // filas, pasando por las dos etapas.
        let carpeta = try carpetaNueva()
        defer { try? FileManager.default.removeItem(at: carpeta) }
        let archivo = carpeta.appendingPathComponent("Glucy.store")
        let uuidDosis = UUID()
        do {
            let esquema = Schema(versionedSchema: EsquemaGlucyV3.self)
            let viejo = ModelContext(try ModelContainer(
                for: esquema, configurations: ModelConfiguration(schema: esquema, url: archivo)
            ))
            viejo.insert(EsquemaGlucyV1.Perfil(
                uuid: uuidPerfil, fechaNacimiento: nacimiento, tipoUsuario: .tipo1
            ))
            viejo.insert(EsquemaGlucyV1.DosisInsulina(
                uuid: uuidDosis, tsUtc: ahora, unidades: 4, tipo: .bolo, motivo: .correccion
            ))
            try viejo.save()
        }
        let contenedor = try ContenedorGlucy.crear(url: archivo)

        let perfil = try #require(try await PerfilSwiftData(modelContainer: contenedor).actual())
        #expect(perfil.uuid == uuidPerfil)
        #expect(perfil.registraInsulina)               // la omisión de la etapa de la V4
        #expect(perfil.consentimientoTsUtc == nil)     // la de la V5
        let dosis = try #require(try await DosisSwiftData(modelContainer: contenedor).porUuid(uuidDosis))
        #expect(dosis.motivo == .correccion)
    }
}
