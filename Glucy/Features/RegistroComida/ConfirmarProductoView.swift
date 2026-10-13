import SwiftUI

/// La ficha de lo que se encontró —el producto del código de barras o los carbohidratos de
/// la etiqueta— con la cuenta a la vista.
///
/// **Aquí no se guarda nada.** Se enseña lo que se leyó, se pregunta lo que falta y la cifra
/// final se ve calculada con sus tres factores; guardar es el botón de la pantalla, un gesto
/// aparte (D-11).
struct ConfirmarProductoView: View {
    @Bindable var modelo: RegistroComidaViewModel
    var campoEnfocado: FocusState<RegistroComidaView.Campo?>.Binding

    @ScaledMetric private var tamanoCifra: CGFloat = Tema.Tipografia.tamanoCifraSecundaria

    var body: some View {
        VStack(alignment: .leading, spacing: Tema.Espacio.interior) {
            encabezado
            porcion
            porciones
            resultado

            if case .producto = modelo.via {
                // La atribución va aquí, en la pantalla que usa el dato, y no en los
                // créditos de Ajustes: lo pide la licencia y además es honesto, porque
                // estos datos los captura gente voluntaria.
                Text("Datos del producto: Open Food Facts (ODbL). Pueden estar incompletos.")
                    .font(Tema.Tipografia.etiqueta)
                    .foregroundStyle(Tema.Colores.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("atribucionProducto")
            }

            Button("Mejor escribo yo los carbohidratos") { modelo.escribirAMano() }
                .font(Tema.Tipografia.etiqueta)
                .foregroundStyle(Tema.Colores.azulPrimario)
                .frame(minHeight: Tema.Medida.areaTocable)
                .accessibilityIdentifier("botonSoltarProducto")
        }
        .padding(Tema.Espacio.interior)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tema.Colores.superficie)
        .clipShape(RoundedRectangle(cornerRadius: Tema.Radio.tarjetaGrande))
    }

    // MARK: - Partes

    @ViewBuilder
    private var encabezado: some View {
        switch modelo.via {
        case .producto(let producto):
            VStack(alignment: .leading, spacing: Tema.Espacio.unidad) {
                Text(producto.nombre)
                    .font(Tema.Tipografia.tituloTarjeta)
                    .foregroundStyle(Tema.Colores.textoPrincipal)
                    .fixedSize(horizontal: false, vertical: true)
                if let marca = producto.marca {
                    Text(marca)
                        .font(Tema.Tipografia.etiqueta)
                        .foregroundStyle(Tema.Colores.textoSecundario)
                }
                Text("\(RegistroComidaViewModel.texto(producto.carbsPor100g)) g de carbohidratos por cada 100 g")
                    .font(Tema.Tipografia.textoLectura)
                    .foregroundStyle(Tema.Colores.textoPrincipal)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("fichaProducto")

        case .etiqueta:
            VStack(alignment: .leading, spacing: Tema.Espacio.unidad * 2) {
                Label("Lo leí de la foto de la etiqueta", systemImage: "camera.fill")
                    .font(Tema.Tipografia.etiqueta)
                    .foregroundStyle(Tema.Colores.textoSecundario)
                Text("¿Es lo que dice la tabla?")
                    .font(Tema.Tipografia.tituloTarjeta)
                    .foregroundStyle(Tema.Colores.textoPrincipal)
                campo(
                    texto: $modelo.textoCarbsPor100g,
                    unidad: "g por cada 100 g",
                    descripcion: "Gramos de carbohidratos por cada 100 gramos",
                    enfoque: .carbsPor100g
                )
                // El borde ámbar marca lo que salió del OCR y falta confirmar, igual que en
                // la foto del glucómetro. Como borde, nunca como letra.
                .overlay(
                    RoundedRectangle(cornerRadius: Tema.Radio.campo)
                        .stroke(Tema.Colores.alertaAmbar, lineWidth: 3)
                )
            }

        case .manual:
            EmptyView()
        }
    }

    private var porcion: some View {
        VStack(alignment: .leading, spacing: Tema.Espacio.unidad * 2) {
            Text("¿Cuántos gramos trae una porción? Viene en la etiqueta.")
                .font(Tema.Tipografia.valorFila)
                .foregroundStyle(Tema.Colores.textoPrincipal)
                .fixedSize(horizontal: false, vertical: true)
            campo(
                texto: $modelo.textoPorcionG,
                unidad: "g por porción",
                descripcion: "Gramos que trae una porción",
                enfoque: .porcionG
            )
            .accessibilityIdentifier("campoPorcionG")
        }
    }

    private var porciones: some View {
        VStack(alignment: .leading, spacing: Tema.Espacio.unidad * 2) {
            Text("¿Cuántas porciones fueron?")
                .font(Tema.Tipografia.valorFila)
                .foregroundStyle(Tema.Colores.textoPrincipal)
            campo(
                texto: $modelo.textoPorciones,
                unidad: "porciones",
                descripcion: "Número de porciones",
                enfoque: .porciones
            )
            .accessibilityIdentifier("campoPorciones")
        }
    }

    /// La cifra que se va a guardar, con sus tres factores. Si falta la porción **no hay
    /// cifra**: ni un cero ni una cuenta hecha con 100 g que nadie dijo.
    @ViewBuilder
    private var resultado: some View {
        if let carbohidratos = modelo.carbohidratos, let desglose = modelo.desglose {
            VStack(alignment: .leading, spacing: Tema.Espacio.unidad) {
                HStack(alignment: .firstTextBaseline, spacing: Tema.Espacio.unidad * 2) {
                    Text(RegistroComidaViewModel.texto(carbohidratos))
                        .font(.system(size: tamanoCifra, weight: .bold))
                        .foregroundStyle(Tema.Colores.azulProfundo)
                    Text("g de carbohidratos")
                        .font(Tema.Tipografia.textoLectura)
                        .foregroundStyle(Tema.Colores.textoSecundario)
                }
                Text(desglose)
                    .font(Tema.Tipografia.etiqueta)
                    .foregroundStyle(Tema.Colores.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                "\(RegistroComidaViewModel.texto(carbohidratos)) gramos de carbohidratos. \(desglose)"
            )
            .accessibilityIdentifier("resultadoCarbohidratos")
        } else {
            Label(
                modelo.faltaLaPorcion
                    ? "Me faltan los gramos de la porción para hacer la cuenta."
                    : "Me falta un dato para hacer la cuenta.",
                systemImage: "questionmark.circle"
            )
            .font(Tema.Tipografia.etiqueta)
            .foregroundStyle(Tema.Colores.textoSecundario)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("faltaUnDato")
        }
    }

    private func campo(
        texto: Binding<String>,
        unidad: String,
        descripcion: String,
        enfoque: RegistroComidaView.Campo
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Tema.Espacio.unidad * 2) {
            TextField("", text: texto)
                .font(Tema.Tipografia.tituloPantalla)
                .foregroundStyle(Tema.Colores.azulProfundo)
                .keyboardType(.decimalPad)
                .focused(campoEnfocado, equals: enfoque)
                .accessibilityLabel(descripcion)
            Text(unidad)
                .font(Tema.Tipografia.textoLectura)
                .foregroundStyle(Tema.Colores.textoSecundario)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, Tema.Espacio.interior)
        .frame(minHeight: Tema.Medida.botonPrincipal)
        .background(Tema.Colores.fondo)
        .clipShape(RoundedRectangle(cornerRadius: Tema.Radio.campo))
    }
}
