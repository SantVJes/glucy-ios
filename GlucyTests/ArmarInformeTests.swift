import Foundation
import SwiftUI
import Testing
@testable import Glucy

/// El informe para el médico (RF-16). Lo que se fija aquí es lo que puede salir mal en papel:
/// que lleve la identidad sin que la persona lo pidiera, que presente un GMI que no significa
/// nada, o que dé cifras distintas de las de la pantalla.
@MainActor
struct ArmarInformeTests {

    /// Mediodía UTC, para que «hace N días» caiga siempre en un día distinto.
    private let ahora = Date(timeIntervalSince1970: 1_758_240_000 + 12 * 3600)
    private let notaSecreta = "Me sentí mareada después de discutir con Raúl"

    private func perfil() -> PerfilDato {
        PerfilDato(
            nombre: "Ana", apellidos: "Ruiz Soto", pesoKg: 62.5,
            fechaNacimiento: ReglasDePerfil.fechaDeAnio(1990), tipoUsuario: .tipo1,
            umbralHipo: 75, consentimientoTsUtc: ahora
        )
    }

    private func lectura(
        _ mgDl: Double, haceDias dias: Double, origen: Origen = .manual, nota: String? = nil
    ) -> LecturaGlucosaDato {
        LecturaGlucosaDato(
            mgDl: mgDl, tsUtc: ahora.addingTimeInterval(-dias * 86_400 - 60), zonaHoraria: "UTC",
            origen: origen, nota: nota
        )
    }

    /// Un día de lecturas por cada uno de los últimos `dias`, de varios orígenes.
    private func lecturas(dias: Int) -> [LecturaGlucosaDato] {
        (0..<dias).flatMap { dia -> [LecturaGlucosaDato] in
            [
                lectura(100 + Double(dia), haceDias: Double(dia), origen: .sensor),
                lectura(150, haceDias: Double(dia) + 0.1, origen: .manual, nota: notaSecreta),
                lectura(190, haceDias: Double(dia) + 0.2, origen: dia.isMultiple(of: 2) ? .fotoGlucometro : .healthkit),
            ]
        }
    }

    private func montar(
        _ lecturas: [LecturaGlucosaDato]
    ) async throws -> (ArmarInforme, ConsultarHistorial, PerfilDato) {
        let repositorio = RepositorioLecturasFalso()
        for l in lecturas { try await repositorio.guardar(l) }
        let comidas = RepositorioComidasFalso()
        try await comidas.guardar(ComidaDato(tsUtc: ahora.addingTimeInterval(-3600), carbsG: 45, origen: .manual))
        try await comidas.guardar(ComidaDato(tsUtc: ahora.addingTimeInterval(-40 * 86_400), carbsG: 30, origen: .manual))
        let dosis = RepositorioDosisFalso()
        try await dosis.guardar(DosisInsulinaDato(tsUtc: ahora.addingTimeInterval(-7200), unidades: 4, tipo: .bolo))
        try await dosis.guardar(DosisInsulinaDato(tsUtc: ahora.addingTimeInterval(-86_400), unidades: 12, tipo: .basal))

        let persona = perfil()
        let perfiles = RepositorioPerfilFalso(persona)
        let historial = ConsultarHistorial(lecturas: repositorio, perfil: perfiles)
        let armar = ArmarInforme(
            historial: historial, lecturas: repositorio, comidas: comidas, dosis: dosis, perfil: perfiles
        )
        return (armar, historial, persona)
    }

    @Test("1 · RF-16: sin pedirlo, el informe no trae identidad")
    func sinIdentidadPorOmision() async throws {
        let (armar, _, _) = try await montar(lecturas(dias: 5))
        let informe = try await armar.ejecutar(dias: 7, conIdentidad: false, ahora: ahora)
        #expect(informe.identidad == nil)
    }

    @Test("2 · RF-16: con el interruptor encendido trae nombre, apellidos, año y peso")
    func conIdentidadCuandoSePide() async throws {
        let (armar, _, _) = try await montar(lecturas(dias: 5))
        let informe = try await armar.ejecutar(dias: 7, conIdentidad: true, ahora: ahora)
        #expect(informe.identidad == IdentidadDelInforme(
            nombre: "Ana", apellidos: "Ruiz Soto", anioNacimiento: 1990, pesoKg: 62.5
        ))
    }

    @Test("3 · regla 3: el informe nunca lleva el UUID del perfil ni las notas", arguments: [false, true])
    func niElUuidNiLasNotas(conIdentidad: Bool) async throws {
        let (armar, _, persona) = try await montar(lecturas(dias: 5))
        let informe = try await armar.ejecutar(dias: 7, conIdentidad: conIdentidad, ahora: ahora)

        // Todo lo que el informe lleva dentro, volcado a texto.
        var volcado = ""
        dump(informe, to: &volcado)
        #expect(!volcado.contains(persona.uuid.uuidString))
        #expect(!volcado.localizedCaseInsensitiveContains("mareada"))
        #expect(!volcado.contains("Raúl"))
        // Y con el interruptor apagado, tampoco el nombre ni el peso.
        if !conIdentidad {
            #expect(!volcado.contains("Ana"))
            #expect(!volcado.contains("Ruiz"))
            #expect(!volcado.contains("62.5"))
        }
    }

    @Test("4 · RF-16: las tres cifras del informe son las mismas que da ConsultarHistorial", arguments: [7, 14, 30])
    func lasCifrasSonLasDeLaPantalla(dias: Int) async throws {
        let (armar, historial, _) = try await montar(lecturas(dias: 20))
        let informe = try await armar.ejecutar(dias: dias, conIdentidad: false, ahora: ahora)
        let pantalla = try await historial.ejecutar(periodoDias: dias, ahora: ahora)

        #expect(informe.indicadores.indicadores == pantalla.indicadores)
        #expect(informe.indicadores.diasConLecturas == pantalla.diasConLecturas)
        #expect(informe.indicadores.gmiEsFiable == pantalla.gmiEsFiable)
        #expect(informe.diaTipico == pantalla.diaTipico)
        #expect(informe.horasSinDatos == pantalla.horasSinDatos)
        // El perfil tiene el umbral de hipo movido, y el informe también lo respeta.
        #expect(try #require(informe.indicadores.indicadores).tbr == pantalla.indicadores?.tbr)
    }

    @Test("5 · RF-16: con menos de 14 días el informe no presenta un GMI")
    func elGmiDeTresDiasNoEsUnGmi() async throws {
        let (armar, _, _) = try await montar(lecturas(dias: 5))
        let informe = try await armar.ejecutar(dias: 30, conIdentidad: false, ahora: ahora)
        #expect(informe.indicadores.indicadores != nil)
        #expect(!informe.indicadores.gmiEsFiable)
        #expect(informe.indicadores.gmi == nil)

        // Con catorce, sí, y es el mismo número de la fórmula del consenso.
        let (completo, _, _) = try await montar(lecturas(dias: 14))
        let conGmi = try await completo.ejecutar(dias: 30, conIdentidad: false, ahora: ahora)
        #expect(conGmi.indicadores.gmiEsFiable)
        #expect(conGmi.indicadores.gmi == conGmi.indicadores.indicadores?.gmi)
        #expect(conGmi.indicadores.gmi != nil)
    }

    @Test("6 · RF-16: con menos de tres días el informe no trae cifras, y lo dice")
    func elVacioTambienExisteEnPapel() async throws {
        let (armar, _, _) = try await montar(lecturas(dias: 2))
        let informe = try await armar.ejecutar(dias: 7, conIdentidad: false, ahora: ahora)
        #expect(informe.indicadores.indicadores == nil)
        #expect(informe.indicadores.gmi == nil)
        #expect(informe.indicadores.diasConLecturas == 2)
        #expect(informe.diaTipico.isEmpty)
        // Lo que sí se registró se cuenta igual.
        #expect(informe.conteos.lecturas == 6)
    }

    @Test("7 · RF-16: el desglose por origen suma exactamente las lecturas del periodo")
    func elDesgloseSuma() async throws {
        let (armar, _, _) = try await montar(lecturas(dias: 6))
        let conteos = try await armar.ejecutar(dias: 7, conIdentidad: false, ahora: ahora).conteos

        #expect(conteos.lecturas == 18)
        #expect(conteos.lecturasPorOrigen.values.reduce(0, +) == conteos.lecturas)
        #expect(conteos.lecturasPorOrigen[.sensor] == 6)
        #expect(conteos.lecturasPorOrigen[.manual] == 6)
        #expect(conteos.lecturasPorOrigen[.fotoGlucometro] == 3)
        #expect(conteos.lecturasPorOrigen[.healthkit] == 3)
    }

    @Test("8 · RF-16: el periodo del informe es el que se le pasó, y nada de fuera se cuela")
    func elPeriodoSeRespeta() async throws {
        let (armar, _, _) = try await montar(lecturas(dias: 20))
        let semana = try await armar.ejecutar(dias: 7, conIdentidad: false, ahora: ahora)

        #expect(semana.periodoDias == 7)
        #expect(semana.hasta == ahora)
        #expect(semana.desde == ahora.addingTimeInterval(-7 * 86_400))
        #expect(semana.generadoTsUtc == ahora)
        #expect(semana.conteos.lecturas == 21)             // siete días, tres por día
        #expect(semana.conteos.comidas == 1)               // la de hace cuarenta días no entra
        #expect(semana.conteos.dosis == 2)

        let mes = try await armar.ejecutar(dias: 30, conIdentidad: false, ahora: ahora)
        #expect(mes.conteos.lecturas == 60)
        #expect(mes.conteos.comidas == 1)
    }

    @Test("9 · RF-16: el PDF que se genera existe y no sale vacío")
    func elPdfNoSaleVacio() async throws {
        let (armar, _, _) = try await montar(lecturas(dias: 14))
        let informe = try await armar.ejecutar(dias: 14, conIdentidad: true, ahora: ahora)
        let generador = GeneradorDePdf()

        let url = try generador.generar(InformeView(informe: informe), nombre: "informe-de-prueba")
        defer { generador.borrar(url) }

        #expect(FileManager.default.fileExists(atPath: url.path))
        #expect(url.pathExtension == "pdf")
        // En la carpeta temporal, no en la de la app.
        #expect(url.path.hasPrefix(FileManager.default.temporaryDirectory.path))
        let datos = try Data(contentsOf: url)
        #expect(datos.count > 1_000)
        #expect(datos.prefix(4) == Data("%PDF".utf8))
    }

    @Test("10 · el informe no se queda en el disco: borrar lo deja sin existir")
    func elPdfSeBorra() async throws {
        let (armar, _, _) = try await montar(lecturas(dias: 5))
        let generador = GeneradorDePdf()
        let informe = try await armar.ejecutar(dias: 7, conIdentidad: true, ahora: ahora)
        let url = try generador.generar(InformeView(informe: informe), nombre: "informe-de-prueba")
        #expect(FileManager.default.fileExists(atPath: url.path))

        generador.borrar(url)
        #expect(!FileManager.default.fileExists(atPath: url.path))

        // Y la hoja de compartir lo suelta al cerrarse, y al cambiar el interruptor.
        let modelo = InformeViewModel(armar: armar, periodoDias: 7)
        #expect(!modelo.conIdentidad)
        await modelo.preparar(ahora: ahora)
        let primero = try #require(modelo.archivo)
        #expect(FileManager.default.fileExists(atPath: primero.path))
        #expect(modelo.informe?.identidad == nil)

        await modelo.poner(conIdentidad: true, ahora: ahora.addingTimeInterval(86_400))
        let segundo = try #require(modelo.archivo)
        #expect(modelo.informe?.identidad?.nombre == "Ana")
        #expect(primero != segundo)
        #expect(!FileManager.default.fileExists(atPath: primero.path))

        modelo.cerrar()
        #expect(modelo.archivo == nil)
        #expect(!FileManager.default.fileExists(atPath: segundo.path))
    }
}
