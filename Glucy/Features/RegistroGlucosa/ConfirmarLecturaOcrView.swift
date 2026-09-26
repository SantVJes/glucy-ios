import SwiftUI

/// Lo que se ve después de la foto: el número que leyó la app y la pregunta.
///
/// **Aquí no se guarda nada.** Al confirmar, el valor se lleva al campo de la pantalla de
/// registro para que se le pueda poner contexto y hora; guardar es un gesto aparte y
/// explícito. Así la confirmación de D-11 se cumple dos veces (RF-02, caso P-01).
///
/// La confianza del OCR no se enseña: enseñarla invitaría a confiar en ella, y no decide
/// nada.
struct ConfirmarLecturaOcrView: View {
    @Bindable var modelo: RegistroGlucosaViewModel
    @FocusState private var campoEnfocado: Bool
    @State private var corrigiendo = false

    @ScaledMetric private var tamanoCifra: CGFloat = Tema.Tipografia.tamanoCifraGlucosa

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Tema.Espacio.entreTarjetas) {
                switch modelo.estadoFoto {
                case .procesando:
                    estadoProcesando
                case .leido(let numero):
                    if corrigiendo {
                        campoDeCorreccion
                    } else {
                        propuesta(numero)
                    }
                case .sinNumero:
                    sinNumero
                case .camaraNegada:
                    camaraNegada
                case .ninguno:
                    EmptyView()
                }

                if let fallo = modelo.fallo {
                    Label {
                        Text(fallo.mensaje)
                            .font(Tema.Tipografia.etiqueta)
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                    }
                    .foregroundStyle(Tema.Colores.hipoglucemia)
                }

                Spacer()
            }
            .padding(.horizontal, Tema.Espacio.margenLateral)
            .padding(.top, Tema.Espacio.interior)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Tema.Colores.fondo)
            .safeAreaInset(edge: .bottom) { botones }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { modelo.cerrarFoto() }
                }
            }
        }
        .onChange(of: modelo.fallo) { _, nuevo in
            guard let nuevo else { return }
            AccessibilityNotification.Announcement(nuevo.mensaje).post()
        }
    }

    // MARK: - Estados

    private var estadoProcesando: some View {
        HStack(spacing: Tema.Espacio.interior) {
            ProgressView()
            Text("Leyendo la pantalla…")
                .font(Tema.Tipografia.textoLectura)
                .foregroundStyle(Tema.Colores.textoSecundario)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, Tema.Espacio.margenLateral)
    }

    private func propuesta(_ numero: NumeroLeido) -> some View {
        VStack(alignment: .leading, spacing: Tema.Espacio.interior) {
            Text("¿Es este el valor que te marcó?")
                .font(Tema.Tipografia.tituloPantalla)
                .foregroundStyle(Tema.Colores.textoPrincipal)
                .fixedSize(horizontal: false, vertical: true)

            HStack(alignment: .firstTextBaseline, spacing: Tema.Espacio.unidad * 2) {
                Text(textoDelValor(numero.valor))
                    .font(.system(size: tamanoCifra, weight: .bold))
                    .foregroundStyle(Tema.Colores.azulProfundo)
                Text("mg/dL")
                    .font(Tema.Tipografia.textoLectura)
                    .foregroundStyle(Tema.Colores.textoSecundario)
            }
            .padding(Tema.Espacio.interior)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Tema.Colores.superficie)
            .clipShape(RoundedRectangle(cornerRadius: Tema.Radio.bloqueInterno))
            // El recuadro ámbar sobre la zona interpretada no es adorno: es lo que deja ver
            // que el número señalado es el de la glucosa y no el de la hora. Va como
            // **borde**, nunca como texto, que es lo que dice el tema.
            .overlay(
                RoundedRectangle(cornerRadius: Tema.Radio.bloqueInterno)
                    .stroke(Tema.Colores.alertaAmbar, lineWidth: 3)
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Leí \(textoDelValor(numero.valor)) miligramos por decilitro")

            Text("Lo paso a la pantalla de registro por si quieres ponerle la hora o el "
                + "momento de la comida. Todavía no se guarda.")
                .font(Tema.Tipografia.etiqueta)
                .foregroundStyle(Tema.Colores.textoSecundario)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var campoDeCorreccion: some View {
        VStack(alignment: .leading, spacing: Tema.Espacio.interior) {
            Text("Escribe el valor correcto")
                .font(Tema.Tipografia.tituloPantalla)
                .foregroundStyle(Tema.Colores.textoPrincipal)

            HStack(alignment: .firstTextBaseline, spacing: Tema.Espacio.unidad * 2) {
                // Arranca con el valor propuesto ya escrito, para no teclear desde cero.
                TextField("", text: $modelo.textoCorreccion)
                    .font(.system(size: tamanoCifra, weight: .bold))
                    .foregroundStyle(Tema.Colores.azulProfundo)
                    .keyboardType(.decimalPad)
                    .focused($campoEnfocado)
                    .accessibilityLabel("Valor de glucosa en miligramos por decilitro")
                Text("mg/dL")
                    .font(Tema.Tipografia.textoLectura)
                    .foregroundStyle(Tema.Colores.textoSecundario)
            }
            .padding(Tema.Espacio.interior)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Tema.Colores.superficie)
            .clipShape(RoundedRectangle(cornerRadius: Tema.Radio.bloqueInterno))
        }
        .onAppear { campoEnfocado = true }
    }

    /// RF-03. No es una pantalla de error: es la misma pantalla, en otro estado, con el
    /// teclado ya abierto.
    private var sinNumero: some View {
        mensajeYCampo("No alcancé a leer el número. Puedes escribirlo tú.")
    }

    /// Negar el permiso tampoco es un error. Se dice en una línea y se sigue.
    private var camaraNegada: some View {
        mensajeYCampo("Sin permiso de cámara no puedo leer la pantalla. "
            + "Escribe el número y listo.")
    }

    private func mensajeYCampo(_ mensaje: String) -> some View {
        VStack(alignment: .leading, spacing: Tema.Espacio.interior) {
            Text(mensaje)
                .font(Tema.Tipografia.textoLectura)
                .foregroundStyle(Tema.Colores.textoPrincipal)
                .fixedSize(horizontal: false, vertical: true)
            campoDeCorreccion
        }
    }

    private var botones: some View {
        VStack(spacing: Tema.Espacio.unidad * 2) {
            switch modelo.estadoFoto {
            case .leido where !corrigiendo:
                Button {
                    modelo.llevarAlRegistro(valor: modelo.textoCorreccion)
                } label: {
                    etiquetaPrincipal("Sí, es correcto")
                }
                .accessibilityIdentifier("botonConfirmarOcr")

                Button("Corregir") { corrigiendo = true }
                    .font(Tema.Tipografia.tituloTarjeta)
                    .foregroundStyle(Tema.Colores.azulPrimario)
                    .frame(maxWidth: .infinity, minHeight: Tema.Medida.areaTocable)
                    .accessibilityIdentifier("botonCorregirOcr")

            case .leido, .sinNumero, .camaraNegada:
                Button {
                    modelo.llevarAlRegistro(valor: modelo.textoCorreccion)
                } label: {
                    etiquetaPrincipal("Usar este valor")
                }
                .accessibilityIdentifier("botonUsarValorOcr")

            case .procesando, .ninguno:
                EmptyView()
            }
        }
        .padding(.horizontal, Tema.Espacio.margenLateral)
        .padding(.vertical, Tema.Espacio.unidad * 2)
        .background(Tema.Colores.fondo)
    }

    private func etiquetaPrincipal(_ texto: String) -> some View {
        ZStack {
            if modelo.guardando {
                ProgressView().tint(Tema.Colores.superficie)
            } else {
                Text(texto).font(Tema.Tipografia.tituloTarjeta)
            }
        }
        .frame(maxWidth: .infinity, minHeight: Tema.Medida.botonPrincipal)
        .foregroundStyle(Tema.Colores.superficie)
        .background(Tema.Colores.azulPrimario)
        .clipShape(RoundedRectangle(cornerRadius: Tema.Radio.campo))
    }

    private func textoDelValor(_ valor: Double) -> String {
        valor == valor.rounded() ? String(Int(valor)) : String(valor)
    }
}
