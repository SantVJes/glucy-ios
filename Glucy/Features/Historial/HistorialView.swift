import SwiftUI

/// El historial (pantalla 6): las tres cifras del periodo y, debajo, el día típico.
///
/// Cada cifra dice sobre cuántas mediciones se calculó, y la que todavía no significa nada
/// no se enseña: se dice qué le falta (RF-16).
struct HistorialView: View {
    @State private var modelo: HistorialViewModel

    @Environment(\.dynamicTypeSize) private var tamanoLetra

    private let armarInforme: ArmarInforme
    @State private var compartiendoInforme = false

    init(consultar: ConsultarHistorial, armarInforme: ArmarInforme) {
        self.armarInforme = armarInforme
        _modelo = State(initialValue: HistorialViewModel(consultar: consultar))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Tema.Espacio.entreTarjetas) {
                    selectorDePeriodo

                    if modelo.estado?.indicadores != nil {
                        cifras
                        diaTipico
                    } else if modelo.cargado {
                        faltanDias
                    }
                    // Al final: la persona acaba de ver sus cifras, y ese es el momento en
                    // que piensa en enseñárselas a su médico.
                    if modelo.cargado, !modelo.sinRespuesta { botonDelInforme }
                }
                .padding(.horizontal, Tema.Espacio.margenLateral)
                .padding(.vertical, Tema.Espacio.margenLateral)
            }
            .background(Tema.Colores.fondo)
            .navigationTitle("Historial")
            .navigationBarTitleDisplayMode(.inline)
        }
        // Cada vez que se entra a la pestaña: puede haber lecturas nuevas.
        .task { await modelo.ponerAlDia() }
        .sheet(isPresented: $compartiendoInforme) {
            // El periodo es el que ya está elegido arriba: no se vuelve a preguntar.
            CompartirInformeView(armar: armarInforme, periodoDias: modelo.periodoDias)
        }
    }

    // MARK: - Partes

    /// Los tres periodos. Propio y no el control segmentado del sistema, por lo mismo que el
    /// selector de «Registrar»: ese se pinta solo y no usa ningún color de `Tema`.
    private var selectorDePeriodo: some View {
        let disposicion = tamanoLetra.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: Tema.Espacio.unidad * 2))
            : AnyLayout(HStackLayout(spacing: Tema.Espacio.unidad * 2))
        return disposicion {
            ForEach(modelo.periodos, id: \.self) { dias in
                let elegido = modelo.periodoDias == dias
                Button {
                    Task { await modelo.elegir(periodo: dias) }
                } label: {
                    Text(modelo.titulo(delPeriodo: dias))
                        // El elegido no se distingue solo por el color: va en negrita y con
                        // el borde más grueso.
                        .font(elegido ? Tema.Tipografia.valorFila : Tema.Tipografia.etiqueta)
                        .foregroundStyle(elegido ? Tema.Colores.azulPrimario : Tema.Colores.textoPrincipal)
                        .frame(maxWidth: .infinity, minHeight: Tema.Medida.areaTocable)
                        .background(elegido ? Tema.Colores.azulClaro : Tema.Colores.superficie)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(
                                elegido ? Tema.Colores.azulPrimario : Tema.Colores.textoSecundario.opacity(0.4),
                                lineWidth: elegido ? 2 : 1
                            )
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Últimos \(dias) días")
                .accessibilityAddTraits(elegido ? [.isSelected] : [])
                .accessibilityIdentifier("periodo\(dias)")
            }
        }
    }

    /// Tiempo en rango, promedio y GMI. Con la letra de accesibilidad se apilan en una
    /// columna en lugar de cortarse (P-15).
    private var cifras: some View {
        let disposicion = tamanoLetra.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: Tema.Espacio.unidad * 2))
            : AnyLayout(HStackLayout(alignment: .top, spacing: Tema.Espacio.unidad * 2))
        return disposicion {
            TarjetaCifra(
                titulo: "Tiempo en rango",
                cifra: modelo.textoTiempoEnRango ?? "",
                pie: modelo.pieTiempoEnRango,
                cifraHablada: modelo.textoTiempoEnRango?.replacingOccurrences(of: " %", with: " por ciento"),
                identificador: "cifraTiempoEnRango"
            )
            TarjetaCifra(
                titulo: "Promedio",
                cifra: modelo.textoPromedio ?? "",
                unidad: "mg/dL",
                pie: modelo.piePromedio,
                cifraHablada: modelo.textoPromedio.map { "\($0) miligramos por decilitro" },
                identificador: "cifraPromedio"
            )
            // Mientras no se puede calcular, la tarjeta no desaparece: dice qué le falta.
            // Una tarjeta que aparece y desaparece hace pensar que la app está rota.
            TarjetaCifra(
                titulo: "GMI",
                cifra: modelo.textoGmi ?? "",
                pie: modelo.pieGmi,
                cifraHablada: modelo.textoGmi?.replacingOccurrences(of: " %", with: " por ciento"),
                identificador: "cifraGmi"
            )
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var diaTipico: some View {
        VStack(alignment: .leading, spacing: Tema.Espacio.unidad * 3) {
            Text("Tu día típico")
                .font(Tema.Tipografia.tituloTarjeta)
                .foregroundStyle(Tema.Colores.textoPrincipal)
            Text("La mediana de cada hora y, alrededor, entre qué valores cae la mitad de tus mediciones.")
                .font(Tema.Tipografia.etiqueta)
                .foregroundStyle(Tema.Colores.textoSecundario)
                .fixedSize(horizontal: false, vertical: true)

            GraficaGlucosa(
                contenido: modelo.contenidoDelDiaTipico, resumen: modelo.resumenDelDiaTipico
            )

            if let pie = modelo.pieDelDiaTipico {
                Text(pie)
                    .font(Tema.Tipografia.etiqueta)
                    .foregroundStyle(Tema.Colores.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("pieDelDiaTipico")
            }
        }
        .padding(Tema.Espacio.interior)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tema.Colores.superficie)
        .clipShape(RoundedRectangle(cornerRadius: Tema.Radio.tarjetaGrande))
    }

    private var botonDelInforme: some View {
        Button {
            compartiendoInforme = true
        } label: {
            Label("Informe para mi médico", systemImage: "doc.text")
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
        .accessibilityIdentifier("botonInformeParaMiMedico")
    }

    /// Menos de tres días con mediciones: ninguna cifra, y la verdad de por qué.
    private var faltanDias: some View {
        VStack(spacing: Tema.Espacio.entreTarjetas) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 44))
                .foregroundStyle(Tema.Colores.textoSecundario)
                .accessibilityHidden(true)

            Text(modelo.sinRespuesta
                ? "No pude leer tus lecturas. Vuelve a intentarlo en un momento."
                : TextosDeIndicadores.faltanDias)
                .font(Tema.Tipografia.textoLectura)
                .foregroundStyle(Tema.Colores.textoPrincipal)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if !modelo.sinRespuesta {
                Text(modelo.textoDiasQueLlevas)
                    .font(Tema.Tipografia.textoLectura)
                    .foregroundStyle(Tema.Colores.textoSecundario)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("diasQueLlevas")
            }
        }
        .padding(.top, Tema.Espacio.margenLateral * 2)
        .frame(maxWidth: .infinity)
    }
}
