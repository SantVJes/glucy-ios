import SwiftUI
import UIKit

/// Pantalla 5 — registro de comida, por sus tres vías.
///
/// Las tres terminan en el mismo sitio: el número de carbohidratos a la vista, esperando que
/// la persona toque «Guardar». Ninguna deja un callejón sin salida (caso P-10).
struct RegistroComidaView: View {
    enum Campo: Hashable { case carbs, carbsPor100g, porcionG, porciones, codigo }

    @State private var modelo: RegistroComidaViewModel
    @FocusState private var campoEnfocado: Campo?

    @ScaledMetric private var tamanoCifra: CGFloat = Tema.Tipografia.tamanoCifraGlucosa

    init(registrar: RegistrarComida, buscar: BuscarProductoPorCodigo, ocr: any ServicioOCR) {
        _modelo = State(initialValue: RegistroComidaViewModel(
            registrar: registrar, buscar: buscar, ocr: ocr
        ))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Tema.Espacio.entreTarjetas) {
                    encabezado
                    vias
                    if let aviso = modelo.aviso { tarjetaDeAviso(aviso) }
                    if modelo.leyendoEtiqueta { leyendo }

                    if modelo.via == .manual {
                        tarjetaDeGramos
                    } else {
                        ConfirmarProductoView(modelo: modelo, campoEnfocado: $campoEnfocado)
                    }

                    mensajeDeFallo
                    fechaYHora
                    absorcion
                }
                .padding(.horizontal, Tema.Espacio.margenLateral)
                .padding(.bottom, Tema.Espacio.margenLateral)
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) { barraInferior }
            .background(Tema.Colores.fondo)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Registrar")
                        .font(.headline)
                        .foregroundStyle(Tema.Colores.textoPrincipal)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear { modelo.ponerLaHoraDeAhora() }
        .onChange(of: modelo.fallo) { _, nuevo in
            guard let nuevo else { return }
            AccessibilityNotification.Announcement(nuevo.mensaje).post()
        }
        .onChange(of: modelo.aviso) { _, nuevo in
            guard let nuevo else { return }
            AccessibilityNotification.Announcement(nuevo).post()
            // Cuando la etiqueta tampoco se leyó, el teclado se abre solo sobre el campo de
            // gramos: es el último escalón y no debe costar un gesto más.
            if !modelo.ofreceFotoDeEtiqueta { campoEnfocado = .carbs }
        }
        .onChange(of: modelo.via) { _, nueva in
            // Lo único que falta casi siempre es la porción: el teclado va ahí.
            if nueva != .manual, modelo.faltaLaPorcion { campoEnfocado = .porcionG }
        }
        .fullScreenCover(isPresented: $modelo.mostrandoEscaner) {
            HojaEscaner(modelo: modelo)
        }
        .fullScreenCover(isPresented: $modelo.mostrandoCamara) {
            CapturaFotoView(
                alCapturar: { datos in
                    modelo.mostrandoCamara = false
                    // La imagen se procesa y se suelta. No se guarda en ningún lado (regla 6).
                    Task { await modelo.procesar(etiqueta: datos) }
                },
                alCancelar: { modelo.mostrandoCamara = false }
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - Partes

    private var encabezado: some View {
        VStack(alignment: .leading, spacing: Tema.Espacio.unidad) {
            Text("Registrar comida")
                .font(Tema.Tipografia.tituloPantalla)
                .foregroundStyle(Tema.Colores.textoPrincipal)
            Text("Elige cómo quieres anotar los carbohidratos")
                .font(Tema.Tipografia.etiqueta)
                .foregroundStyle(Tema.Colores.textoSecundario)
        }
        .padding(.top, Tema.Espacio.interior)
    }

    private var vias: some View {
        VStack(spacing: Tema.Espacio.unidad * 2) {
            ViaComida(
                titulo: "Escanear código de barras",
                descripcion: "Busco el producto y sus carbohidratos",
                icono: "barcode.viewfinder",
                activa: { if case .producto = modelo.via { true } else { false } }()
            ) {
                campoEnfocado = nil
                modelo.abrirEscaner()
            }
            .accessibilityIdentifier("viaCodigoDeBarras")

            ViaComida(
                titulo: "Foto de la etiqueta",
                descripcion: "Le tomas una foto a la tabla nutrimental y leo los carbohidratos",
                icono: "camera",
                activa: modelo.via == .etiqueta
            ) {
                abrirCamara()
            }
            .accessibilityIdentifier("viaFotoEtiqueta")

            ViaComida(
                titulo: "A mano",
                descripcion: "Escribes los gramos de carbohidratos",
                icono: "keyboard",
                activa: modelo.via == .manual
            ) {
                modelo.escribirAMano()
                campoEnfocado = .carbs
            }
            .accessibilityIdentifier("viaManual")
        }
    }

    /// Por qué se bajó de escalón, en una línea, y el siguiente escalón ahí mismo.
    private func tarjetaDeAviso(_ aviso: String) -> some View {
        VStack(alignment: .leading, spacing: Tema.Espacio.unidad * 2) {
            Label {
                Text(aviso)
                    .font(Tema.Tipografia.textoLectura)
                    .foregroundStyle(Tema.Colores.textoPrincipal)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(Tema.Colores.alertaAmbar)
            }

            if modelo.ofreceFotoDeEtiqueta {
                Button {
                    abrirCamara()
                } label: {
                    Label("Tomar foto de la etiqueta", systemImage: "camera")
                        .font(Tema.Tipografia.tituloTarjeta)
                        .frame(maxWidth: .infinity, minHeight: Tema.Medida.botonPrincipal)
                        .foregroundStyle(Tema.Colores.superficie)
                        .background(Tema.Colores.azulPrimario)
                        .clipShape(RoundedRectangle(cornerRadius: Tema.Radio.campo))
                }
                .accessibilityIdentifier("botonFotoDeEtiqueta")
            }
        }
        .padding(Tema.Espacio.interior)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tema.Colores.superficie)
        .clipShape(RoundedRectangle(cornerRadius: Tema.Radio.bloqueInterno))
        .overlay(
            RoundedRectangle(cornerRadius: Tema.Radio.bloqueInterno)
                .stroke(Tema.Colores.alertaAmbar, lineWidth: 2)
        )
        .accessibilityIdentifier("avisoComida")
    }

    private var leyendo: some View {
        HStack(spacing: Tema.Espacio.interior) {
            ProgressView()
            Text("Leyendo la etiqueta…")
                .font(Tema.Tipografia.textoLectura)
                .foregroundStyle(Tema.Colores.textoSecundario)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var tarjetaDeGramos: some View {
        VStack(alignment: .leading, spacing: Tema.Espacio.unidad * 2) {
            Text("Carbohidratos")
                .font(Tema.Tipografia.tituloTarjeta)
                .foregroundStyle(Tema.Colores.textoPrincipal)

            HStack(alignment: .firstTextBaseline, spacing: Tema.Espacio.unidad * 2) {
                TextField("", text: $modelo.textoCarbs)
                    .font(.system(size: tamanoCifra, weight: .bold))
                    .foregroundStyle(Tema.Colores.azulProfundo)
                    .keyboardType(.decimalPad)
                    .focused($campoEnfocado, equals: .carbs)
                    .accessibilityLabel("Gramos de carbohidratos")
                    .accessibilityIdentifier("campoCarbohidratos")

                Text("g")
                    .font(Tema.Tipografia.textoLectura)
                    .foregroundStyle(Tema.Colores.textoSecundario)
                    .accessibilityHidden(true)
            }
        }
        .padding(Tema.Espacio.interior)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tema.Colores.superficie)
        .clipShape(RoundedRectangle(cornerRadius: Tema.Radio.tarjetaGrande))
    }

    @ViewBuilder
    private var mensajeDeFallo: some View {
        if let fallo = modelo.fallo {
            Label {
                Text(fallo.mensaje)
                    .font(Tema.Tipografia.etiqueta)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
            }
            .foregroundStyle(Tema.Colores.hipoglucemia)
            .accessibilityIdentifier("falloComida")
        }
    }

    private var fechaYHora: some View {
        VStack(alignment: .leading, spacing: Tema.Espacio.unidad * 2) {
            Text("Cuándo")
                .font(Tema.Tipografia.tituloTarjeta)
                .foregroundStyle(Tema.Colores.textoPrincipal)

            DatePicker(
                "Fecha y hora de la comida",
                selection: Binding(
                    get: { modelo.fecha },
                    set: { modelo.elegir(fecha: $0) }
                ),
                displayedComponents: [.date, .hourAndMinute]
            )
            .labelsHidden()
            .datePickerStyle(.compact)
            .environment(\.colorScheme, .light)
            .accessibilityLabel("Fecha y hora de la comida")
        }
        .padding(Tema.Espacio.interior)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tema.Colores.superficie)
        .clipShape(RoundedRectangle(cornerRadius: Tema.Radio.tarjetaGrande))
    }

    /// RF-12b: el tiempo de absorción **no se pregunta**. Son 180 minutos, dichos en un
    /// renglón, y los tres chips viven detrás de «Ajustar». Quien no toca nada no ve una
    /// decisión que tomar.
    private var absorcion: some View {
        VStack(alignment: .leading, spacing: Tema.Espacio.unidad * 2) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Tema.Espacio.unidad * 2) {
                    renglonDeAbsorcion
                    Spacer(minLength: 0)
                    botonAjustar
                }
                // Con la letra de accesibilidad más grande el botón baja de renglón en vez
                // de cortar el texto (P-15).
                VStack(alignment: .leading, spacing: 0) {
                    renglonDeAbsorcion
                    botonAjustar
                }
            }

            Text(
                (modelo.absorcion == .normal ? "Si no lo cambias, Glucy" : "Glucy")
                    + " cuenta estos carbohidratos repartidos en "
                    + RegistroComidaViewModel.duracion(minutos: modelo.absorcion.minutos) + "."
            )
            .font(Tema.Tipografia.etiqueta)
            .foregroundStyle(Tema.Colores.textoSecundario)
            .fixedSize(horizontal: false, vertical: true)

            if modelo.ajustandoAbsorcion {
                VStack(spacing: Tema.Espacio.unidad * 2) {
                    ForEach(OpcionAbsorcion.allCases, id: \.self) { opcion in
                        ChipAbsorcion(
                            opcion: opcion,
                            elegida: modelo.absorcion == opcion,
                            alTocar: { modelo.absorcion = opcion }
                        )
                    }
                }
            }
        }
        .padding(Tema.Espacio.interior)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tema.Colores.superficie)
        .clipShape(RoundedRectangle(cornerRadius: Tema.Radio.tarjetaGrande))
    }

    private var renglonDeAbsorcion: some View {
        Text(
            "Absorción: \(modelo.absorcion.nombre), "
                + RegistroComidaViewModel.duracion(minutos: modelo.absorcion.minutos)
        )
        .font(Tema.Tipografia.valorFila)
        .foregroundStyle(Tema.Colores.textoPrincipal)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityIdentifier("renglonAbsorcion")
    }

    private var botonAjustar: some View {
        Button(modelo.ajustandoAbsorcion ? "Listo" : "Ajustar") {
            campoEnfocado = nil
            modelo.ajustandoAbsorcion.toggle()
        }
        .font(Tema.Tipografia.valorFila)
        .foregroundStyle(Tema.Colores.azulPrimario)
        .frame(minHeight: Tema.Medida.areaTocable)
        .accessibilityIdentifier("botonAjustarAbsorcion")
    }

    private var barraInferior: some View {
        VStack(spacing: Tema.Espacio.unidad * 2) {
            if modelo.ultimaGuardada != nil { franjaGuardada }

            HStack(spacing: Tema.Espacio.unidad * 2) {
                Button {
                    Task {
                        await modelo.guardar()
                        if modelo.fallo == nil { campoEnfocado = nil }
                    }
                } label: {
                    ZStack {
                        if modelo.guardando {
                            ProgressView().tint(Tema.Colores.superficie)
                        } else {
                            Text("Guardar").font(Tema.Tipografia.tituloTarjeta)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: Tema.Medida.botonPrincipal)
                    .foregroundStyle(Tema.Colores.superficie)
                    .background(
                        modelo.sePuedeGuardar
                            ? Tema.Colores.azulPrimario : Tema.Colores.textoSecundario
                    )
                    .clipShape(RoundedRectangle(cornerRadius: Tema.Radio.campo))
                }
                // Sin los gramos de la porción el botón no guarda: lo que falta se pregunta
                // en el momento y nunca se rellena con 100 g (RF-37).
                .disabled(!modelo.sePuedeGuardar)
                .accessibilityIdentifier("botonGuardarComida")

                if campoEnfocado != nil {
                    Button {
                        campoEnfocado = nil
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
                }
            }
        }
        .padding(.horizontal, Tema.Espacio.margenLateral)
        .padding(.vertical, Tema.Espacio.unidad * 2)
        .background(Tema.Colores.fondo)
    }

    private var franjaGuardada: some View {
        HStack {
            Label("Comida guardada", systemImage: "checkmark.circle.fill")
                .font(Tema.Tipografia.valorFila)
                .foregroundStyle(Tema.Colores.superficie)
            Spacer()
            Button("Deshacer") { Task { await modelo.deshacer() } }
                .font(Tema.Tipografia.valorFila)
                .foregroundStyle(Tema.Colores.superficie)
                .accessibilityIdentifier("botonDeshacerComida")
        }
        .padding(.horizontal, Tema.Espacio.interior)
        .frame(minHeight: Tema.Medida.areaTocable)
        .background(Tema.Colores.enRango)
        .clipShape(RoundedRectangle(cornerRadius: Tema.Radio.campo))
        .accessibilityIdentifier("franjaComidaGuardada")
        .task(id: modelo.ultimaGuardada?.uuid) {
            try? await Task.sleep(for: .seconds(5))
            modelo.olvidarConfirmacion()
        }
    }

    /// El simulador no tiene cámara, y pedírsela a `UIImagePickerController` tumba la app.
    private func abrirCamara() {
        campoEnfocado = nil
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            modelo.mostrandoCamara = true
        } else {
            modelo.sinCamaraParaLaEtiqueta()
        }
    }
}

// MARK: - Piezas de la pantalla

/// Una de las tres vías. Aquí sí son botones: cada una hace algo distinto al tocarla.
private struct ViaComida: View {
    let titulo: String
    let descripcion: String
    let icono: String
    let activa: Bool
    let alTocar: () -> Void

    var body: some View {
        Button(action: alTocar) {
            HStack(spacing: Tema.Espacio.interior) {
                Image(systemName: icono)
                    .font(.title3)
                    .foregroundStyle(Tema.Colores.azulPrimario)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: Tema.Espacio.unidad / 2) {
                    Text(titulo)
                        .font(Tema.Tipografia.tituloTarjeta)
                        .foregroundStyle(Tema.Colores.textoPrincipal)
                    Text(descripcion)
                        .font(Tema.Tipografia.etiqueta)
                        .foregroundStyle(Tema.Colores.textoSecundario)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: 0)

                // La vía en curso se marca con una palomita además del color.
                if activa {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Tema.Colores.azulPrimario)
                        .accessibilityHidden(true)
                }
            }
            .padding(Tema.Espacio.interior)
            .frame(maxWidth: .infinity, minHeight: Tema.Medida.areaTocable, alignment: .leading)
            .background(activa ? Tema.Colores.azulClaro : Tema.Colores.superficie)
            .clipShape(RoundedRectangle(cornerRadius: Tema.Radio.bloqueInterno))
            .overlay(
                RoundedRectangle(cornerRadius: Tema.Radio.bloqueInterno)
                    .stroke(activa ? Tema.Colores.azulPrimario : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(activa ? [.isSelected] : [])
    }
}

/// Una de las tres velocidades de absorción. Son las de `OpcionAbsorcion`: no hay cuarta.
private struct ChipAbsorcion: View {
    let opcion: OpcionAbsorcion
    let elegida: Bool
    let alTocar: () -> Void

    var body: some View {
        Button(action: alTocar) {
            HStack(spacing: Tema.Espacio.interior) {
                Image(systemName: elegida ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(
                        elegida ? Tema.Colores.azulPrimario : Tema.Colores.textoSecundario
                    )
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: Tema.Espacio.unidad / 2) {
                    Text(opcion.titulo)
                        .font(Tema.Tipografia.valorFila)
                        .foregroundStyle(Tema.Colores.textoPrincipal)
                    Text(opcion.apoyo)
                        .font(Tema.Tipografia.etiqueta)
                        .foregroundStyle(Tema.Colores.textoSecundario)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(Tema.Espacio.interior)
            .frame(maxWidth: .infinity, minHeight: Tema.Medida.areaTocable, alignment: .leading)
            .background(elegida ? Tema.Colores.azulClaro : Tema.Colores.fondo)
            .clipShape(RoundedRectangle(cornerRadius: Tema.Radio.bloqueInterno))
            .overlay(
                RoundedRectangle(cornerRadius: Tema.Radio.bloqueInterno)
                    .stroke(elegida ? Tema.Colores.azulPrimario : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            "\(opcion.titulo), \(RegistroComidaViewModel.duracion(minutos: opcion.minutos)). \(opcion.apoyo)"
        )
        .accessibilityAddTraits(elegida ? [.isSelected] : [])
        .accessibilityIdentifier("chipAbsorcion-\(opcion.minutos)")
    }
}

extension OpcionAbsorcion {
    var titulo: String {
        switch self {
        case .rapida: "Rápida"
        case .normal: "Normal"
        case .lenta: "Lenta"
        }
    }

    /// En minúsculas, para el renglón «Absorción: normal, 3 horas».
    var nombre: String { titulo.lowercased() }

    var apoyo: String {
        switch self {
        case .rapida: "Jugo, refresco, algo dulce solo"
        case .normal: "Una comida como las de siempre"
        case .lenta: "Mucha grasa o mucha fibra: pizza, tacos, guisado"
        }
    }
}

// MARK: - El escáner

/// La cámara apuntando al código, con una línea de texto encima. Mientras busca no se
/// cierra: así no hay un parpadeo entre «leí el código» y «aquí está el producto».
private struct HojaEscaner: View {
    @Bindable var modelo: RegistroComidaViewModel
    @State private var textoCodigo = ""
    @FocusState private var campoEnfocado: Bool

    var body: some View {
        NavigationStack {
            Group {
                if modelo.escanerSinCamara {
                    codigoEscrito
                } else {
                    camara
                }
            }
            .background(Tema.Colores.fondo)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { modelo.mostrandoEscaner = false }
                }
            }
        }
    }

    private var camara: some View {
        EscanerCodigoView(
            alLeer: { codigo in Task { await modelo.escaneado(codigo: codigo) } },
            alNoHaberCamara: { modelo.escanerNoTieneCamara() }
        )
        .ignoresSafeArea(edges: .bottom)
        .safeAreaInset(edge: .bottom) {
            estado
                .padding(Tema.Espacio.interior)
                .frame(maxWidth: .infinity)
                .background(Tema.Colores.superficie)
        }
    }

    /// Sin cámara o sin permiso no hay pantalla de error: el código viene impreso debajo de
    /// las barras y se puede escribir.
    private var codigoEscrito: some View {
        VStack(alignment: .leading, spacing: Tema.Espacio.entreTarjetas) {
            Text("Sin cámara no puedo leer el código. Escribe los números que vienen "
                + "debajo de las barras.")
                .font(Tema.Tipografia.textoLectura)
                .foregroundStyle(Tema.Colores.textoPrincipal)
                .fixedSize(horizontal: false, vertical: true)

            TextField("", text: $textoCodigo)
                .font(Tema.Tipografia.tituloPantalla)
                .foregroundStyle(Tema.Colores.azulProfundo)
                .keyboardType(.numberPad)
                .focused($campoEnfocado)
                .padding(Tema.Espacio.interior)
                .background(Tema.Colores.superficie)
                .clipShape(RoundedRectangle(cornerRadius: Tema.Radio.campo))
                .accessibilityLabel("Código de barras")
                .accessibilityIdentifier("campoCodigoDeBarras")

            estado

            Button {
                Task { await modelo.escaneado(codigo: textoCodigo) }
            } label: {
                Text("Buscar")
                    .font(Tema.Tipografia.tituloTarjeta)
                    .frame(maxWidth: .infinity, minHeight: Tema.Medida.botonPrincipal)
                    .foregroundStyle(Tema.Colores.superficie)
                    .background(
                        textoCodigo.isEmpty || modelo.buscando
                            ? Tema.Colores.textoSecundario : Tema.Colores.azulPrimario
                    )
                    .clipShape(RoundedRectangle(cornerRadius: Tema.Radio.campo))
            }
            .disabled(textoCodigo.isEmpty || modelo.buscando)
            .accessibilityIdentifier("botonBuscarCodigo")

            Spacer()
        }
        .padding(Tema.Espacio.margenLateral)
        .onAppear { campoEnfocado = true }
    }

    @ViewBuilder
    private var estado: some View {
        if modelo.buscando {
            HStack(spacing: Tema.Espacio.interior) {
                ProgressView()
                Text("Buscando el producto…")
                    .font(Tema.Tipografia.textoLectura)
                    .foregroundStyle(Tema.Colores.textoPrincipal)
            }
        } else if let aviso = modelo.avisoDelEscaner {
            Label(
                modelo.escanerSinCamara
                    ? "Ese código no cuadra. Revisa los números."
                    : aviso,
                systemImage: "exclamationmark.triangle.fill"
            )
            .font(Tema.Tipografia.textoLectura)
            .foregroundStyle(Tema.Colores.textoPrincipal)
            .fixedSize(horizontal: false, vertical: true)
        } else if !modelo.escanerSinCamara {
            Text("Apunta al código de barras del producto")
                .font(Tema.Tipografia.textoLectura)
                .foregroundStyle(Tema.Colores.textoPrincipal)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
