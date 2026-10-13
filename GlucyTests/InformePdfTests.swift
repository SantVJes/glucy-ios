import Foundation
import PDFKit
import SwiftUI
import Testing
@testable import Glucy

/// El PDF del informe, leído de vuelta. No se mira: PDFKit lo abre y devuelve su texto, y la
/// prueba afirma lo que una persona tendría que comprobar a ojo antes de mandarlo por correo.
@MainActor
struct InformePdfTests {

    private let ahora = Date(timeIntervalSince1970: 1_758_240_000 + 12 * 3600)

    /// Un nombre que no puede aparecer por casualidad en ninguna plantilla. Si se buscara
    /// «Ana» y la hoja dijera «Ana» en otro sitio, la prueba pasaría por el motivo equivocado.
    private let nombre = "Zzyzx"
    private let apellidos = "Qwertyuiop"
    /// Un peso con decimales raros, por lo mismo: «70» sale en el eje de la gráfica.
    private let pesoKg = 93.7
    private let anio = 1967
    private let palabraDeLasNotas = "Xilofonazo"

    private func montar() async throws -> (ArmarInforme, PerfilDato) {
        let lecturas = RepositorioLecturasFalso()
        for dia in 0..<15 {
            for (indice, mgDl) in [104.0, 131, 162].enumerated() {
                try await lecturas.guardar(LecturaGlucosaDato(
                    mgDl: mgDl,
                    tsUtc: ahora.addingTimeInterval(-Double(dia) * 86_400 - Double(indice) * 3600 - 60),
                    zonaHoraria: "UTC",
                    origen: indice == 0 ? .sensor : .manual,
                    nota: "\(palabraDeLasNotas) después de comer"
                ))
            }
        }
        let persona = PerfilDato(
            nombre: nombre, apellidos: apellidos, pesoKg: pesoKg,
            fechaNacimiento: ReglasDePerfil.fechaDeAnio(anio), tipoUsuario: .tipo1,
            consentimientoTsUtc: ahora
        )
        let perfil = RepositorioPerfilFalso(persona)
        let armar = ArmarInforme(
            historial: ConsultarHistorial(lecturas: lecturas, perfil: perfil),
            lecturas: lecturas, comidas: RepositorioComidasFalso(), dosis: RepositorioDosisFalso(),
            perfil: perfil
        )
        return (armar, persona)
    }

    /// El texto del PDF tal como lo leería quien lo abre. Si viniera vacío, el PDF habría
    /// salido como una imagen sin capa de texto y nada de lo que sigue probaría nada.
    private func textoDelPdf(conIdentidad: Bool) async throws -> (texto: String, persona: PerfilDato) {
        let (armar, persona) = try await montar()
        let informe = try await armar.ejecutar(dias: 30, conIdentidad: conIdentidad, ahora: ahora)
        let generador = GeneradorDePdf()
        let url = try generador.generar(InformeView(informe: informe), nombre: "informe-leido-de-vuelta")
        defer { generador.borrar(url) }

        let documento = try #require(PDFDocument(url: url), "PDFKit no pudo abrir el archivo")
        #expect(documento.pageCount == 1)
        let texto = try #require(documento.string)
        try #require(
            texto.count > 200,
            "El PDF no trae capa de texto: salió como imagen y no se puede afirmar qué dice"
        )
        return (texto, persona)
    }

    /// Casilla 16. Con el interruptor apagado, el nombre no está en el archivo. No «no se
    /// ve»: no está, y eso es lo que importa cuando el PDF se va por correo.
    @Test("casilla 16 · sin el interruptor, el PDF no trae nombre, apellidos, año ni peso")
    func sinIdentidadElPdfNoTraeElNombre() async throws {
        let (texto, _) = try await textoDelPdf(conIdentidad: false)

        #expect(!texto.contains(nombre))
        #expect(!texto.contains(apellidos))
        #expect(!texto.contains("93.7"))
        #expect(!texto.contains(String(anio)))
        #expect(!texto.contains("Datos de la persona"))
        // Lo que sí tiene que traer: sus cifras.
        #expect(texto.contains("Informe de glucosa"))
        #expect(texto.contains("Tiempo en rango"))
        #expect(texto.contains("sobre 45 mediciones"))
    }

    /// Casilla 17. Con el interruptor encendido, sí.
    @Test("casilla 17 · con el interruptor, el PDF trae nombre, apellidos, año y peso")
    func conIdentidadElPdfTraeElNombre() async throws {
        let (texto, _) = try await textoDelPdf(conIdentidad: true)

        #expect(texto.contains(nombre))
        #expect(texto.contains(apellidos))
        #expect(texto.contains("93.7"))
        #expect(texto.contains(String(anio)))
    }

    /// La regla 3 comprobada sobre el archivo, no prometida.
    @Test("regla 3 · el PDF nunca trae el UUID del perfil ni las notas", arguments: [false, true])
    func niElUuidNiLasNotas(conIdentidad: Bool) async throws {
        let (texto, persona) = try await textoDelPdf(conIdentidad: conIdentidad)

        #expect(!texto.localizedCaseInsensitiveContains(persona.uuid.uuidString))
        // Ni un trozo: los ocho primeros caracteres ya lo delatarían.
        #expect(!texto.localizedCaseInsensitiveContains(String(persona.uuid.uuidString.prefix(8))))
        #expect(!texto.localizedCaseInsensitiveContains(palabraDeLasNotas))
    }

    /// Si una plantilla cambia y este párrafo se cae, nadie lo notaría nunca.
    @Test("el PDF trae el aviso de que Glucy no es un dispositivo médico", arguments: [false, true])
    func elAvisoEstaEnLaHoja(conIdentidad: Bool) async throws {
        let (texto, _) = try await textoDelPdf(conIdentidad: conIdentidad)
        // El salto de renglón cae donde quiera el ancho de la hoja: se compara sin espacios.
        let junto = texto.filter { !$0.isWhitespace }
        #expect(junto.contains("Glucynoesundispositivomédicocertificado."))
        #expect(junto.contains("nosustituyenunamedicióndelaboratorioniunaindicaciónmédica."))
        // Y ninguna predicción: en la fase 1 no hay modelo.
        #expect(!texto.localizedCaseInsensitiveContains("predicción"))
    }

    @Test("después de cerrar la hoja, el archivo ya no existe")
    func alCerrarNoQuedaElArchivo() async throws {
        let (armar, _) = try await montar()
        let modelo = InformeViewModel(armar: armar, periodoDias: 30)

        await modelo.poner(conIdentidad: true, ahora: ahora)
        let url = try #require(modelo.archivo)
        #expect(FileManager.default.fileExists(atPath: url.path))
        // Con el nombre dentro: es justo el archivo que no puede quedarse.
        #expect(try #require(PDFDocument(url: url)?.string).contains(nombre))

        modelo.cerrar()
        #expect(!FileManager.default.fileExists(atPath: url.path))
        #expect(modelo.archivo == nil)
    }
}
