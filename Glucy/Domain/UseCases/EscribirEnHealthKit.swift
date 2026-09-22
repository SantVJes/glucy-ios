import Foundation

/// Sube a Salud la glucosa que **Glucy** capturó, y solo esa (RF-15, RF-15b).
///
/// Salud es una copia; el teléfono es el dueño del dato (regla 1). Por eso nada de aquí
/// lanza: si Salud rechaza la escritura, la lectura ya está guardada en el teléfono y la
/// persona no tiene nada que corregir.
nonisolated struct EscribirEnHealthKit: Sendable {
    let servicio: any ServicioHealthKit
    let lecturas: any RepositorioLecturas

    /// Devuelve `true` si la lectura quedó escrita en Salud.
    @discardableResult
    func ejecutar(_ dato: LecturaGlucosaDato) async -> Bool {
        // Solo se escribe lo que Glucy capturó: a mano o por foto. Una lectura de origen
        // sensor ya está en Salud, y volver a escribirla duplica la serie en cada arranque
        // (RF-15b, caso P-14). Es una lista de los que sí, no de los que no: un origen
        // nuevo no se escribe hasta que alguien decida que debe.
        guard Self.origenesQueSeEscriben.contains(dato.origen),
              !dato.escritaEnHealthKit,
              servicio.disponible else { return false }

        do {
            try await servicio.escribirGlucosa(dato)
        } catch {
            return false
        }
        // Que no se pueda anotar no deshace la escritura: la muestra lleva el UUID como
        // identificador de sincronización, y escribirla otra vez la reemplaza en Salud.
        try? await lecturas.marcarEscritaEnHealthKit(uuid: dato.uuid)
        return true
    }

    /// Quita de Salud lo que se escribió con esa lectura. Para el «Deshacer».
    func deshacer(_ dato: LecturaGlucosaDato) async {
        guard Self.origenesQueSeEscriben.contains(dato.origen), servicio.disponible else { return }
        try? await servicio.eliminarGlucosa(uuid: dato.uuid)
    }

    private static let origenesQueSeEscriben: Set<Origen> = [.manual, .fotoGlucometro]
}
