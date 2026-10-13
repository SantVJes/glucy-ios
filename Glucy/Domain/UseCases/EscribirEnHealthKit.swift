import Foundation

/// Sube a Salud la glucosa, los carbohidratos y la insulina que **Glucy** capturó, y solo
/// eso (RF-15, RF-15b).
///
/// Salud es una copia; el teléfono es el dueño del dato (regla 1). Por eso nada de aquí
/// lanza: si Salud rechaza la escritura, el registro ya está guardado en el teléfono y la
/// persona no tiene nada que corregir.
///
/// Los tres tipos viven en este archivo y no en tres casos de uso hermanos para que la lista
/// de orígenes que sí se escriben y el «no lanzar nunca» estén en un solo lugar.
nonisolated struct EscribirEnHealthKit: Sendable {
    let servicio: any ServicioHealthKit
    let lecturas: any RepositorioLecturas
    /// Solo para anotar que la muestra quedó escrita. Sin ellos se escribe igual.
    var comidas: (any RepositorioComidas)? = nil
    var dosis: (any RepositorioDosis)? = nil

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

    // MARK: - Carbohidratos

    /// Devuelve `true` si la comida quedó escrita en Salud como carbohidratos.
    @discardableResult
    func ejecutar(_ dato: ComidaDato) async -> Bool {
        guard Self.origenesDeComidaQueSeEscriben.contains(dato.origen),
              !dato.escritaEnHealthKit,
              servicio.disponible else { return false }

        do {
            try await servicio.escribirCarbohidratos(dato)
        } catch {
            return false
        }
        try? await comidas?.marcarEscritaEnHealthKit(uuid: dato.uuid)
        return true
    }

    /// Quita de Salud lo que se escribió con esa comida. Para el «Deshacer».
    func deshacer(_ dato: ComidaDato) async {
        guard Self.origenesDeComidaQueSeEscriben.contains(dato.origen),
              servicio.disponible else { return }
        try? await servicio.eliminarCarbohidratos(uuid: dato.uuid)
    }

    /// Las tres vías por las que Glucy captura una comida. Como arriba, es una lista de las
    /// que sí.
    private static let origenesDeComidaQueSeEscriben: Set<Origen> = [
        .manual, .barcode, .ocrEtiqueta,
    ]

    // MARK: - Insulina

    /// Devuelve `true` si la dosis quedó escrita en Salud.
    @discardableResult
    func ejecutar(_ dato: DosisInsulinaDato) async -> Bool {
        guard Self.origenesDeDosisQueSeEscriben.contains(dato.origen),
              !dato.escritaEnHealthKit,
              servicio.disponible else { return false }

        do {
            try await servicio.escribirInsulina(dato)
        } catch {
            return false
        }
        try? await dosis?.marcarEscritaEnHealthKit(uuid: dato.uuid)
        return true
    }

    /// Quita de Salud lo que se escribió con esa dosis. Para el «Deshacer».
    func deshacer(_ dato: DosisInsulinaDato) async {
        guard Self.origenesDeDosisQueSeEscriben.contains(dato.origen),
              servicio.disponible else { return }
        try? await servicio.eliminarInsulina(uuid: dato.uuid)
    }

    /// La insulina solo entra a mano: Glucy no la lee de Salud ni de ningún otro lado.
    private static let origenesDeDosisQueSeEscriben: Set<Origen> = [.manual]
}
