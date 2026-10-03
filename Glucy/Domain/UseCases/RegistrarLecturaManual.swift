import Foundation

/// Lo que la pantalla necesita saber cuando algo no se pudo guardar.
///
/// Es el `Rechazo` del paso 1 ya traducido a algo que se puede enseñar. La traducción vive
/// aquí y no en la vista para que el mismo texto salga igual en las tres vías de captura.
nonisolated struct FalloRegistro: Error, Equatable {
    let mensaje: String
    let campo: CampoRegistro
}

/// A qué campo hay que llevar a la persona para que corrija.
nonisolated enum CampoRegistro: Equatable { case valor, fecha, ninguno }

extension FalloRegistro {
    /// Los mensajes, palabra por palabra. Son los que va a leer alguien a las tres de la
    /// mañana: no dicen «error», no dicen «inválido» y no nombran ninguna regla. Dicen qué
    /// corregir.
    ///
    /// Viven juntos porque las tres vías de captura —a mano, foto y sensor— tienen que
    /// decir exactamente lo mismo ante el mismo rechazo.
    static let fueraDeRango = FalloRegistro(
        mensaje: "Ese valor está fuera de lo que un medidor puede leer. "
            + "Anota un número entre 20 y 600 mg/dL.",
        campo: .valor
    )

    static let horaFutura = FalloRegistro(
        mensaje: "Esa hora todavía no llega. Revisa la fecha.",
        campo: .fecha
    )

    static let valorVacio = FalloRegistro(
        mensaje: "Escribe el número que te marcó el medidor.",
        campo: .valor
    )

    static let noSePudoGuardar = FalloRegistro(
        mensaje: "No se pudo guardar la lectura. Inténtalo otra vez.",
        campo: .ninguno
    )

    /// Traduce el rechazo del paso 1. Los dos casos que esta pantalla no puede producir
    /// —OCR sin confirmar y duplicado— caen en el mensaje general en lugar de inventarse
    /// uno: un texto que nadie va a ver no se puede revisar.
    init(rechazo: Rechazo) {
        switch rechazo {
        case .fueraDeRango: self = .fueraDeRango
        case .marcaDeTiempoFutura: self = .horaFutura
        case .ocrSinConfirmar, .duplicado: self = .noSePudoGuardar
        }
    }
}

/// Registrar a mano una lectura de glucosa.
///
/// Aquí vive la única llamada a la validación. La vista no valida y el ViewModel tampoco:
/// la regla ya está probada desde el paso 1 y una segunda copia es una segunda copia que
/// algún día va a estar en otro valor (RF-05).
nonisolated struct RegistrarLecturaManual: Sendable {
    let repositorio: any RepositorioLecturas
    /// Copia en Salud. Opcional porque la captura no depende de ella: sin Salud, sin
    /// permiso o en las pruebas del paso 3, la lectura se guarda igual (regla 1).
    var salud: EscribirEnHealthKit? = nil

    /// Valida, pone el origen y guarda. Devuelve la lectura tal como quedó guardada.
    ///
    /// El origen lo pone este caso de uso, no quien lo llama: es la única forma de
    /// garantizar que ninguna lectura entre sin él (regla 4, RF-04).
    func ejecutar(
        mgDl: Double,
        tsUtc: Date,
        contexto: ContextoComida?,
        nota: String? = nil,
        ahora: Date = Date()
    ) async throws -> LecturaGlucosaDato {
        if let rechazo = Validacion.validarLectura(
            mgDl: mgDl,
            tsUtc: tsUtc,
            ahora: ahora,
            origen: .manual,
            confirmadaPorUsuario: true
        ) {
            // Se rechaza antes de tocar el repositorio: lo que no es válido no llega a la
            // base ni a la cola.
            throw FalloRegistro(rechazo: rechazo)
        }

        let dato = LecturaGlucosaDato(
            mgDl: mgDl,
            tsUtc: tsUtc,
            origen: .manual,
            contexto: contexto,
            nota: nota
        )
        try await repositorio.guardar(dato)
        // Después de guardar y sin poder fallar el guardado: Salud es una copia, no la
        // fuente (RF-15).
        await salud?.ejecutar(dato)
        return dato
    }

    /// Deshace el último guardado. Borra la lectura y su fila de la cola.
    ///
    /// Deshacer es mejor que preguntar «¿estás seguro?»: no interrumpe a quien acertó y
    /// rescata a quien se equivocó.
    func deshacer(_ dato: LecturaGlucosaDato) async throws {
        try await repositorio.eliminar(uuid: dato.uuid)
        // Si ya se había escrito en Salud, se quita de ahí también: una lectura deshecha
        // en Glucy que siguiera en Salud volvería a aparecer en cualquier otra app.
        await salud?.deshacer(dato)
    }
}
