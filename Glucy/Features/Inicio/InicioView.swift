import SwiftUI

/// La pantalla de inicio, en sus dos modos (pantallas 3 y 10).
///
/// Es una sola vista y no dos: con sensor y sin sensor el orden es el mismo y lo que cambia
/// es el contenido, así que quien active el sensor después de un mes de pinchazos no tiene
/// que volver a aprenderse la pantalla.
///
/// **No dibuja ninguna predicción**: en la fase 1 no hay modelo, y el pie de la gráfica lo
/// dice.
struct InicioView: View {
    @State private var modelo: InicioViewModel
    /// Lleva a la pestaña «Registrar», ya en lo que se va a anotar.
    private let alAnotar: (TipoDeRegistro) -> Void

    @ScaledMetric private var tamanoCifra: CGFloat = Tema.Tipografia.tamanoCifraGlucosa
    @Environment(\.dynamicTypeSize) private var tamanoLetra
    @Environment(\.scenePhase) private var fase

    private static let altoDeLaGrafica = Tema.Espacio.unidad * 55

    init(
        consultar: ConsultarInicio,
        sincronizar: SincronizarLecturasDelSensor,
        ajustes: ConsultarAjustesDeInsulina,
        alAnotar: @escaping (TipoDeRegistro) -> Void
    ) {
        self.alAnotar = alAnotar
        _modelo = State(initialValue: InicioViewModel(
            consultar: consultar, sincronizar: sincronizar, ajustes: ajustes
        ))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Tema.Espacio.entreTarjetas) {
                    if modelo.sinLecturas || modelo.sinRespuesta {
                        // El aviso va también el primer día: sin lecturas tampoco se puede
                        // anticipar nada.
                        if modelo.mostrarAvisoSinSensor { avisoSinSensor }
                        primerDia
                    } else {
                        valor
                        if modelo.mostrarAvisoSinSensor { avisoSinSensor }
                        // Debajo del aviso cuando salen los dos.
                        if let texto = modelo.textoSinDatosDelSensor { franjaDelSensor(texto) }
                        tarjetaDeLaGrafica
                        loQueSigueActivo
                        accesosRapidos
                    }
                }
                .padding(.horizontal, Tema.Espacio.margenLateral)
                .padding(.vertical, Tema.Espacio.margenLateral)
            }
            .background(Tema.Colores.fondo)
            .navigationTitle("Inicio")
            .navigationBarTitleDisplayMode(.inline)
        }
        // Al entrar a la pestaña, al volver a la app y cada minuto mientras se ve: la
        // antigüedad de la lectura envejece sola aunque no llegue nada nuevo (RF-06c).
        .task(id: fase) {
            guard fase == .active else { return }
            while !Task.isCancelled {
                await modelo.ponerAlDia()
                try? await Task.sleep(for: .seconds(60))
            }
        }
    }

    // MARK: - Partes

    /// La cifra protagonista, con su unidad, y debajo el modo y su antigüedad.
    private var valor: some View {
        VStack(alignment: .leading, spacing: Tema.Espacio.unidad * 2) {
            // Con la letra de accesibilidad la cifra y su unidad no caben en un renglón: la
            // unidad baja (P-15).
            let disposicion = tamanoLetra.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 0))
                : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: Tema.Espacio.unidad * 2))
            disposicion {
                if let texto = modelo.textoValor {
                    Text(texto)
                        .font(.system(size: tamanoCifra, weight: .bold))
                        // Mientras se actualiza, el valor anterior se queda, en gris.
                        .foregroundStyle(
                            modelo.actualizando ? Tema.Colores.textoSecundario : Tema.Colores.azulProfundo
                        )
                    Text("mg/dL")
                        .font(Tema.Tipografia.textoLectura)
                        .foregroundStyle(Tema.Colores.textoSecundario)
                } else {
                    // Antes de la primera respuesta: el hueco de la cifra, no un cero.
                    RoundedRectangle(cornerRadius: Tema.Radio.campo)
                        .fill(Tema.Colores.textoSecundario.opacity(0.15))
                        .frame(width: tamanoCifra * 2, height: tamanoCifra)
                }
                if modelo.actualizando {
                    Text("actualizando")
                        .font(Tema.Tipografia.etiqueta)
                        .foregroundStyle(Tema.Colores.textoSecundario)
                }
            }

            if modelo.cargado {
                Label(modelo.letreroDelModo, systemImage: iconoDelModo)
                    .font(Tema.Tipografia.valorFila)
                    .foregroundStyle(Tema.Colores.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("letreroDelModo")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(modelo.valorHablado ?? "Cargando tu última lectura")
        // Solo se llama así cuando ya hay un valor que leer, no mientras carga.
        .accessibilityIdentifier(modelo.textoValor == nil ? "valorCargando" : "valorActual")
        .accessibilityValue(modelo.segundosHastaElValor.map { String(format: "%.3f", $0) } ?? "")
        // Primero el valor, después el aviso y después la gráfica.
        .accessibilitySortPriority(2)
    }

    /// El modo no se distingue solo por el texto: cada uno lleva su símbolo.
    private var iconoDelModo: String {
        modelo.estado?.modo == .sensor ? "dot.radiowaves.left.and.right" : "drop"
    }

    /// RF-10b: en modo sin sensor la app declara que no puede anticipar hipoglucemias.
    ///
    /// No tiene equis ni «entendido», no hay ningún estado que lo esconda y nada lo
    /// recuerda apagado: si se pudiera cerrar, se cerraría el primer día y el requisito
    /// dejaría de cumplirse para siempre. El ámbar va solo en el borde y en el icono.
    private var avisoSinSensor: some View {
        HStack(alignment: .top, spacing: Tema.Espacio.unidad * 3) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundStyle(Tema.Colores.alertaAmbar)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Tema.Espacio.unidad) {
                Text("Sin sensor no puedo anticipar hipoglucemias.")
                    .font(Tema.Tipografia.valorFila)
                    .foregroundStyle(Tema.Colores.textoPrincipal)
                Text("Te enseño lo que has medido, no lo que va a pasar. Si te sientes mal, mídete.")
                    .font(Tema.Tipografia.etiqueta)
                    .foregroundStyle(Tema.Colores.textoPrincipal)
            }
            // Crece hacia abajo lo que haga falta: un aviso cortado a la mitad puede acabar
            // diciendo lo contrario de lo que dice.
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
        // VoiceOver lo lee justo después del valor y antes de la gráfica.
        .accessibilitySortPriority(1)
        .accessibilityIdentifier("avisoSinSensor")
    }

    /// El sensor que la persona dijo tener lleva un rato sin escribir. El ámbar va solo en
    /// el borde y en el icono; lo que informa son el triángulo, la hora y el botón.
    private func franjaDelSensor(_ texto: String) -> some View {
        VStack(alignment: .leading, spacing: Tema.Espacio.unidad * 3) {
            HStack(alignment: .top, spacing: Tema.Espacio.unidad * 3) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title3)
                    .foregroundStyle(Tema.Colores.alertaAmbar)
                    .accessibilityHidden(true)
                Text(texto)
                    .font(Tema.Tipografia.etiqueta)
                    .foregroundStyle(Tema.Colores.textoPrincipal)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("textoSinDatosDelSensor")
                Spacer(minLength: 0)
            }
            Button {
                Task { await modelo.ponerAlDia() }
            } label: {
                Text("Reintentar")
                    .font(Tema.Tipografia.valorFila)
                    .foregroundStyle(Tema.Colores.azulPrimario)
                    .frame(maxWidth: .infinity, minHeight: Tema.Medida.areaTocable)
                    .background(Tema.Colores.azulClaro)
                    .clipShape(RoundedRectangle(cornerRadius: Tema.Radio.campo))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("botonReintentarSensor")
        }
        .padding(Tema.Espacio.interior)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tema.Colores.superficie)
        .clipShape(RoundedRectangle(cornerRadius: Tema.Radio.bloqueInterno))
        .overlay(
            RoundedRectangle(cornerRadius: Tema.Radio.bloqueInterno)
                .stroke(Tema.Colores.alertaAmbar, lineWidth: 2)
        )
    }

    private var tarjetaDeLaGrafica: some View {
        VStack(alignment: .leading, spacing: Tema.Espacio.unidad * 3) {
            if let contenido = modelo.contenidoDeLaGrafica {
                GraficaGlucosa(contenido: contenido, resumen: modelo.resumenDeLaGrafica)
            } else if modelo.cargado {
                // Hay una última lectura, pero es más vieja que la ventana. Se dice, en el
                // mismo espacio: una gráfica vacía se lee como que la app está rota.
                Text(modelo.textoSinPuntos)
                    .font(Tema.Tipografia.textoLectura)
                    .foregroundStyle(Tema.Colores.textoSecundario)
                    .frame(maxWidth: .infinity, minHeight: Self.altoDeLaGrafica)
                    .multilineTextAlignment(.center)
            } else {
                // Cargando: la gráfica guarda su sitio con un bloque gris.
                RoundedRectangle(cornerRadius: Tema.Radio.campo)
                    .fill(Tema.Colores.textoSecundario.opacity(0.15))
                    .frame(height: Self.altoDeLaGrafica)
                    .accessibilityHidden(true)
            }

            if modelo.cargado {
                Text(modelo.pieDeLaGrafica)
                    .font(Tema.Tipografia.etiqueta)
                    .foregroundStyle(Tema.Colores.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("pieDeLaGrafica")
            }
        }
        .padding(Tema.Espacio.interior)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tema.Colores.superficie)
        .clipShape(RoundedRectangle(cornerRadius: Tema.Radio.tarjetaGrande))
    }

    /// Dos cifras chicas, cada una con de dónde sale. Ninguna va seguida de un consejo.
    @ViewBuilder
    private var loQueSigueActivo: some View {
        if modelo.estado != nil {
            let disposicion = tamanoLetra.isAccessibilitySize
                ? AnyLayout(VStackLayout(spacing: Tema.Espacio.unidad * 2))
                : AnyLayout(HStackLayout(alignment: .top, spacing: Tema.Espacio.unidad * 2))
            disposicion {
                TarjetaCifra(
                    titulo: "Carbohidratos que siguen activos",
                    cifra: modelo.textoCarbohidratos,
                    unidad: "g",
                    pie: "de las comidas que anotaste",
                    cifraHablada: "\(modelo.textoCarbohidratos) gramos",
                    identificador: "carbohidratosActivos"
                )
                // Quien ocultó la insulina tampoco ve su cifra (RF-14).
                if modelo.registraInsulina {
                    TarjetaCifra(
                        titulo: "Insulina que sigue activa",
                        cifra: modelo.textoInsulina,
                        unidad: "UI",
                        pie: "de la insulina rápida que anotaste",
                        cifraHablada: "\(modelo.textoInsulina) unidades de insulina",
                        identificador: "insulinaActivaEnInicio"
                    )
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var accesosRapidos: some View {
        let disposicion = tamanoLetra.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: Tema.Espacio.unidad * 2))
            : AnyLayout(HStackLayout(spacing: Tema.Espacio.unidad * 2))
        return disposicion {
            acceso("Anotar comida", icono: "fork.knife", identificador: "accesoAnotarComida") {
                alAnotar(.comida)
            }
            // Ni en gris ni deshabilitado: si no se registra insulina, no está (RF-14).
            if modelo.registraInsulina {
                acceso("Anotar insulina", icono: "syringe", identificador: "accesoAnotarInsulina") {
                    alAnotar(.insulina)
                }
            }
        }
    }

    private func acceso(
        _ titulo: String, icono: String, identificador: String, alTocar: @escaping () -> Void
    ) -> some View {
        Button(action: alTocar) {
            Label(titulo, systemImage: icono)
                .font(Tema.Tipografia.tituloTarjeta)
                .foregroundStyle(Tema.Colores.azulPrimario)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Tema.Espacio.unidad * 2)
                .frame(maxWidth: .infinity, minHeight: Tema.Medida.botonPrincipal)
                .background(Tema.Colores.azulClaro)
                .clipShape(RoundedRectangle(cornerRadius: Tema.Radio.campo))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identificador)
    }

    /// El primer día. No una gráfica vacía: se dice qué falta y se ofrece cómo empezar.
    private var primerDia: some View {
        VStack(spacing: Tema.Espacio.entreTarjetas) {
            Image(systemName: "drop")
                .font(.system(size: 44))
                .foregroundStyle(Tema.Colores.textoSecundario)
                .accessibilityHidden(true)

            Text(modelo.sinRespuesta
                ? "No pude leer tus lecturas. Vuelve a intentarlo en un momento."
                : "Todavía no tengo lecturas tuyas.")
                .font(Tema.Tipografia.textoLectura)
                .foregroundStyle(Tema.Colores.textoSecundario)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("textoPrimerDia")

            Button {
                alAnotar(.glucosa)
            } label: {
                Text("Registrar una medición")
                    .font(Tema.Tipografia.tituloTarjeta)
                    .foregroundStyle(Tema.Colores.textoSobreColor)
                    .frame(maxWidth: .infinity, minHeight: Tema.Medida.botonPrincipal)
                    .background(Tema.Colores.azulPrimario)
                    .clipShape(RoundedRectangle(cornerRadius: Tema.Radio.campo))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("botonIrARegistrar")
        }
        .padding(.top, Tema.Espacio.margenLateral * 2)
        .frame(maxWidth: .infinity)
    }
}
