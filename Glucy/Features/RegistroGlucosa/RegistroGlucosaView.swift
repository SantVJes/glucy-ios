import SwiftUI

/// Pantalla 4 — registro de glucosa, vía manual.
///
/// La vista **no valida, no calcula y no toca la base**. Dibuja y recoge gestos; quien
/// decide si un número se puede guardar es `Validacion.validarLectura`, del paso 1, a
/// través del caso de uso.
struct RegistroGlucosaView: View {
    @State private var modelo: RegistroGlucosaViewModel
    @FocusState private var campoEnfocado: Bool

    /// La pestaña «Registrar» mantiene montadas todas sus pantallas y oculta las que no
    /// tocan, así que `onAppear` no dice cuándo se está viendo esta.
    /// Lo que la persona declaró en su perfil. Solo cambia el texto de la tarjeta del sensor.
    private let usaSensor: Bool
    private let visible: Bool

    /// La cifra crece con la letra del sistema: un tamaño fijo no se mueve con Dynamic Type
    /// y esta pantalla se diseña para el peor momento (P-15).
    @ScaledMetric private var tamanoCifra: CGFloat = Tema.Tipografia.tamanoCifraGlucosa

    init(
        registrar: RegistrarLecturaManual,
        registrarPorFoto: RegistrarLecturaPorFoto? = nil,
        ocr: (any ServicioOCR)? = nil,
        usaSensor: Bool = false,
        visible: Bool = true
    ) {
        self.usaSensor = usaSensor
        self.visible = visible
        _modelo = State(initialValue: RegistroGlucosaViewModel(
            registrar: registrar, registrarPorFoto: registrarPorFoto, ocr: ocr
        ))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Tema.Espacio.entreTarjetas) {
                    encabezado
                    vias
                    tarjetaDelValor
                    fechaYHora
                    contexto
                }
                .padding(.horizontal, Tema.Espacio.margenLateral)
                .padding(.bottom, Tema.Espacio.margenLateral)
                .onTapGesture { campoEnfocado = false }
            }
            // La acción principal va anclada al borde inferior y **por encima del
            // teclado**: si el botón se quedara dentro del scroll quedaría tapado justo
            // por lo que la persona acaba de usar para escribir. Un dato y una acción por
            // pantalla, y la acción siempre alcanzable.
            .safeAreaInset(edge: .bottom) {
                // Solo mientras la pantalla se ve. Lo que va en un borde de la zona segura no
                // hereda el `accessibilityHidden` de la pantalla, y VoiceOver leería el
                // «Guardar» de una pantalla oculta encima del de la que sí se ve.
                if visible {
                VStack(spacing: Tema.Espacio.unidad * 2) {
                    if modelo.ultimaGuardada != nil { franjaGuardada }

                    HStack(spacing: Tema.Espacio.unidad * 2) {
                        botonGuardar

                        // Solo aparece mientras el teclado está abierto
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
                            .accessibilityIdentifier("botonCerrarTeclado")
                        }
                    }
                }
                .padding(.horizontal, Tema.Espacio.margenLateral)
                .padding(.vertical, Tema.Espacio.unidad * 2)
                .background(Tema.Colores.fondo)
                }
            }
            .background(Tema.Colores.fondo)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Registrar")
                        .font(.headline)
                        .foregroundStyle(Tema.Colores.textoPrincipal)
                }
            }
            
            .navigationBarTitleDisplayMode(.inline)
            // Aquí adentro y no sobre el `NavigationStack`: desde afuera el modificador no
            // cruza la barra de navegación y VoiceOver seguiría leyendo la pantalla oculta.
            .accessibilityHidden(!visible)
        }
        // El teclado no se abre solo, ni al entrar a la pestaña ni al volver de Comida:
        // tapa media pantalla a quien solo venía a ver, y las otras vías de captura quedan
        // debajo. Aparece cuando la persona toca el campo. Lo único que se hace aquí es
        // soltarlo cuando la pantalla se oculta.
        .onChange(of: visible) { _, seVe in
            if !seVe { campoEnfocado = false }
        }
        .onChange(of: modelo.fallo) { _, nuevo in
            guard let nuevo else { return }
            // El rechazo se anuncia solo: quien usa VoiceOver no ve el texto rojo aparecer.
            AccessibilityNotification.Announcement(nuevo.mensaje).post()
        }
        .fullScreenCover(isPresented: $modelo.mostrandoCamara) {
            CapturaFotoView(
                alCapturar: { datos in
                    modelo.mostrandoCamara = false
                    // La imagen se procesa y se suelta. No se guarda en ningún lado
                    // (regla 6): ni aquí, ni en el ViewModel, ni en la base.
                    Task { await modelo.procesar(imagen: datos) }
                },
                alCancelar: { modelo.mostrandoCamara = false }
            )
            .ignoresSafeArea()
        }
        // La confirmación es una hoja aparte porque es **la única puerta** al guardado por
        // foto: si el valor no pasa por aquí, no se guarda (RF-02, D-11, caso P-01).
        .sheet(isPresented: .init(
            get: { modelo.estadoFoto != .ninguno },
            set: { abierta in if !abierta { modelo.cerrarFoto() } }
        )) {
            ConfirmarLecturaOcrView(modelo: modelo)
        }
    }

    // MARK: - Partes

    private var encabezado: some View {
        VStack(alignment: .leading, spacing: Tema.Espacio.unidad) {
            Text("Registrar glucosa")
                .font(Tema.Tipografia.tituloPantalla)
                .foregroundStyle(Tema.Colores.textoPrincipal)
            Text("Elige de dónde viene el valor")
                .font(Tema.Tipografia.etiqueta)
                .foregroundStyle(Tema.Colores.textoSecundario)
        }
        .padding(.top, Tema.Espacio.interior)
    }

    /// Las tres vías se ven siempre: la persona tiene que saber que existen. Dos se usan
    /// aquí. La del sensor es solo informativa, porque del sensor no se captura nada a mano:
    /// sus lecturas entran solas por Salud (RF-06). Un botón apagado haría dudar de las
    /// otras dos.
    private var vias: some View {
        VStack(spacing: Tema.Espacio.unidad * 2) {
            ViaCaptura(
                titulo: "A mano",
                descripcion: "Escribe el número que te marcó el medidor",
                activa: true
            )
            Button {
                modelo.mostrandoCamara = true
            } label: {
                ViaCaptura(
                    titulo: "Foto del medidor",
                    descripcion: "Le tomas una foto a la pantalla y leo el número",
                    activa: false
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("viaFoto")
            ViaCaptura(
                titulo: "Del sensor",
                descripcion: usaSensor
                    ? "Tus lecturas entran solas desde Salud."
                    : "Puedes conectar tu sensor en Ajustes.",
                activa: false,
                icono: "dot.radiowaves.left.and.right"
            )
            .accessibilityIdentifier("viaSensor")
        }
    }

    private var tarjetaDelValor: some View {
        VStack(alignment: .leading, spacing: Tema.Espacio.unidad * 2) {
            // Cuando el número vino de la foto se dice, y se puede quitar. Sin esto, el
            // campo se llenaría solo y nadie sabría de dónde salió el valor.
            if modelo.propuestaOcr != nil {
                HStack(spacing: Tema.Espacio.unidad * 2) {
                    Label("Lo leí de la foto de tu medidor", systemImage: "camera.fill")
                        .font(Tema.Tipografia.etiqueta)
                        .foregroundStyle(Tema.Colores.textoSecundario)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Button("Quitar") { modelo.descartarLoDeLaFoto() }
                        .font(Tema.Tipografia.etiqueta)
                        .foregroundStyle(Tema.Colores.azulPrimario)
                        .accessibilityIdentifier("botonQuitarLoDeLaFoto")
                }
                .frame(minHeight: Tema.Medida.areaTocable)
            }

            HStack(alignment: .firstTextBaseline, spacing: Tema.Espacio.unidad * 2) {
                TextField("", text: $modelo.textoValor)
                    .font(.system(size: tamanoCifra, weight: .bold))
                    .foregroundStyle(Tema.Colores.azulProfundo)
                    .keyboardType(.decimalPad)
                    .focused($campoEnfocado)
                    .overlay(alignment: .leading) {
                           if modelo.textoValor.isEmpty {
                               Text("0")
                                   .font(.system(size: tamanoCifra, weight: .bold))
                                   .foregroundStyle(Tema.Colores.azulProfundo.opacity(0.3))
                                   .allowsHitTesting(false)
                           }
                       }
                    .accessibilityLabel("Valor de glucosa en miligramos por decilitro")

                Text("mg/dL")
                    .font(Tema.Tipografia.textoLectura)
                    .foregroundStyle(Tema.Colores.textoSecundario)
                    .accessibilityHidden(true)
            }

            if let fallo = modelo.fallo {
                // Pegado al campo que hay que corregir, no en un diálogo: un diálogo tapa
                // justo el valor que se está corrigiendo. Y con icono, porque el color
                // nunca es el único portador de información.
                Label {
                    Text(fallo.mensaje)
                        .font(Tema.Tipografia.etiqueta)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                }
                .foregroundStyle(Tema.Colores.hipoglucemia)
            }
        }
        .padding(Tema.Espacio.interior)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tema.Colores.superficie)
        .clipShape(RoundedRectangle(cornerRadius: Tema.Radio.tarjetaGrande))
        .overlay(
            RoundedRectangle(cornerRadius: Tema.Radio.tarjetaGrande)
                .stroke(
                    modelo.propuestaOcr != nil ? Tema.Colores.alertaAmbar : .clear,
                    lineWidth: 3
                )
        )
    }

    private var fechaYHora: some View {
        VStack(alignment: .leading, spacing: Tema.Espacio.unidad * 2) {
            Text("Cuándo")
                .font(Tema.Tipografia.tituloTarjeta)
                .foregroundStyle(Tema.Colores.textoPrincipal)

            // Arranca en «ahora» y se puede cambiar. No se pide confirmación si no se tocó.
            DatePicker(
                "Fecha y hora de la lectura",
                selection: $modelo.fecha,
                displayedComponents: [.date, .hourAndMinute]
            )
            .labelsHidden()
            .datePickerStyle(.compact)
            .tint(Tema.Colores.azulPrimario)
            .accessibilityLabel("Fecha y hora de la lectura")
        }
        .padding(Tema.Espacio.interior)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tema.Colores.superficie)
        .clipShape(RoundedRectangle(cornerRadius: Tema.Radio.tarjetaGrande ))
    }

    private var contexto: some View {
        VStack(alignment: .leading, spacing: Tema.Espacio.unidad * 2) {
            Text("Contexto")
                .font(Tema.Tipografia.tituloTarjeta)
                .foregroundStyle(Tema.Colores.textoPrincipal)
            Text("Es opcional")
                .font(Tema.Tipografia.etiqueta)
                .foregroundStyle(Tema.Colores.textoSecundario)

            // Rejilla adaptativa: con la letra de accesibilidad más grande los chips se
            // apilan en columna en vez de cortarse (P-15).
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 140), spacing: Tema.Espacio.unidad * 2)],
                alignment: .leading,
                spacing: Tema.Espacio.unidad * 2
            ) {
                ForEach(ContextoComida.allCases, id: \.self) { opcion in
                    ChipContexto(
                        opcion: opcion,
                        elegido: modelo.contexto == opcion,
                        alTocar: {
                            // Tocar el elegido lo quita: el contexto es opcional y tiene
                            // que poder deshacerse sin salir de la pantalla.
                            modelo.contexto = modelo.contexto == opcion ? nil : opcion
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

    private var botonGuardar: some View {
        Button {
            Task { await modelo.guardar()
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
        .accessibilityIdentifier("botonGuardar")
    }

    /// Franja breve con «Deshacer». Deshacer es mejor que preguntar «¿estás seguro?»: no
    /// interrumpe a quien acertó y rescata a quien se equivocó.
    private var franjaGuardada: some View {
        HStack {
            Label("Lectura guardada", systemImage: "checkmark.circle.fill")
                .font(Tema.Tipografia.valorFila)
                .foregroundStyle(Tema.Colores.textoSobreColor)
            Spacer()
            Button("Deshacer") { Task { await modelo.deshacer() } }
                .font(Tema.Tipografia.valorFila)
                .foregroundStyle(Tema.Colores.textoSobreColor)
                .accessibilityIdentifier("botonDeshacer")
        }
        .padding(.horizontal, Tema.Espacio.interior)
        .frame(minHeight: Tema.Medida.areaTocable)
        .background(Tema.Colores.enRango)
        .clipShape(RoundedRectangle(cornerRadius: Tema.Radio.campo))
        // Sin identificador en la franja: puesto sobre un contenedor baja a sus hijos y le
        // pisa el suyo a «Deshacer».
        .task(id: modelo.ultimaGuardada?.uuid) {
            // La franja se va sola a los cinco segundos; la lectura ya está guardada.
            try? await Task.sleep(for: .seconds(5))
            modelo.olvidarConfirmacion()
        }
    }
}

// MARK: - Piezas de la pantalla

/// Una de las tres vías de captura.
private struct ViaCaptura: View {
    let titulo: String
    let descripcion: String
    let activa: Bool
    /// La que solo informa lleva su propio símbolo en lugar del círculo de elegir: así no
    /// parece una opción que no se deja marcar.
    var icono: String? = nil

    var body: some View {
        HStack(spacing: Tema.Espacio.interior) {
            Image(systemName: icono ?? (activa ? "largecircle.fill.circle" : "circle"))
                .foregroundStyle(activa ? Tema.Colores.azulPrimario : Tema.Colores.textoSecundario)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Tema.Espacio.unidad / 2) {
                Text(titulo)
                    .font(Tema.Tipografia.tituloTarjeta)
                    .foregroundStyle(activa ? Tema.Colores.textoPrincipal : Tema.Colores.textoSecundario)
                Text(descripcion)
                    .font(Tema.Tipografia.etiqueta)
                    .foregroundStyle(Tema.Colores.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(Tema.Espacio.interior)
        .frame(maxWidth: .infinity, minHeight: Tema.Medida.areaTocable, alignment: .leading)
        .background(activa ? Tema.Colores.azulClaro : Tema.Colores.superficie)
        .clipShape(RoundedRectangle(cornerRadius: Tema.Radio.bloqueInterno))
        .overlay(
            RoundedRectangle(cornerRadius: Tema.Radio.bloqueInterno)
                .stroke(activa ? Tema.Colores.azulPrimario : .clear, lineWidth: 2)
        )
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(activa ? [.isSelected] : [])
    }
}

/// Una etiqueta de contexto. Las cinco son las de `ContextoComida`: no se inventa una sexta
/// ni se quita ninguna (RF-01).
private struct ChipContexto: View {
    let opcion: ContextoComida
    let elegido: Bool
    let alTocar: () -> Void

    var body: some View {
        Button(action: alTocar) {
            Text(opcion.etiquetaCorta)
                .font(Tema.Tipografia.etiqueta)
                .foregroundStyle(elegido ? Tema.Colores.azulPrimario : Tema.Colores.textoPrincipal)
                .padding(.horizontal, Tema.Espacio.interior)
                .frame(minHeight: Tema.Medida.chip)
                .frame(maxWidth: .infinity)
                .background(elegido ? Tema.Colores.azulClaro : Tema.Colores.fondo)
                .clipShape(Capsule() )
                .overlay(
                    Capsule().stroke(
                        elegido ? Tema.Colores.azulPrimario : Tema.Colores.textoSecundario.opacity(0.4),
                        lineWidth: elegido ? 2 : 1
                    )
                )
        
        }
        // El área tocable es de 44 aunque el chip mida 36.
        .frame(minHeight: Tema.Medida.areaTocable)
        .accessibilityLabel(opcion.etiquetaLarga)
        .accessibilityAddTraits(elegido ? [.isSelected] : [])
    }
}

extension ContextoComida {
    /// Lo que cabe en el chip.
    var etiquetaCorta: String {
        switch self {
        case .enAyunas: "En ayunas"
        case .antesDeComer: "Antes de comer"
        case .dosHorasDespues: "2 h después"
        case .antesDeDormir: "Antes de dormir"
        case .otro: "Otro"
        }
    }

    /// Lo que lee VoiceOver, que no abrevia: «2 h después» se oye como «dos hache después».
    var etiquetaLarga: String {
        switch self {
        case .enAyunas: "En ayunas"
        case .antesDeComer: "Antes de comer"
        case .dosHorasDespues: "Dos horas después de comer"
        case .antesDeDormir: "Antes de dormir"
        case .otro: "Otro"
        }
    }
}
