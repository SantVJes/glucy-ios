import SwiftUI

/// Ajustes (pantalla 9): lo que el cálculo de verdad usa, la privacidad enumerada y, al
/// final, borrar la cuenta.
///
/// Aquí **no hay** dónde anotar las cifras con las que se calcula una dosis, ni para
/// consultarlas: Glucy registra lo que la persona dice haberse aplicado (regla 7).
struct AjustesView: View {
    @State private var modelo: AjustesViewModel
    @FocusState private var tecladoAbierto: Bool
    @Environment(\.dynamicTypeSize) private var tamanoLetra

    private let cuantoHay: ConsultarCuantoHay
    private let borrarTodo: BorrarTodo
    private let alBorrarCuenta: () -> Void

    init(
        guardar: GuardarAjustes,
        pendientes: ConsultarColaPendiente,
        completarAlta: CompletarAlta,
        sincronizar: SincronizarLecturasDelSensor,
        candado: any Candado,
        cuantoHay: ConsultarCuantoHay,
        borrarTodo: BorrarTodo,
        subirAlBackend: SincronizarConBackend? = nil,
        alBorrarCuenta: @escaping () -> Void
    ) {
        self.cuantoHay = cuantoHay
        self.borrarTodo = borrarTodo
        self.alBorrarCuenta = alBorrarCuenta
        _modelo = State(initialValue: AjustesViewModel(
            guardar: guardar, pendientes: pendientes, completarAlta: completarAlta,
            sincronizar: sincronizar, candado: candado, subirAlBackend: subirAlBackend
        ))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Tema.Espacio.entreTarjetas) {
                    if let ajustes = modelo.ajustes {
                        if let fallo = modelo.fallo { aviso(fallo) }
                        tusDatos(ajustes)
                        comoVesTusCifras(ajustes)
                        tusUmbrales(ajustes)
                        insulina(ajustes)
                        comidas(ajustes)
                        sensor(ajustes)
                        sincronizacion(ajustes)
                        asistente(ajustes)
                        privacidad
                        seguridad(ajustes)
                        borrar
                        Text("Glucy no es un dispositivo médico certificado y no debe usarse como "
                            + "única fuente para una decisión terapéutica. Informa; no prescribe ni "
                            + "administra, y nunca calcula ni sugiere una dosis de insulina.")
                            .font(Tema.Tipografia.etiqueta)
                            .foregroundStyle(Tema.Colores.textoSecundario)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("avisoNoEsDispositivoMedico")
                    }
                }
                .padding(.horizontal, Tema.Espacio.margenLateral)
                .padding(.vertical, Tema.Espacio.margenLateral)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Tema.Colores.fondo)
            .navigationTitle("Ajustes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Listo") { tecladoAbierto = false }
                }
            }
        }
        .tint(Tema.Colores.azulPrimario)
        // Cada vez que se entra a la pestaña: la cola pudo crecer.
        .task { await modelo.cargar() }
        // Lo tecleado se guarda al salir del campo.
        .onChange(of: tecladoAbierto) { _, abierto in
            if !abierto { Task { await modelo.confirmarTextos() } }
        }
    }

    // MARK: - Secciones

    private func tusDatos(_ ajustes: AjustesEditables) -> some View {
        seccion("Tus datos") {
            campo("Nombre", texto: $modelo.textoNombre, identificador: "ajusteNombre")
            campo("Apellidos", texto: $modelo.textoApellidos, identificador: "ajusteApellidos")
            campo("Peso en kilos (opcional)", texto: $modelo.textoPeso, identificador: "ajustePeso")
                .keyboardType(.decimalPad)
            campo("Año de nacimiento", texto: $modelo.textoAnio, identificador: "ajusteAnio")
                .keyboardType(.numberPad)

            Text("Con qué vives")
                .font(Tema.Tipografia.etiqueta)
                .foregroundStyle(Tema.Colores.textoSecundario)
            ForEach(TipoUsuario.allCases, id: \.self) { tipo in
                OpcionElegible(
                    titulo: tipo.nombreEnPantalla,
                    elegida: ajustes.tipoUsuario == tipo,
                    identificador: "ajuste_\(tipo.identificador)"
                ) {
                    Task { await modelo.cambiar { $0.tipoUsuario = tipo } }
                }
            }
        }
    }

    private func comoVesTusCifras(_ ajustes: AjustesEditables) -> some View {
        seccion("Cómo ves tus cifras") {
            MismoTamano(apilado: tamanoLetra.isAccessibilitySize, separacion: Tema.Espacio.unidad * 2) {
                ForEach(UnidadGlucosa.allCases, id: \.self) { unidad in
                    OpcionElegible(
                        titulo: unidad.rawValue,
                        elegida: ajustes.unidadPreferida == unidad,
                        identificador: "ajusteUnidad_\(unidad == .mgDl ? "mgDl" : "mmolL")"
                    ) {
                        Task { await modelo.cambiar { $0.unidadPreferida = unidad } }
                    }
                }
            }
            pie("Por ahora la unidad se usa en tus umbrales. Las demás pantallas siguen en mg/dL.")
        }
    }

    private func tusUmbrales(_ ajustes: AjustesEditables) -> some View {
        seccion("Tus umbrales") {
            ControlDePasos(
                titulo: "Glucosa baja, por debajo de",
                valor: ajustes.unidadPreferida.texto(deMgDl: ajustes.umbralHipo),
                valorHablado: ajustes.unidadPreferida.hablado(deMgDl: ajustes.umbralHipo),
                puedeBajar: ajustes.umbralHipo > ConfiguracionDominio.umbralHipoConfigurable.lowerBound,
                puedeSubir: ajustes.umbralHipo < ConfiguracionDominio.umbralHipoConfigurable.upperBound,
                identificador: "ajusteUmbralHipo",
                alBajar: { Task { await modelo.moverUmbralHipo(-1) } },
                alSubir: { Task { await modelo.moverUmbralHipo(1) } }
            )
            ControlDePasos(
                titulo: "Glucosa alta, por encima de",
                valor: ajustes.unidadPreferida.texto(deMgDl: ajustes.umbralHiper),
                valorHablado: ajustes.unidadPreferida.hablado(deMgDl: ajustes.umbralHiper),
                puedeBajar: ajustes.umbralHiper > ConfiguracionDominio.umbralHiperConfigurable.lowerBound,
                puedeSubir: ajustes.umbralHiper < ConfiguracionDominio.umbralHiperConfigurable.upperBound,
                identificador: "ajusteUmbralHiper",
                alBajar: { Task { await modelo.moverUmbralHiper(-1) } },
                alSubir: { Task { await modelo.moverUmbralHiper(1) } }
            )
        }
    }

    private func insulina(_ ajustes: AjustesEditables) -> some View {
        seccion("Insulina") {
            interruptor(
                "Registrar insulina",
                explicacion: nil,
                encendido: Binding(
                    get: { ajustes.registraInsulina },
                    set: { nuevo in Task { await modelo.cambiar { $0.registraInsulina = nuevo } } }
                ),
                identificador: "ajusteRegistraInsulina"
            )

            campo("Tu insulina rápida", texto: $modelo.textoInsulina, identificador: "ajusteTipoInsulina")
            ControlDePasos(
                titulo: "Cuánto te dura trabajando",
                valor: AltaViewModel.textoDeHoras(ajustes.duracionAccionH),
                valorHablado: "\(ajustes.duracionAccionH) horas",
                puedeBajar: ajustes.duracionAccionH
                    > ConfiguracionDominio.duracionAccionConfigurableH.lowerBound,
                puedeSubir: ajustes.duracionAccionH
                    < ConfiguracionDominio.duracionAccionConfigurableH.upperBound,
                identificador: "ajusteDuracionAccion",
                alBajar: { Task { await modelo.moverDuracion(-1) } },
                alSubir: { Task { await modelo.moverDuracion(1) } }
            )

            // Fija: aquí es donde alguien buscaría las cifras de un calculador de dosis, y
            // hay que decirle que no están y por qué (regla 7).
            Text("Glucy no calcula dosis. Guarda estos dos datos porque con ellos estima cuánta "
                + "insulina sigue trabajando, no cuánta deberías aplicarte.")
                .font(Tema.Tipografia.etiqueta)
                .foregroundStyle(Tema.Colores.textoPrincipal)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("glucyNoCalculaDosis")
        }
    }

    private func comidas(_ ajustes: AjustesEditables) -> some View {
        seccion("Comidas") {
            Text("Cuánto tardan en absorberse, si no dices otra cosa")
                .font(Tema.Tipografia.etiqueta)
                .foregroundStyle(Tema.Colores.textoSecundario)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(modelo.absorciones, id: \.self) { minutos in
                OpcionElegible(
                    titulo: modelo.titulo(deAbsorcion: minutos),
                    elegida: ajustes.tiempoAbsorcionMin == minutos,
                    identificador: "ajusteAbsorcion\(minutos)"
                ) {
                    Task { await modelo.cambiar { $0.tiempoAbsorcionMin = minutos } }
                }
            }
        }
    }

    private func sensor(_ ajustes: AjustesEditables) -> some View {
        seccion("Sensor") {
            interruptor(
                "Leer mi sensor desde Salud",
                explicacion: nil,
                encendido: Binding(
                    get: { ajustes.usaSensor },
                    set: { nuevo in Task { await modelo.ponerSensor(nuevo) } }
                ),
                identificador: "ajusteUsaSensor"
            )

            if ajustes.usaSensor {
                Text(LocalizedStringKey(
                    "Si lo apagas, Glucy deja de leer tu sensor y vuelve al modo sin sensor. "
                        + "**No pierdes nada**: tu historial se queda completo."
                ))
                .font(Tema.Tipografia.etiqueta)
                .foregroundStyle(Tema.Colores.textoPrincipal)
                .fixedSize(horizontal: false, vertical: true)
            } else {
                // La explicación está a la vista antes de tocar el interruptor, que es lo
                // que hace salir la hoja del sistema.
                Text(LocalizedStringKey(
                    "Glucy va a pedirte permiso para **leer** tu glucosa de la app Salud. "
                        + "Nada más: no escribe encima de lo de tu sensor y no sale de tu "
                        + "teléfono. Si dices que no, la app funciona igual en modo sin sensor."
                ))
                .font(Tema.Tipografia.etiqueta)
                .foregroundStyle(Tema.Colores.textoPrincipal)
                .fixedSize(horizontal: false, vertical: true)
            }
            if modelo.seguimosSinSensor {
                pie("Listo, seguimos sin sensor. Puedes activarlo cuando quieras desde Ajustes.")
            }
        }
    }

    private func sincronizacion(_ ajustes: AjustesEditables) -> some View {
        seccion("Sincronización") {
            // No es un interruptor: es cómo funciona, y no se puede cambiar (D-10).
            Label {
                Text("Glucy sincroniza solo con wifi, por lotes. No usa tus datos móviles.")
                    .font(Tema.Tipografia.textoLectura)
                    .foregroundStyle(Tema.Colores.textoPrincipal)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "wifi").foregroundStyle(Tema.Colores.textoSecundario)
            }

            interruptor(
                "Sincronizar mis registros",
                explicacion: nil,
                encendido: Binding(
                    get: { ajustes.sincronizacionActiva },
                    set: { nuevo in Task { await modelo.cambiar { $0.sincronizacionActiva = nuevo } } }
                ),
                identificador: "ajusteSincronizacion"
            )

            Text(modelo.textoPendientes)
                .font(Tema.Tipografia.valorFila)
                .foregroundStyle(Tema.Colores.textoPrincipal)
                .accessibilityIdentifier("pendientesEnCola")

            if let errores = modelo.textoErrores {
                // Lleva icono además del color: el color nunca es el único portador.
                Label(errores, systemImage: "exclamationmark.triangle.fill")
                    .font(Tema.Tipografia.etiqueta)
                    .foregroundStyle(Tema.Colores.alertaAmbar)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("erroresEnCola")
            }

            if modelo.hayBackend {
                if ajustes.sincronizacionActiva {
                    // El único camino que sube con datos móviles (caso P-08).
                    BotonPrincipal(
                        titulo: "Sincronizar ahora",
                        ocupado: modelo.ocupado,
                        identificador: "botonSincronizarAhora"
                    ) {
                        Task { await modelo.sincronizarAhora() }
                    }
                }
                if let resultado = modelo.textoUltimaVentana {
                    Text(resultado)
                        .font(Tema.Tipografia.etiqueta)
                        .foregroundStyle(Tema.Colores.textoSecundario)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("resultadoSincronizacion")
                }
                pie("«Sincronizar ahora» es lo único que usa tus datos móviles, y solo cuando "
                    + "tú lo tocas. Lo demás espera a que haya wifi.")
            } else {
                pie("Esta versión de la app no trae servidor configurado: aunque enciendas la "
                    + "sincronización, nada sale de tu teléfono. Los registros esperan en la cola.")
            }
        }
    }

    /// El interruptor del asistente de explicaciones.
    ///
    /// Se dice qué se apaga y qué no: apagarlo no deja la pantalla sin explicación, porque la
    /// app arma la frase con los mismos factores y sin llamar a ningún modelo de lenguaje. Un
    /// interruptor cuyo efecto no se entiende se queda como lo encontró.
    private func asistente(_ ajustes: AjustesEditables) -> some View {
        seccion("La explicación") {
            interruptor(
                "Que el asistente redacte la frase",
                explicacion: "Apagado, Glucy arma la frase con los mismos factores y sin "
                    + "consultar ningún asistente. Dice lo mismo, con menos variedad.",
                encendido: Binding(
                    get: { ajustes.asistenteActivo },
                    set: { nuevo in Task { await modelo.cambiar { $0.asistenteActivo = nuevo } } }
                ),
                identificador: "ajusteAsistente"
            )

            // Lo que se manda, enumerado, en la pantalla donde se decide: es el único dato de
            // la app que acaba en el texto de un asistente (regla 3).
            Text("Cuando está encendido se manda tu glucosa de ahora y la estimada, la hora, "
                + "tus umbrales, y qué movió la estimación. No se manda tu nombre, tu peso, "
                + "tus notas ni nada que te identifique.")
                .font(Tema.Tipografia.etiqueta)
                .foregroundStyle(Tema.Colores.textoSecundario)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("queSeMandaAlAsistente")

            if !modelo.hayBackend {
                pie("Esta versión de la app no trae servidor configurado, así que por ahora no "
                    + "hay frase de ninguna de las dos maneras. La estimación sale igual.")
            }
        }
    }

    /// Enumera; no resume. «Respetamos tu privacidad» no es información.
    private var privacidad: some View {
        seccion("Privacidad") {
            Text("Esto nunca sale de tu teléfono:")
                .font(Tema.Tipografia.valorFila)
                .foregroundStyle(Tema.Colores.textoPrincipal)
            ForEach([
                "Tu nombre y tus apellidos",
                "Tu peso",
                "Tus notas",
                "Las fotos del glucómetro y de las etiquetas: se leen y se descartan, no se guardan",
                "Los productos que consultaste por código de barras",
            ], id: \.self) { renglon in
                Label {
                    Text(renglon)
                        .font(Tema.Tipografia.textoLectura)
                        .foregroundStyle(Tema.Colores.textoPrincipal)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "lock.fill").foregroundStyle(Tema.Colores.textoSecundario)
                }
            }

            Text(LocalizedStringKey(
                "**Esto sube solo si tú enciendes la sincronización:** tus lecturas, tus "
                    + "comidas, tus dosis y tu contexto, bajo un identificador que no dice quién eres."
            ))
            .font(Tema.Tipografia.textoLectura)
            .foregroundStyle(Tema.Colores.textoPrincipal)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func seguridad(_ ajustes: AjustesEditables) -> some View {
        seccion("Seguridad") {
            interruptor(
                "Pedir Face ID al abrir",
                explicacion: "Esto no cifra nada: tu iPhone ya cifra tus datos. Solo evita que "
                    + "alguien que tome tu teléfono desbloqueado vea tu historial.",
                encendido: Binding(
                    get: { ajustes.bloqueoBiometrico },
                    set: { nuevo in Task { await modelo.ponerCandado(nuevo) } }
                ),
                identificador: "ajusteCandado"
            )
        }
    }

    /// Al final y en rojo. Es la única acción de la app que no se puede deshacer.
    private var borrar: some View {
        NavigationLink {
            BorrarCuentaView(cuantoHay: cuantoHay, borrarTodo: borrarTodo, alBorrar: alBorrarCuenta)
        } label: {
            Label("Borrar mi cuenta", systemImage: "trash")
                .font(Tema.Tipografia.tituloTarjeta)
                .foregroundStyle(Tema.Colores.hipoglucemia)
                .frame(maxWidth: .infinity, minHeight: Tema.Medida.botonPrincipal)
                .background(Tema.Colores.superficie)
                .clipShape(RoundedRectangle(cornerRadius: Tema.Radio.campo))
                .overlay(
                    RoundedRectangle(cornerRadius: Tema.Radio.campo)
                        .stroke(Tema.Colores.hipoglucemia, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("botonIrABorrarCuenta")
    }

    // MARK: - Piezas

    private func seccion(_ titulo: String, @ViewBuilder _ contenido: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Tema.Espacio.unidad * 3) {
            Text(titulo)
                .font(Tema.Tipografia.tituloTarjeta)
                .foregroundStyle(Tema.Colores.textoPrincipal)
                .accessibilityAddTraits(.isHeader)
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
                .submitLabel(.done)
                .frame(minHeight: Tema.Medida.areaTocable)
                .padding(.horizontal, Tema.Espacio.unidad * 3)
                .background(Tema.Colores.fondo)
                .clipShape(RoundedRectangle(cornerRadius: Tema.Radio.campo))
                .accessibilityLabel(etiqueta)
                .accessibilityIdentifier(identificador)
        }
    }

    private func interruptor(
        _ titulo: String,
        explicacion: String?,
        encendido: Binding<Bool>,
        identificador: String
    ) -> some View {
        VStack(alignment: .leading, spacing: Tema.Espacio.unidad) {
            Toggle(isOn: encendido) {
                Text(titulo)
                    .font(Tema.Tipografia.textoLectura)
                    .foregroundStyle(Tema.Colores.textoPrincipal)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .tint(Tema.Colores.azulPrimario)
            .disabled(modelo.ocupado)
            .frame(minHeight: Tema.Medida.areaTocable)
            .accessibilityIdentifier(identificador)

            if let explicacion { pie(explicacion) }
        }
    }

    private func pie(_ texto: String) -> some View {
        Text(texto)
            .font(Tema.Tipografia.etiqueta)
            .foregroundStyle(Tema.Colores.textoSecundario)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func aviso(_ mensaje: String) -> some View {
        Label {
            Text(mensaje)
                .font(Tema.Tipografia.etiqueta)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill")
        }
        .foregroundStyle(Tema.Colores.hipoglucemia)
        .accessibilityIdentifier("falloDeAjustes")
    }
}
