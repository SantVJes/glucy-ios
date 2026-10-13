import SwiftUI

/// La hoja desde la que se comparte el informe: un interruptor, una explicación y un botón.
struct CompartirInformeView: View {
    @State private var modelo: InformeViewModel
    @Environment(\.dismiss) private var cerrar

    init(armar: ArmarInforme, periodoDias: Int) {
        _modelo = State(initialValue: InformeViewModel(armar: armar, periodoDias: periodoDias))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Tema.Espacio.entreTarjetas) {
                    Text("Un PDF de una hoja con tus cifras de los últimos \(modelo.periodoDias) días, "
                        + "tu día típico y cuántos registros hiciste. Tú decides a quién se lo das.")
                        .font(Tema.Tipografia.textoLectura)
                        .foregroundStyle(Tema.Colores.textoPrincipal)
                        .fixedSize(horizontal: false, vertical: true)

                    interruptorDeIdentidad

                    if let fallo = modelo.fallo {
                        Label(fallo, systemImage: "exclamationmark.triangle.fill")
                            .font(Tema.Tipografia.etiqueta)
                            .foregroundStyle(Tema.Colores.hipoglucemia)
                    }
                }
                .padding(.horizontal, Tema.Espacio.margenLateral)
                .padding(.vertical, Tema.Espacio.margenLateral)
            }
            .safeAreaInset(edge: .bottom) {
                botonDeCompartir
                    .padding(.horizontal, Tema.Espacio.margenLateral)
                    .padding(.vertical, Tema.Espacio.unidad * 2)
                    .background(Tema.Colores.fondo)
            }
            .background(Tema.Colores.fondo)
            .navigationTitle("Informe para tu médico")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { cerrar() }
                        .accessibilityIdentifier("botonCerrarInforme")
                }
            }
        }
        .tint(Tema.Colores.azulPrimario)
        .task { await modelo.preparar() }
        // Al cerrarse la hoja, el PDF se borra del teléfono.
        .onDisappear { modelo.cerrar() }
    }

    /// Uno solo para el bloque entero, y apagado: nombre, apellidos, año de nacimiento y
    /// peso van juntos o no van.
    private var interruptorDeIdentidad: some View {
        VStack(alignment: .leading, spacing: Tema.Espacio.unidad * 2) {
            Toggle(isOn: Binding(
                get: { modelo.conIdentidad },
                set: { nuevo in Task { await modelo.poner(conIdentidad: nuevo) } }
            )) {
                Text("Incluir mis datos personales")
                    .font(Tema.Tipografia.tituloTarjeta)
                    .foregroundStyle(Tema.Colores.textoPrincipal)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .tint(Tema.Colores.azulPrimario)
            .frame(minHeight: Tema.Medida.areaTocable)
            .accessibilityIdentifier("interruptorDeIdentidad")

            Text("Apagado, el informe solo lleva tus cifras. Encendido, lleva también tu nombre y "
                + "tu peso, para que tu médico sepa de quién es.")
                .font(Tema.Tipografia.etiqueta)
                .foregroundStyle(Tema.Colores.textoSecundario)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Tema.Espacio.interior)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tema.Colores.superficie)
        .clipShape(RoundedRectangle(cornerRadius: Tema.Radio.tarjetaGrande))
    }

    @ViewBuilder
    private var botonDeCompartir: some View {
        if let archivo = modelo.archivo, !modelo.generando {
            ShareLink(item: archivo) {
                Label("Compartir el PDF", systemImage: "square.and.arrow.up")
                    .font(Tema.Tipografia.tituloTarjeta)
                    .foregroundStyle(Tema.Colores.textoSobreColor)
                    .frame(maxWidth: .infinity, minHeight: Tema.Medida.botonPrincipal)
                    .background(Tema.Colores.azulPrimario)
                    .clipShape(RoundedRectangle(cornerRadius: Tema.Radio.campo))
            }
            .accessibilityIdentifier("botonCompartirPdf")
        } else {
            // Mientras se arma, el botón guarda su sitio.
            ProgressView()
                .tint(Tema.Colores.textoSobreColor)
                .frame(maxWidth: .infinity, minHeight: Tema.Medida.botonPrincipal)
                .background(Tema.Colores.textoSecundario)
                .clipShape(RoundedRectangle(cornerRadius: Tema.Radio.campo))
                .accessibilityLabel("Armando el informe")
        }
    }
}
