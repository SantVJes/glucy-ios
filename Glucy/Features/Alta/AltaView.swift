import SwiftUI

/// El alta del perfil (pantalla 2): cinco pasos, y el último es el consentimiento.
///
/// Se puede terminar eligiendo «Sin sensor» y sin conceder un solo permiso. Y no se puede
/// terminar sin aceptar: la puerta de la app es el consentimiento (LFPDPPP).
struct AltaView: View {
    @State private var modelo: AltaViewModel
    @State private var ruta: [PasoDeAlta] = []
    @FocusState private var tecladoAbierto: Bool
    @Environment(\.dynamicTypeSize) private var tamanoLetra

    private let alTerminar: () -> Void

    init(completar: CompletarAlta, alTerminar: @escaping () -> Void) {
        self.alTerminar = alTerminar
        _modelo = State(initialValue: AltaViewModel(completar: completar))
    }

    var body: some View {
        NavigationStack(path: $ruta) {
            paso(.nombre)
                .navigationDestination(for: PasoDeAlta.self) { paso($0) }
        }
        .tint(Tema.Colores.azulPrimario)
    }

    // MARK: - El armazón de cada paso

    @ViewBuilder
    private func paso(_ paso: PasoDeAlta) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tema.Espacio.entreTarjetas) {
                progreso(paso)
                switch paso {
                case .nombre: pasoNombre
                case .tipoYAnio: pasoTipoYAnio
                case .sensor: pasoSensor
                case .parametros: pasoParametros
                case .consentimiento: pasoConsentimiento
                }
            }
            .padding(.horizontal, Tema.Espacio.margenLateral)
            .padding(.vertical, Tema.Espacio.margenLateral)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            botonDelPaso(paso)
                .padding(.horizontal, Tema.Espacio.margenLateral)
                .padding(.vertical, Tema.Espacio.unidad * 2)
                .background(Tema.Colores.fondo)
        }
        .background(Tema.Colores.fondo)
        .navigationTitle("Tu perfil")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// En qué paso va, con número y con barra: el color nunca es lo único que informa.
    private func progreso(_ paso: PasoDeAlta) -> some View {
        VStack(alignment: .leading, spacing: Tema.Espacio.unidad * 2) {
            Text("Paso \(paso.rawValue) de \(PasoDeAlta.allCases.count)")
                .font(Tema.Tipografia.etiqueta)
                .foregroundStyle(Tema.Colores.textoSecundario)
            ProgressView(value: Double(paso.rawValue), total: Double(PasoDeAlta.allCases.count))
                .tint(Tema.Colores.azulPrimario)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private func botonDelPaso(_ paso: PasoDeAlta) -> some View {
        switch paso {
        case .nombre:
            BotonPrincipal(
                titulo: "Continuar", activo: modelo.nombreValido, identificador: "botonContinuarPaso1"
            ) { avanzar(a: .tipoYAnio) }
        case .tipoYAnio:
            BotonPrincipal(
                titulo: "Continuar", activo: modelo.puedeContinuarDelTipo(),
                identificador: "botonContinuarPaso2"
            ) { avanzar(a: .sensor) }
        case .sensor:
            BotonPrincipal(
                titulo: "Continuar", activo: modelo.usaSensor != nil,
                ocupado: modelo.pidiendoPermiso, identificador: "botonContinuarPaso3"
            ) {
                Task {
                    if await modelo.continuarDelSensor() { avanzar(a: .parametros) }
                }
            }
        case .parametros:
            BotonPrincipal(
                titulo: "Continuar", activo: modelo.puedeContinuarDeParametros,
                identificador: "botonContinuarPaso4"
            ) { avanzar(a: .consentimiento) }
        case .consentimiento:
            // «Acepto», no «Continuar»: es un consentimiento expreso, no un paso más.
            BotonPrincipal(
                titulo: "Acepto", ocupado: modelo.guardando, identificador: "botonAcepto"
            ) {
                Task {
                    if await modelo.aceptar() { alTerminar() }
                }
            }
        }
    }

    private func avanzar(a paso: PasoDeAlta) {
        tecladoAbierto = false
        ruta.append(paso)
    }

    // MARK: - Paso 1

    private var pasoNombre: some View {
        VStack(alignment: .leading, spacing: Tema.Espacio.entreTarjetas) {
            titulo(
                "¿Cómo te llamas?",
                "Es para hablarte por tu nombre. Se queda en tu teléfono y puedes dejarlo en blanco."
            )
            tarjeta {
                campo("Nombre", texto: $modelo.nombre, identificador: "campoNombre")
                    .textContentType(.givenName)
                campo("Apellidos", texto: $modelo.apellidos, identificador: "campoApellidos")
                    .textContentType(.familyName)
                aviso(modelo.mensajeDeNombre)
            }
        }
    }

    // MARK: - Paso 2

    private var pasoTipoYAnio: some View {
        VStack(alignment: .leading, spacing: Tema.Espacio.entreTarjetas) {
            titulo("¿Con qué vives?", "De esto depende qué pantallas ves.")
            // Las cuatro, no tres: la resistencia a la insulina también es usuaria (C-3).
            ForEach(TipoUsuario.allCases, id: \.self) { tipo in
                OpcionElegible(
                    titulo: tipo.nombreEnPantalla,
                    elegida: modelo.tipoUsuario == tipo,
                    identificador: tipo.identificador
                ) {
                    modelo.tipoUsuario = tipo
                    tecladoAbierto = false
                }
            }

            titulo("¿En qué año naciste?", "Solo el año. No guardo tu fecha de nacimiento.")
            tarjeta {
                TextField("", text: $modelo.textoAnio, prompt: Text("Por ejemplo, 1990"))
                    .keyboardType(.numberPad)
                    .font(Tema.Tipografia.tituloPantalla)
                    .foregroundStyle(Tema.Colores.textoPrincipal)
                    .focused($tecladoAbierto)
                    .frame(minHeight: Tema.Medida.areaTocable)
                    .accessibilityLabel("Año de nacimiento")
                    .accessibilityIdentifier("campoAnioNacimiento")
                aviso(modelo.mensajeDeAnio())
            }
        }
    }

    // MARK: - Paso 3

    private var pasoSensor: some View {
        VStack(alignment: .leading, spacing: Tema.Espacio.entreTarjetas) {
            titulo("¿Cómo te mides?", "Las dos formas funcionan. Puedes cambiarlo después en Ajustes.")

            // Del mismo tamaño siempre, lado a lado o apiladas: una tarjeta más grande que
            // la otra sería una recomendación, y tener sensor es opcional (RF-06).
            MismoTamano(apilado: tamanoLetra.isAccessibilitySize, separacion: Tema.Espacio.unidad * 2) {
                OpcionElegible(
                    titulo: "Tengo un sensor",
                    descripcion: "Dexcom o FreeStyle Libre, con su app escribiendo en Salud. "
                        + "Glucy lee de ahí; no necesitas emparejar nada.",
                    elegida: modelo.usaSensor == true,
                    identificador: "tarjetaConSensor"
                ) { modelo.elegir(usaSensor: true) }

                // La advertencia va dentro de la tarjeta, antes de elegir (RF-10b).
                OpcionElegible(
                    titulo: "Me mido con glucómetro",
                    descripcion: "Registras tus mediciones a mano o con una foto. Sin sensor no "
                        + "puedo anticipar hipoglucemias: te enseño lo que has medido, no lo "
                        + "que va a pasar.",
                    elegida: modelo.usaSensor == false,
                    identificador: "tarjetaSinSensor"
                ) { modelo.elegir(usaSensor: false) }
            }

            if modelo.usaSensor == true {
                // La explicación va antes de la hoja del sistema, nunca después.
                nota(
                    // Como clave localizable para que «leer» salga en negritas.
                    Text(LocalizedStringKey(
                        "Glucy va a pedirte permiso para **leer** tu glucosa de la app Salud. "
                            + "Nada más: no escribe encima de lo de tu sensor y no sale de tu "
                            + "teléfono. Si dices que no, la app funciona igual en modo sin sensor."
                    )),
                    identificador: "explicacionDelPermiso"
                )
            }
            if modelo.seguimosSinSensor {
                nota(
                    Text("Listo, seguimos sin sensor. Puedes activarlo cuando quieras desde Ajustes."),
                    identificador: "seguimosSinSensor"
                )
            }
        }
    }

    // MARK: - Paso 4

    private var pasoParametros: some View {
        VStack(alignment: .leading, spacing: Tema.Espacio.entreTarjetas) {
            titulo("Tus números", "Todos traen un valor para empezar. Puedes cambiarlos después.")

            tarjeta {
                Text("¿En qué unidad ves tu glucosa?")
                    .font(Tema.Tipografia.tituloTarjeta)
                    .foregroundStyle(Tema.Colores.textoPrincipal)
                MismoTamano(apilado: tamanoLetra.isAccessibilitySize, separacion: Tema.Espacio.unidad * 2) {
                    ForEach(UnidadGlucosa.allCases, id: \.self) { unidad in
                        OpcionElegible(
                            titulo: unidad.rawValue,
                            elegida: modelo.unidad == unidad,
                            identificador: "unidad_\(unidad == .mgDl ? "mgDl" : "mmolL")"
                        ) { modelo.unidad = unidad }
                    }
                }
            }

            tarjeta {
                ControlDePasos(
                    titulo: "Glucosa baja, por debajo de",
                    valor: modelo.unidad.texto(deMgDl: modelo.umbralHipo),
                    valorHablado: modelo.unidad.hablado(deMgDl: modelo.umbralHipo),
                    puedeBajar: modelo.umbralHipo > ConfiguracionDominio.umbralHipoConfigurable.lowerBound,
                    puedeSubir: modelo.umbralHipo < ConfiguracionDominio.umbralHipoConfigurable.upperBound,
                    identificador: "umbralHipo",
                    alBajar: { modelo.moverUmbralHipo(-1) },
                    alSubir: { modelo.moverUmbralHipo(1) }
                )
                ControlDePasos(
                    titulo: "Glucosa alta, por encima de",
                    valor: modelo.unidad.texto(deMgDl: modelo.umbralHiper),
                    valorHablado: modelo.unidad.hablado(deMgDl: modelo.umbralHiper),
                    puedeBajar: modelo.umbralHiper > ConfiguracionDominio.umbralHiperConfigurable.lowerBound,
                    puedeSubir: modelo.umbralHiper < ConfiguracionDominio.umbralHiperConfigurable.upperBound,
                    identificador: "umbralHiper",
                    alBajar: { modelo.moverUmbralHiper(-1) },
                    alSubir: { modelo.moverUmbralHiper(1) }
                )
            }

            tarjeta {
                campo(
                    "Peso en kilos (opcional)", texto: $modelo.textoPeso, identificador: "campoPeso"
                )
                .keyboardType(.decimalPad)
                aviso(modelo.mensajeDePeso)
            }

            if modelo.registraInsulina {
                tarjeta {
                    campo(
                        "Tu insulina rápida (opcional)", texto: $modelo.tipoInsulinaRapida,
                        identificador: "campoTipoInsulina"
                    )
                    ControlDePasos(
                        titulo: "Cuánto te dura trabajando",
                        valor: AltaViewModel.textoDeHoras(modelo.duracionAccionH),
                        valorHablado: "\(modelo.duracionAccionH) horas",
                        puedeBajar: modelo.duracionAccionH
                            > ConfiguracionDominio.duracionAccionConfigurableH.lowerBound,
                        puedeSubir: modelo.duracionAccionH
                            < ConfiguracionDominio.duracionAccionConfigurableH.upperBound,
                        identificador: "duracionAccion",
                        alBajar: { modelo.moverDuracion(-1) },
                        alSubir: { modelo.moverDuracion(1) }
                    )
                }
            }
        }
    }

    // MARK: - Paso 5

    /// El consentimiento, completo y con su fecha. No es una casilla al pie de un párrafo
    /// que nadie lee.
    private var pasoConsentimiento: some View {
        VStack(alignment: .leading, spacing: Tema.Espacio.entreTarjetas) {
            titulo(
                "Tu consentimiento",
                "Glucy guarda datos de tu salud. Antes de empezar necesito que lo aceptes."
            )

            tarjeta {
                punto("Qué guardo", "Tus lecturas de glucosa, tus comidas, tus dosis de insulina y los datos de tu perfil.")
                punto("Dónde", "En tu teléfono. Glucy funciona completa sin internet y sin servidor.")
                punto(
                    "Qué sube",
                    "Nada, mientras no enciendas la sincronización. Si la enciendes, suben tus "
                        + "lecturas, tus comidas, tus dosis y tu contexto, bajo un identificador que no "
                        + "dice quién eres. Tu nombre, tus apellidos, tu peso, tus notas y tus fotos "
                        + "no suben nunca."
                )
                punto(
                    "Puedes cambiar de opinión",
                    "Este consentimiento se puede retirar. Desde Ajustes puedes borrar tu cuenta "
                        + "y todo lo que Glucy guardó, cuando quieras."
                )
            }
            .accessibilityIdentifier("textoDelConsentimiento")

            Text("Fecha: \(modelo.textoDeHoy())")
                .font(Tema.Tipografia.valorFila)
                .foregroundStyle(Tema.Colores.textoPrincipal)
                .accessibilityIdentifier("fechaDelConsentimiento")

            aviso(modelo.fallo)

            Text("Glucy no es un dispositivo médico certificado y no sustituye la indicación de "
                + "tu médico. Informa; no prescribe ni administra.")
                .font(Tema.Tipografia.etiqueta)
                .foregroundStyle(Tema.Colores.textoSecundario)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Piezas

    private func titulo(_ titulo: String, _ explicacion: String) -> some View {
        VStack(alignment: .leading, spacing: Tema.Espacio.unidad) {
            Text(titulo)
                .font(Tema.Tipografia.tituloPantalla)
                .foregroundStyle(Tema.Colores.textoPrincipal)
                .accessibilityAddTraits(.isHeader)
            Text(explicacion)
                .font(Tema.Tipografia.textoLectura)
                .foregroundStyle(Tema.Colores.textoSecundario)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func tarjeta(@ViewBuilder _ contenido: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Tema.Espacio.unidad * 3) {
            contenido()
        }
        .padding(Tema.Espacio.interior)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tema.Colores.superficie)
        .clipShape(RoundedRectangle(cornerRadius: Tema.Radio.tarjetaGrande))
    }

    private func campo(_ etiqueta: String, texto: Binding<String>, identificador: String) -> some View {
        VStack(alignment: .leading, spacing: Tema.Espacio.unidad) {
            Text(etiqueta)
                .font(Tema.Tipografia.etiqueta)
                .foregroundStyle(Tema.Colores.textoSecundario)
                .accessibilityHidden(true)
            TextField("", text: texto)
                .font(Tema.Tipografia.textoLectura)
                .foregroundStyle(Tema.Colores.textoPrincipal)
                .focused($tecladoAbierto)
                .frame(minHeight: Tema.Medida.areaTocable)
                .padding(.horizontal, Tema.Espacio.unidad * 3)
                .background(Tema.Colores.fondo)
                .clipShape(RoundedRectangle(cornerRadius: Tema.Radio.campo))
                .accessibilityLabel(etiqueta)
                .accessibilityIdentifier(identificador)
        }
    }

    /// Lo que hay que corregir, pegado al campo y con icono además de color.
    @ViewBuilder
    private func aviso(_ mensaje: String?) -> some View {
        if let mensaje {
            Label {
                Text(mensaje)
                    .font(Tema.Tipografia.etiqueta)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
            }
            .foregroundStyle(Tema.Colores.hipoglucemia)
        }
    }

    private func nota(_ texto: Text, identificador: String) -> some View {
        HStack(alignment: .top, spacing: Tema.Espacio.unidad * 3) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(Tema.Colores.azulPrimario)
                .accessibilityHidden(true)
            texto
                .font(Tema.Tipografia.etiqueta)
                .foregroundStyle(Tema.Colores.textoPrincipal)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(Tema.Espacio.interior)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tema.Colores.azulClaro)
        .clipShape(RoundedRectangle(cornerRadius: Tema.Radio.bloqueInterno))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identificador)
    }

    private func punto(_ titulo: String, _ texto: String) -> some View {
        VStack(alignment: .leading, spacing: Tema.Espacio.unidad) {
            Text(titulo)
                .font(Tema.Tipografia.valorFila)
                .foregroundStyle(Tema.Colores.textoPrincipal)
            Text(texto)
                .font(Tema.Tipografia.textoLectura)
                .foregroundStyle(Tema.Colores.textoPrincipal)
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }
}
