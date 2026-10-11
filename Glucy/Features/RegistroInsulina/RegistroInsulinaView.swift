import SwiftUI

/// Registro de insulina. No está en los mockups: copia la forma de la pantalla 4.
///
/// La vista **no valida, no calcula y no toca la base**. Y no enseña ninguna frase que diga
/// cuánto aplicarse: anota lo que la persona dice haberse aplicado (regla 7).
struct RegistroInsulinaView: View {
    @State private var modelo: RegistroInsulinaViewModel
    @FocusState private var campoEnfocado: Bool

    /// La pestaña «Registrar» mantiene montadas todas sus pantallas y oculta las que no
    /// tocan, así que `onAppear` no dice cuándo se está viendo esta.
    private let visible: Bool

    @ScaledMetric private var tamanoCifra: CGFloat = Tema.Tipografia.tamanoCifraGlucosa
    @Environment(\.dynamicTypeSize) private var tamanoLetra

    init(
        registrar: RegistrarDosis,
        calcular: CalcularInsulinaActiva,
        ajustes: ConsultarAjustesDeInsulina,
        visible: Bool = true
    ) {
        self.visible = visible
        _modelo = State(initialValue: RegistroInsulinaViewModel(
            registrar: registrar, calcular: calcular, ajustes: ajustes
        ))
    }

    var body: some View {
        // Sin `NavigationStack`: esta pantalla no navega a ninguna otra, y su barra quedaría
        // debajo del selector de «Registrar», empujando el aviso a esconderse tras él.
        ScrollView {
            VStack(alignment: .leading, spacing: Tema.Espacio.entreTarjetas) {
                // Con la letra de accesibilidad el aviso ocupa media pantalla: fijo
                // arriba no dejaría sitio para el campo, y recortarlo no es opción. Ahí
                // va primero dentro del desplazamiento, entero (P-15).
                if tamanoLetra.isAccessibilitySize { avisoDeLaFrontera }
                tarjetaDeUnidades
                tipoDeInsulina
                fechaYHora
                motivo
                insulinaActiva
            }
            .padding(.horizontal, Tema.Espacio.margenLateral)
            .padding(.bottom, Tema.Espacio.margenLateral)
            .onTapGesture { campoEnfocado = false }
        }
        // Fijo arriba del formulario, fuera del desplazamiento: no se va al bajar y no
        // tiene forma de cerrarse.
        .safeAreaInset(edge: .top, spacing: 0) {
            if !tamanoLetra.isAccessibilitySize {
                avisoDeLaFrontera
                    .padding(.horizontal, Tema.Espacio.margenLateral)
                    .padding(.vertical, Tema.Espacio.unidad * 2)
                    .background(Tema.Colores.fondo)
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: Tema.Espacio.unidad * 2) {
                if modelo.ultimaGuardada != nil { franjaGuardada }

                HStack(spacing: Tema.Espacio.unidad * 2) {
                    botonGuardar

                    if campoEnfocado {
                        Button {
                            campoEnfocado = false
                        } label: {
                            Image(systemName: "keyboard.chevron.compact.down")
                                .font(.title2)
                                .frame(width: Tema.Medida.botonPrincipal,
                                       height: Tema.Medida.botonPrincipal)
                                .foregroundStyle(Tema.Colores.azulPrimario)
                                .background(Tema.Colores.superficie)
                                .clipShape(RoundedRectangle(cornerRadius: Tema.Radio.campo))
                        }
                        .accessibilityLabel("Cerrar teclado")
                        .accessibilityIdentifier("botonCerrarTecladoInsulina")
                    }
                }
            }
            .padding(.horizontal, Tema.Espacio.margenLateral)
            .padding(.vertical, Tema.Espacio.unidad * 2)
            .background(Tema.Colores.fondo)
        }
        .background(Tema.Colores.fondo)
        .accessibilityHidden(!visible)
        .onChange(of: visible) { _, seVe in
            if !seVe { campoEnfocado = false }
        }
        // La insulina que queda baja sola con el tiempo: mientras la pantalla se ve, la
        // cifra y la hora propuesta se refrescan cada minuto.
        .task(id: visible) {
            guard visible else { return }
            while !Task.isCancelled {
                await modelo.ponerAlDia()
                try? await Task.sleep(for: .seconds(60))
            }
        }
        .onChange(of: modelo.fallo) { _, nuevo in
            guard let nuevo else { return }
            // El rechazo se anuncia solo: quien usa VoiceOver no ve el texto rojo aparecer.
            AccessibilityNotification.Announcement(nuevo.mensaje).post()
        }
    }

    // MARK: - Partes

    /// El texto que marca la frontera con un dispositivo médico regulado (regla 7).
    ///
    /// No tiene «entendido», no tiene equis y no se encoge al segundo uso. El ámbar va solo
    /// en el borde y en el icono; lo que informa son el icono y las palabras, así que en
    /// escala de grises se lee igual.
    private var avisoDeLaFrontera: some View {
        HStack(alignment: .top, spacing: Tema.Espacio.unidad * 3) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.title3)
                .foregroundStyle(Tema.Colores.alertaAmbar)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Tema.Espacio.unidad) {
                Text("Glucy solo anota lo que tú te aplicaste.")
                    .font(Tema.Tipografia.valorFila)
                    .foregroundStyle(Tema.Colores.textoPrincipal)
                Text("No calcula ni sugiere dosis. Esa decisión es tuya y de tu médico.")
                    .font(Tema.Tipografia.etiqueta)
                    .foregroundStyle(Tema.Colores.textoPrincipal)
            }
            // Crece hacia abajo todo lo que haga falta: un aviso cortado a la mitad puede
            // acabar diciendo lo contrario de lo que dice.
            .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(Tema.Espacio.interior)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tema.Colores.superficie)
        .clipShape(RoundedRectangle(cornerRadius: Tema.Radio.bloqueInterno))
        .overlay(
            RoundedRectangle(cornerRadius: Tema.Radio.bloqueInterno)
                .stroke(Tema.Colores.alertaAmbar, lineWidth: 2)
        )
        .accessibilityElement(children: .combine)
        // VoiceOver lo lee antes que el campo de unidades: quien no ve la pantalla tiene que
        // oír la advertencia antes de escribir el número.
        .accessibilitySortPriority(1)
        .accessibilityIdentifier("avisoDeLaFrontera")
    }

    private var tarjetaDeUnidades: some View {
        VStack(alignment: .leading, spacing: Tema.Espacio.unidad * 2) {
            Text("¿Cuántas unidades te aplicaste?")
                .font(Tema.Tipografia.tituloTarjeta)
                .foregroundStyle(Tema.Colores.textoPrincipal)
                .fixedSize(horizontal: false, vertical: true)

            // Con la letra de accesibilidad la cifra y los dos botones no caben en un
            // renglón: los botones bajan (P-15).
            if tamanoLetra.isAccessibilitySize {
                campoDeUnidades
                HStack(spacing: Tema.Espacio.unidad * 2) {
                    botonDeMediaUnidad(haciaArriba: false)
                    botonDeMediaUnidad(haciaArriba: true)
                }
            } else {
                HStack(spacing: Tema.Espacio.unidad * 2) {
                    botonDeMediaUnidad(haciaArriba: false)
                    campoDeUnidades
                    botonDeMediaUnidad(haciaArriba: true)
                }
            }

            if let fallo = modelo.fallo {
                // Pegado al campo y con icono: el color nunca es el único portador de
                // información.
                Label {
                    Text(fallo.mensaje)
                        .font(Tema.Tipografia.etiqueta)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                }
                .foregroundStyle(Tema.Colores.hipoglucemia)
                .accessibilityIdentifier("falloDeInsulina")
            }
        }
        .padding(Tema.Espacio.interior)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tema.Colores.superficie)
        .clipShape(RoundedRectangle(cornerRadius: Tema.Radio.tarjetaGrande))
    }

    private var campoDeUnidades: some View {
        HStack(alignment: .firstTextBaseline, spacing: Tema.Espacio.unidad * 2) {
            TextField("", text: $modelo.textoUnidades)
                .font(.system(size: tamanoCifra, weight: .bold))
                .foregroundStyle(Tema.Colores.azulProfundo)
                .multilineTextAlignment(.trailing)
                .keyboardType(.decimalPad)
                .focused($campoEnfocado)
                .overlay(alignment: .trailing) {
                    if modelo.textoUnidades.isEmpty {
                        Text("0")
                            .font(.system(size: tamanoCifra, weight: .bold))
                            .foregroundStyle(Tema.Colores.azulProfundo.opacity(0.3))
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                }
                .accessibilityLabel("Unidades de insulina que te aplicaste")
                .accessibilityIdentifier("campoUnidades")

            Text("UI")
                .font(Tema.Tipografia.textoLectura)
                .foregroundStyle(Tema.Colores.textoSecundario)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity)
    }

    private func botonDeMediaUnidad(haciaArriba: Bool) -> some View {
        Button {
            modelo.moverMediaUnidad(haciaArriba: haciaArriba)
        } label: {
            Image(systemName: haciaArriba ? "plus" : "minus")
                .font(.title2.weight(.semibold))
                .frame(maxWidth: tamanoLetra.isAccessibilitySize ? .infinity : Tema.Medida.botonPrincipal)
                .frame(minWidth: Tema.Medida.botonPrincipal, minHeight: Tema.Medida.botonPrincipal)
                .foregroundStyle(Tema.Colores.azulPrimario)
                .background(Tema.Colores.azulClaro)
                .clipShape(RoundedRectangle(cornerRadius: Tema.Radio.campo))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(haciaArriba ? "Media unidad más" : "Media unidad menos")
        .accessibilityIdentifier(haciaArriba ? "botonMasMediaUnidad" : "botonMenosMediaUnidad")
    }

    private var tipoDeInsulina: some View {
        VStack(alignment: .leading, spacing: Tema.Espacio.unidad * 2) {
            // Dos opciones del mismo tamaño. Con la letra de accesibilidad se apilan en
            // lugar de cortarse (P-15).
            let disposicion = tamanoLetra.isAccessibilitySize
                ? AnyLayout(VStackLayout(spacing: Tema.Espacio.unidad * 2))
                : AnyLayout(HStackLayout(spacing: Tema.Espacio.unidad * 2))
            disposicion {
                ForEach(TipoInsulina.allCases, id: \.self) { opcion in
                    OpcionDeTipo(
                        opcion: opcion,
                        elegida: modelo.tipo == opcion,
                        alTocar: {
                            modelo.tipo = opcion
                            campoEnfocado = false
                        }
                    )
                }
            }
        }
        .padding(Tema.Espacio.interior)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tema.Colores.superficie)
        .clipShape(RoundedRectangle(cornerRadius: Tema.Radio.tarjetaGrande))
    }

    private var fechaYHora: some View {
        VStack(alignment: .leading, spacing: Tema.Espacio.unidad * 2) {
            Text("Cuándo")
                .font(Tema.Tipografia.tituloTarjeta)
                .foregroundStyle(Tema.Colores.textoPrincipal)

            DatePicker(
                "Fecha y hora de la dosis",
                selection: .init(get: { modelo.fecha }, set: { modelo.elegir(fecha: $0) }),
                displayedComponents: [.date, .hourAndMinute]
            )
            .labelsHidden()
            .datePickerStyle(.compact)
            .tint(Tema.Colores.azulPrimario)
            .accessibilityLabel("Fecha y hora de la dosis")
        }
        .padding(Tema.Espacio.interior)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tema.Colores.superficie)
        .clipShape(RoundedRectangle(cornerRadius: Tema.Radio.tarjetaGrande))
    }

    private var motivo: some View {
        VStack(alignment: .leading, spacing: Tema.Espacio.unidad * 2) {
            Text("¿Por qué?")
                .font(Tema.Tipografia.tituloTarjeta)
                .foregroundStyle(Tema.Colores.textoPrincipal)
            Text("Puedes dejarlo en blanco")
                .font(Tema.Tipografia.etiqueta)
                .foregroundStyle(Tema.Colores.textoSecundario)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 140), spacing: Tema.Espacio.unidad * 2)],
                alignment: .leading,
                spacing: Tema.Espacio.unidad * 2
            ) {
                ForEach(MotivoDosis.allCases, id: \.self) { opcion in
                    ChipDeMotivo(
                        opcion: opcion,
                        elegido: modelo.motivo == opcion,
                        alTocar: {
                            // Tocar el elegido lo quita: el motivo se puede dejar en blanco
                            // también después de haber tocado uno.
                            modelo.motivo = modelo.motivo == opcion ? nil : opcion
                            campoEnfocado = false
                        }
                    )
                }
            }
        }
        .padding(Tema.Espacio.interior)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tema.Colores.superficie)
        .clipShape(RoundedRectangle(cornerRadius: Tema.Radio.tarjetaGrande))
    }

    /// Una cifra con su unidad y su hora. No lleva color de estado ni va seguida de nada.
    @ViewBuilder
    private var insulinaActiva: some View {
        if let texto = modelo.textoInsulinaActiva {
            Label {
                Text(texto)
                    .font(Tema.Tipografia.textoLectura)
                    .foregroundStyle(Tema.Colores.textoPrincipal)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "clock")
                    .foregroundStyle(Tema.Colores.textoSecundario)
            }
            .padding(Tema.Espacio.interior)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Tema.Colores.superficie)
            .clipShape(RoundedRectangle(cornerRadius: Tema.Radio.tarjetaGrande))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(modelo.textoInsulinaActivaHablado ?? texto)
            .accessibilityIdentifier("insulinaActiva")
        }
    }

    private var botonGuardar: some View {
        Button {
            Task {
                await modelo.guardar()
                campoEnfocado = false
            }
        } label: {
            ZStack {
                if modelo.guardando {
                    ProgressView().tint(Tema.Colores.textoSobreColor)
                } else {
                    Text("Guardar").font(Tema.Tipografia.tituloTarjeta)
                }
            }
            .frame(maxWidth: .infinity, minHeight: Tema.Medida.botonPrincipal)
            .foregroundStyle(Tema.Colores.textoSobreColor)
            .background(modelo.sePuedeGuardar ? Tema.Colores.azulPrimario : Tema.Colores.textoSecundario)
            .clipShape(RoundedRectangle(cornerRadius: Tema.Radio.campo))
        }
        .disabled(!modelo.sePuedeGuardar)
        .accessibilityIdentifier("botonGuardarDosis")
    }

    /// Franja breve con «Deshacer», que además quita la muestra de Salud.
    private var franjaGuardada: some View {
        // Con la letra de accesibilidad los dos textos no caben lado a lado sin partirse a
        // media palabra: «Deshacer» baja a su propio renglón (P-15).
        let disposicion = tamanoLetra.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: Tema.Espacio.unidad))
            : AnyLayout(HStackLayout())
        return disposicion {
            Label("Dosis guardada", systemImage: "checkmark.circle.fill")
                .font(Tema.Tipografia.valorFila)
                .foregroundStyle(Tema.Colores.textoSobreColor)
            if !tamanoLetra.isAccessibilitySize { Spacer() }
            Button("Deshacer") { Task { await modelo.deshacer() } }
                .font(Tema.Tipografia.valorFila)
                .foregroundStyle(Tema.Colores.textoSobreColor)
                .frame(minHeight: Tema.Medida.areaTocable)
                .accessibilityIdentifier("botonDeshacerDosis")
        }
        .padding(.horizontal, Tema.Espacio.interior)
        .frame(minHeight: Tema.Medida.areaTocable)
        .background(Tema.Colores.enRango)
        .clipShape(RoundedRectangle(cornerRadius: Tema.Radio.campo))
        // Sin identificador en la franja: puesto sobre un contenedor baja a sus hijos y le
        // pisa el suyo a «Deshacer».
        .task(id: modelo.ultimaGuardada?.uuid) {
            // La franja se va sola a los cinco segundos; la dosis ya está guardada.
            try? await Task.sleep(for: .seconds(5))
            modelo.olvidarConfirmacion()
        }
    }
}

// MARK: - Piezas de la pantalla

/// Una de las dos insulinas. La elegida no se distingue solo por el color: cambia el
/// símbolo, el borde se engruesa y lleva el rasgo de «seleccionado».
private struct OpcionDeTipo: View {
    let opcion: TipoInsulina
    let elegida: Bool
    let alTocar: () -> Void

    var body: some View {
        Button(action: alTocar) {
            VStack(alignment: .leading, spacing: Tema.Espacio.unidad) {
                HStack(spacing: Tema.Espacio.unidad * 2) {
                    Image(systemName: elegida ? "largecircle.fill.circle" : "circle")
                        .foregroundStyle(elegida ? Tema.Colores.azulPrimario : Tema.Colores.textoSecundario)
                    Text(opcion.nombreEnPantalla)
                        .font(Tema.Tipografia.tituloTarjeta)
                        .foregroundStyle(Tema.Colores.textoPrincipal)
                }
                // Sobre el azul claro el gris secundario no llega a 4.5:1, así que en la
                // elegida la descripción va en el color principal.
                Text(opcion.descripcionEnPantalla)
                    .font(Tema.Tipografia.etiqueta)
                    .foregroundStyle(elegida ? Tema.Colores.textoPrincipal : Tema.Colores.textoSecundario)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(Tema.Espacio.interior)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(elegida ? Tema.Colores.azulClaro : Tema.Colores.fondo)
            .clipShape(RoundedRectangle(cornerRadius: Tema.Radio.bloqueInterno))
            .overlay(
                RoundedRectangle(cornerRadius: Tema.Radio.bloqueInterno).stroke(
                    elegida ? Tema.Colores.azulPrimario : Tema.Colores.textoSecundario.opacity(0.4),
                    lineWidth: elegida ? 2 : 1
                )
            )
            .contentShape(RoundedRectangle(cornerRadius: Tema.Radio.bloqueInterno))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(elegida ? [.isSelected] : [])
        .accessibilityIdentifier(opcion.identificador)
    }
}

/// Uno de los tres motivos de `MotivoDosis`.
private struct ChipDeMotivo: View {
    let opcion: MotivoDosis
    let elegido: Bool
    let alTocar: () -> Void

    var body: some View {
        Button(action: alTocar) {
            Text(opcion.nombreEnPantalla)
                .font(Tema.Tipografia.etiqueta)
                .foregroundStyle(elegido ? Tema.Colores.azulPrimario : Tema.Colores.textoPrincipal)
                .padding(.horizontal, Tema.Espacio.interior)
                .frame(minHeight: Tema.Medida.chip)
                .frame(maxWidth: .infinity)
                .background(elegido ? Tema.Colores.azulClaro : Tema.Colores.fondo)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(
                        elegido ? Tema.Colores.azulPrimario : Tema.Colores.textoSecundario.opacity(0.4),
                        lineWidth: elegido ? 2 : 1
                    )
                )
        }
        // El área tocable es de 44 aunque el chip mida 36.
        .frame(minHeight: Tema.Medida.areaTocable)
        .accessibilityAddTraits(elegido ? [.isSelected] : [])
        .accessibilityIdentifier(opcion.identificador)
    }
}

extension TipoInsulina {
    /// En el modelo es `bolo`; «bolo» no es una palabra que use la gente (C-4).
    var nombreEnPantalla: String {
        switch self {
        case .bolo: "Rápida"
        case .basal: "Basal"
        }
    }

    var descripcionEnPantalla: String {
        switch self {
        case .bolo: "la de las comidas (bolo)"
        case .basal: "la de todos los días (lenta)"
        }
    }

    var identificador: String {
        switch self {
        case .bolo: "tipoRapida"
        case .basal: "tipoBasal"
        }
    }
}

extension MotivoDosis {
    var nombreEnPantalla: String {
        switch self {
        case .comida: "Por una comida"
        case .correccion: "Para corregir"
        case .programada: "Es la de siempre"
        }
    }

    var identificador: String {
        switch self {
        case .comida: "motivoComida"
        case .correccion: "motivoCorreccion"
        case .programada: "motivoProgramada"
        }
    }
}
