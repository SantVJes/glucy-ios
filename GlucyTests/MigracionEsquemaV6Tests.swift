import Foundation
import SwiftData
import Testing
@testable import Glucy

/// La quinta migración del esquema: `asistenteActivo` en `Perfil`, el interruptor de la
/// explicación.
///
/// Con una base **en disco** y en serie, por lo mismo que las cuatro anteriores: en memoria no
/// hay nada que migrar, y dos versiones del esquema abiertas a la vez en el mismo proceso se
/// pisan.
///
/// **La prueba que importa es `quienYaTeniaLaAppSigueViendoLaFrase`.** Un campo nuevo que
/// naciera en `false` apagaría el asistente a todo el que actualice, y nadie lo notaría: la
/// pantalla seguiría funcionando, solo que sin la frase, y la persona no tocó nada.
@Suite(.serialized)
struct MigracionEsquemaV6Tests {

    private let ahora = Date(timeIntervalSince1970: 1_758_240_000)
    private let uuidPerfil = UUID()
    private let uuidLectura = UUID()
    private let nacimiento = Date(timeIntervalSince1970: 800_000_000)

    private func carpetaNueva() throws -> URL {
        let carpeta = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("glucy-migracion-v6-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: carpeta, withIntermediateDirectories: true)
        return carpeta
    }

    /// Una base de verdad de la V5, con un perfil ya dado de alta —consentido, con su unidad y
    /// sus interruptores— y encima la app de ahora.
    private func baseV5AbiertaConLaV6() throws -> (contenedor: ModelContainer, carpeta: URL) {
        let carpeta = try carpetaNueva()
        let archivo = carpeta.appendingPathComponent("Glucy.store")

        do {
            let esquema = Schema(versionedSchema: EsquemaGlucyV5.self)
            let viejo = ModelContext(try ModelContainer(
                for: esquema, configurations: ModelConfiguration(schema: esquema, url: archivo)
            ))
            let perfil = EsquemaGlucyV5.Perfil(
                uuid: uuidPerfil, nombre: "Ana", pesoKg: 62, fechaNacimiento: nacimiento,
                tipoUsuario: .tipo2Insulinodependiente, umbralHipo: 75,
                duracionAccionInsulinaH: 6, usaSensor: true, registraInsulina: false
            )
            // Los cinco campos de F-1 se ponen después del init: el congelado trae el init
            // corto, como los de las versiones anteriores.
            perfil.consentimientoTsUtc = ahora
            perfil.unidadPreferida = .mmolL
            perfil.tipoInsulinaRapida = "Humalog"
            perfil.sincronizacionActiva = true
            perfil.bloqueoBiometrico = true
            viejo.insert(perfil)
            viejo.insert(LecturaGlucosa(uuid: uuidLectura, mgDl: 112, tsUtc: ahora, origen: .manual))
            try viejo.save()
        }

        return (try ContenedorGlucy.crear(url: archivo), carpeta)
    }

    @Test("1: quien ya tenía la app sigue viendo la frase después de actualizar")
    func quienYaTeniaLaAppSigueViendoLaFrase() async throws {
        let (contenedor, carpeta) = try baseV5AbiertaConLaV6()
        defer { try? FileManager.default.removeItem(at: carpeta) }

        let perfil = try #require(try await PerfilSwiftData(modelContainer: contenedor).actual())
        #expect(perfil.asistenteActivo)
    }

    @Test("2: la V6 abre una base V5 y no pierde nada de lo que había")
    func noSePierdeNada() async throws {
        let (contenedor, carpeta) = try baseV5AbiertaConLaV6()
        defer { try? FileManager.default.removeItem(at: carpeta) }

        let perfil = try #require(try await PerfilSwiftData(modelContainer: contenedor).actual())
        #expect(perfil.uuid == uuidPerfil)
        #expect(perfil.nombre == "Ana")
        #expect(perfil.pesoKg == 62)
        #expect(perfil.fechaNacimiento == nacimiento)
        #expect(perfil.tipoUsuario == .tipo2Insulinodependiente)
        #expect(perfil.umbralHipo == 75)
        #expect(perfil.duracionAccionInsulinaH == 6)
        #expect(perfil.usaSensor)
        #expect(!perfil.registraInsulina)
        #expect(perfil.consentimientoTsUtc == ahora)
        #expect(perfil.unidadPreferida == .mmolL)
        #expect(perfil.tipoInsulinaRapida == "Humalog")
        #expect(perfil.sincronizacionActiva)
        #expect(perfil.bloqueoBiometrico)

        // Y sigue consentido: actualizar no vuelve a cerrar la puerta.
        let repositorio = PerfilSwiftData(modelContainer: contenedor)
        #expect(await ConsultarEntrada(perfil: repositorio).ejecutar().consintio)

        // Lo demás tampoco se tocó.
        let lectura = try #require(
            try await LecturasSwiftData(modelContainer: contenedor).porUuid(uuidLectura)
        )
        #expect(lectura.mgDl == 112)
    }

    @Test("3: apagar el interruptor sobre una base migrada se guarda y se vuelve a leer")
    func apagarloSeGuarda() async throws {
        let (contenedor, carpeta) = try baseV5AbiertaConLaV6()
        defer { try? FileManager.default.removeItem(at: carpeta) }
        let repositorio = PerfilSwiftData(modelContainer: contenedor)
        let guardar = GuardarAjustes(perfil: repositorio)

        var ajustes = try #require(try await guardar.actuales())
        #expect(ajustes.asistenteActivo)
        ajustes.asistenteActivo = false
        try await guardar.ejecutar(ajustes, ahora: ahora)

        #expect(try await repositorio.actual()?.asistenteActivo == false)
        // Y nada más se movió al guardar.
        #expect(try await repositorio.actual()?.tipoInsulinaRapida == "Humalog")
    }

    @Test("4: se agrega una etapa y las cuatro anteriores siguen como estaban")
    func lasEtapasAnterioresNoSeTocaron() async throws {
        #expect(EsquemaGlucyV6.versionIdentifier == Schema.Version(6, 0, 0))
        #expect(EsquemaGlucyV6.models.count == 10)
        #expect(PlanMigracionGlucy.schemas.count == 6)
        #expect(PlanMigracionGlucy.stages.count == 5)

        // Cada versión sigue describiendo la base como era: si dos coinciden, el plan no las
        // distingue y la app se cae al abrir una base vieja.
        #expect(EsquemaGlucyV5.versionIdentifier == Schema.Version(5, 0, 0))
        #expect(EsquemaGlucyV5.models.contains { $0 == EsquemaGlucyV5.Perfil.self })
        #expect(EsquemaGlucyV4.models.contains { $0 == EsquemaGlucyV4.Perfil.self })
        #expect(EsquemaGlucyV1.models.contains { $0 == EsquemaGlucyV1.Perfil.self })

        // Y el de hoy está solo en la V6.
        #expect(EsquemaGlucyV6.models.contains { $0 == Perfil.self })
        #expect(!EsquemaGlucyV5.models.contains { $0 == Perfil.self })
    }

    @Test("5: la cadena entera sigue funcionando, desde la V1 hasta la V6")
    func laCadenaEnteraFunciona() async throws {
        let carpeta = try carpetaNueva()
        defer { try? FileManager.default.removeItem(at: carpeta) }
        let archivo = carpeta.appendingPathComponent("Glucy.store")

        do {
            let esquema = Schema(versionedSchema: EsquemaGlucyV1.self)
            let viejo = ModelContext(try ModelContainer(
                for: esquema, configurations: ModelConfiguration(schema: esquema, url: archivo)
            ))
            viejo.insert(EsquemaGlucyV1.Perfil(
                uuid: uuidPerfil, fechaNacimiento: nacimiento, tipoUsuario: .tipo1
            ))
            try viejo.save()
        }

        let contenedor = try ContenedorGlucy.crear(url: archivo)
        let perfil = try #require(try await PerfilSwiftData(modelContainer: contenedor).actual())
        #expect(perfil.uuid == uuidPerfil)
        #expect(perfil.registraInsulina)            // la omisión de la V4
        #expect(perfil.consentimientoTsUtc == nil)  // la de la V5
        #expect(perfil.asistenteActivo)             // la de la V6
    }
}
