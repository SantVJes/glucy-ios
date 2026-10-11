import Foundation

extension FalloRegistro {
    static let unidadesVacias = FalloRegistro(
        mensaje: "Escribe cuántas unidades te aplicaste.",
        campo: .valor
    )

    static let unidadesFueraDeRango = FalloRegistro(
        mensaje: "Esa cantidad está fuera de lo que Glucy registra. Revisa el número.",
        campo: .valor
    )

    static let unidadesFueraDeResolucion = FalloRegistro(
        mensaje: "Las plumas dosifican de media en media unidad. Prueba con 2.5.",
        campo: .valor
    )

    static let tipoSinElegir = FalloRegistro(
        mensaje: "Elige si fue rápida o basal.",
        campo: .ninguno
    )

    static let dosisNoSePudoGuardar = FalloRegistro(
        mensaje: "No se pudo guardar la dosis. Inténtalo otra vez.",
        campo: .ninguno
    )

    /// Los mensajes de una dosis dicen qué hacer con el campo, nunca qué hacer con el
    /// cuerpo: «revisa el número», no una cantidad a aplicarse (regla 7).
    init(rechazoDeDosis rechazo: Rechazo) {
        switch rechazo {
        case .unidadesNoPositivas: self = .unidadesVacias
        case .fueraDeRango: self = .unidadesFueraDeRango
        case .unidadesFueraDeResolucion: self = .unidadesFueraDeResolucion
        case .marcaDeTiempoFutura: self = .horaFutura
        case .ocrSinConfirmar, .duplicado, .absorcionFueraDeRango, .porcionesNoPositivas:
            self = .dosisNoSePudoGuardar
        }
    }
}

/// Registrar una dosis que la persona **dice haberse aplicado**.
///
/// No hay ninguna función aquí que reciba una glucosa, un objetivo o unos carbohidratos y
/// devuelva unidades. No la hay y no la va a haber: eso es un calculador de bolo, es
/// software médico regulado, y es la regla 7.
///
/// **Es el único camino al repositorio**: ni la vista ni el ViewModel escriben una dosis por
/// su cuenta.
nonisolated struct RegistrarDosis: Sendable {
    let repositorio: any RepositorioDosis
    /// Copia en Salud. Opcional porque la captura no depende de ella (regla 1).
    var salud: EscribirEnHealthKit? = nil

    /// - Parameter unidades: lo que la persona dice haberse aplicado, múltiplo de 0.5.
    /// - Parameter motivo: `nil` si no lo dijo. No se adivina (RF-37 es de comidas, pero el
    ///   principio es el mismo: lo que no se registró, no se infiere).
    /// - Parameter duracionAccionH: la del perfil **en el momento de aplicarse**. Se guarda
    ///   con la dosis para que el IOB del histórico no cambie si mañana el perfil la mueve.
    @discardableResult
    func ejecutar(
        unidades: Double,
        tsUtc: Date,
        tipo: TipoInsulina,
        motivo: MotivoDosis?,
        duracionAccionH: Double,
        ahora: Date = Date()
    ) async throws -> DosisInsulinaDato {
        if let rechazo = Validacion.validarDosis(unidades: unidades, tsUtc: tsUtc, ahora: ahora) {
            // Se rechaza antes de tocar el repositorio: lo que no es válido no llega a la
            // base ni a la cola.
            throw FalloRegistro(rechazoDeDosis: rechazo)
        }

        let dato = DosisInsulinaDato(
            tsUtc: tsUtc,
            unidades: unidades,
            tipo: tipo,
            motivo: motivo,
            // La insulina solo entra a mano. El origen lo pone este caso de uso y no quien
            // lo llama, para que ninguna dosis entre sin él (regla 4).
            origen: .manual,
            duracionAccionH: duracionAccionH
        )
        try await repositorio.guardar(dato)
        // Después de guardar y sin poder fallar el guardado: Salud es una copia, no la
        // fuente (RF-15).
        await salud?.ejecutar(dato)
        return dato
    }

    /// Deshace el último guardado. Borra la dosis, su fila de la cola y su muestra en Salud:
    /// una dosis deshecha en Glucy que siguiera en Salud volvería a aparecer en cualquier
    /// otra app.
    func deshacer(_ dato: DosisInsulinaDato) async throws {
        try await repositorio.eliminar(uuid: dato.uuid)
        await salud?.deshacer(dato)
    }

    /// La última dosis registrada, para proponer el mismo tipo y decir a qué hora fue. `nil`
    /// si no hay ninguna o si la base no respondió: en los dos casos no se propone nada.
    func ultima() async -> DosisInsulinaDato? {
        try? await repositorio.ultima()
    }
}
