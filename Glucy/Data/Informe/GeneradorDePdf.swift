import SwiftUI

/// Lo que puede salir mal al escribir el informe.
nonisolated enum ErrorDeInforme: Error {
    case noSePudoEscribir
}

/// Rasteriza la vista del informe a un PDF temporal. Lo único de la app que sabe qué es un
/// PDF, igual que `HealthKitReal` es lo único que sabe qué es `HKSample`.
@MainActor
struct GeneradorDePdf {

    /// Una carpeta propia dentro de la temporal, para poder vaciarla entera.
    private static var carpeta: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("Informes", isDirectory: true)
    }

    /// Escribe el PDF en la carpeta temporal y devuelve su URL.
    ///
    /// Antes vacía la carpeta: si la app se cerró con un informe a medio compartir, ese
    /// archivo no sobrevive al siguiente.
    func generar(_ vista: some View, nombre: String) throws -> URL {
        borrarTodos()
        try FileManager.default.createDirectory(at: Self.carpeta, withIntermediateDirectories: true)
        let url = Self.carpeta.appendingPathComponent(nombre).appendingPathExtension("pdf")

        var escrito = false
        let rasterizador = ImageRenderer(content: vista)
        rasterizador.render { tamano, dibujar in
            var hoja = CGRect(origin: .zero, size: tamano)
            guard tamano.width > 0, tamano.height > 0,
                  let pdf = CGContext(url as CFURL, mediaBox: &hoja, nil) else { return }
            pdf.beginPDFPage(nil)
            dibujar(pdf)
            pdf.endPDFPage()
            pdf.closePDF()
            escrito = true
        }

        guard escrito, FileManager.default.fileExists(atPath: url.path) else {
            // Lo que haya quedado a medias tampoco se queda.
            borrar(url)
            throw ErrorDeInforme.noSePudoEscribir
        }
        return url
    }

    /// Lo borra. Se llama al cerrarse la hoja de compartir, y también si algo falla a medias:
    /// un informe con el nombre de la persona dentro no se queda en el disco.
    func borrar(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    /// Todo lo que haya en la carpeta de informes.
    func borrarTodos() {
        try? FileManager.default.removeItem(at: Self.carpeta)
    }
}
