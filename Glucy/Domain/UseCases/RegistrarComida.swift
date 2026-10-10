import Foundation

extension FalloRegistro {
    static let carbohidratosFueraDeRango = FalloRegistro(
        mensaje: "Esa cantidad está fuera de lo que puedo registrar. Anota entre "
            + "\(Int(ConfiguracionDominio.carbsMinimos)) y "
            + "\(Int(ConfiguracionDominio.carbsMaximos)) g de carbohidratos.",
        campo: .valor
    )

    static let carbohidratosVacios = FalloRegistro(
        mensaje: "Escribe cuántos gramos de carbohidratos fueron.",
        campo: .valor
    )

    static let porcionSinGramos = FalloRegistro(
        mensaje: "¿Cuántos gramos trae una porción? Viene en la etiqueta.",
        campo: .valor
    )

    static let porcionesNoPositivas = FalloRegistro(
        mensaje: "Anota cuántas porciones fueron. Tiene que ser más de cero.",
        campo: .valor
    )

    static let comidaNoSePudoGuardar = FalloRegistro(
        mensaje: "No se pudo guardar la comida. Inténtalo otra vez.",
        campo: .ninguno
    )

    /// El mismo rechazo se dice distinto en una comida que en una lectura: «lo que un
    /// medidor puede leer» no significa nada cuando lo que se anota son gramos.
    init(rechazoDeComida rechazo: Rechazo) {
        switch rechazo {
        case .fueraDeRango: self = .carbohidratosFueraDeRango
        case .marcaDeTiempoFutura: self = .horaFutura
        case .porcionesNoPositivas: self = .porcionesNoPositivas
        case .absorcionFueraDeRango, .ocrSinConfirmar, .duplicado: self = .comidaNoSePudoGuardar
        }
    }
}

/// Registrar una comida.
///
/// **Es el único camino al repositorio.** Ni la vista, ni el ViewModel, ni la búsqueda del
/// producto escriben una comida por su cuenta, y no existe ninguna función que cree una sin
/// que la persona haya tocado «Guardar»: ni sugerida, ni probable, ni deducida de una subida
/// de glucosa (D-9, RF-37).
nonisolated struct RegistrarComida: Sendable {
    let repositorio: any RepositorioComidas

    /// - Parameter carbsG: los gramos que la persona confirmó. **Es el dato.**
    /// - Parameter origen: `.barcode`, `.ocrEtiqueta` o `.manual`, según de dónde salió el
    ///   número, no dónde se tocó el botón (regla 4).
    /// - Parameter porcionG: los gramos de una porción. Obligatorio cuando el número salió
    ///   de un producto o de una etiqueta, porque ahí los carbohidratos vienen por 100 g.
    func ejecutar(
        carbsG: Double,
        tsUtc: Date,
        origen: Origen,
        tiempoAbsorcionMin: Int = ConfiguracionDominio.absorcionPorOmisionMin,
        descripcion: String? = nil,
        codigoBarras: String? = nil,
        nombreProducto: String? = nil,
        porcionG: Double? = nil,
        porciones: Double = 1,
        ahora: Date = Date()
    ) async throws -> ComidaDato {
        // Sin los gramos de la porción no hay forma honrada de llegar de «por 100 g» a lo
        // que la persona se comió. No se suponen 100: se rechaza y se pregunta (RF-37).
        if origen != .manual {
            guard let porcionG, porcionG > 0 else { throw FalloRegistro.porcionSinGramos }
        }

        if let rechazo = Validacion.validarComida(
            carbsG: carbsG,
            tiempoAbsorcionMin: tiempoAbsorcionMin,
            porciones: porciones,
            tsUtc: tsUtc,
            ahora: ahora
        ) {
            // Se rechaza antes de tocar el repositorio: lo que no es válido no llega a la
            // base ni a la cola.
            throw FalloRegistro(rechazoDeComida: rechazo)
        }

        let dato = ComidaDato(
            tsUtc: tsUtc,
            carbsG: carbsG,
            tiempoAbsorcionMin: tiempoAbsorcionMin,
            origen: origen,
            descripcion: descripcion,
            codigoBarras: codigoBarras,
            nombreProducto: nombreProducto,
            porcionG: porcionG,
            porciones: porciones,
            // Cierto por construcción: aquí solo se llega desde el botón de guardar, con el
            // número a la vista (D-11).
            confirmadaPorUsuario: true
        )
        try await repositorio.guardar(dato)
        return dato
    }

    /// Deshace el último guardado. Borra la comida y su fila de la cola.
    func deshacer(_ dato: ComidaDato) async throws {
        try await repositorio.eliminar(uuid: dato.uuid)
    }
}
