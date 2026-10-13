import Foundation

/// Registrar una glucosa leída de la foto del glucómetro.
///
/// **Solo existe un camino al repositorio, y pasa por el valor confirmado.** No hay una
/// versión de `ejecutar` que reciba lo que leyó el OCR y lo guarde sin más: guardar sin que
/// la persona apruebe el número es justo lo que D-11 prohíbe, con la confianza que sea
/// (RF-02, caso P-01). Si solo hay una puerta, nadie entra por la ventana.
nonisolated struct RegistrarLecturaPorFoto: Sendable {
    let repositorio: any RepositorioLecturas
    /// Copia en Salud. Opcional porque la captura no depende de ella (regla 1).
    var salud: EscribirEnHealthKit? = nil

    /// - Parameter valorConfirmado: lo que la persona aprobó. **Es el dato clínico.**
    /// - Parameter valorLeidoOcr: lo que el OCR había propuesto, o `nil` si no leyó nada
    ///   y la persona escribió el número (RF-03).
    /// - Parameter confianzaOcr: lo que el OCR reportó. Se guarda y no decide nada (D-11).
    func ejecutar(
        valorConfirmado: Double,
        valorLeidoOcr: Double?,
        confianzaOcr: Double?,
        tsUtc: Date,
        contexto: ContextoComida?,
        ahora: Date = Date()
    ) async throws -> LecturaGlucosaDato {
        // La misma validación del paso 3, con el origen que toca. Un 900 leído por el OCR y
        // confirmado por error tampoco se guarda (RF-05).
        //
        // `confirmadaPorUsuario: true` no es una fórmula: es cierto por construcción,
        // porque a esta función solo se llega desde la pantalla de confirmación.
        if let rechazo = Validacion.validarLectura(
            mgDl: valorConfirmado,
            tsUtc: tsUtc,
            ahora: ahora,
            origen: .fotoGlucometro,
            confirmadaPorUsuario: true
        ) {
            throw FalloRegistro(rechazo: rechazo)
        }

        let dato = LecturaGlucosaDato(
            mgDl: valorConfirmado,
            tsUtc: tsUtc,
            origen: .fotoGlucometro,
            contexto: contexto,
            confirmadaPorUsuario: true,
            valorLeidoOcr: valorLeidoOcr,
            // No se pide como parámetro: se deduce. Un dato que se puede calcular y además
            // se recibe es un dato que algún día llega mal.
            fueCorregido: Self.huboCorreccion(confirmado: valorConfirmado, leido: valorLeidoOcr),
            confianzaOcr: confianzaOcr
        )

        try await repositorio.guardar(dato)
        // Después de guardar y sin poder tumbarlo: Salud es una copia, no la fuente. El
        // origen `.fotoGlucometro` ya está en la lista de los que se escriben (RF-15).
        await salud?.ejecutar(dato)
        return dato
    }

    /// Hubo corrección cuando el valor guardado no es el que propuso el OCR.
    ///
    /// Si el OCR no leyó nada, no hay nada que corregir: la persona escribió el número
    /// desde cero, que es el caso de RF-03, y eso no es una corrección.
    private static func huboCorreccion(confirmado: Double, leido: Double?) -> Bool {
        guard let leido else { return false }
        return confirmado != leido
    }
}
