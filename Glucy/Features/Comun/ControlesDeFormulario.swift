import SwiftUI

/// Un valor que se mueve por pasos, con un botón para bajar y otro para subir.
///
/// Propio y no el `Stepper` del sistema porque ese se pinta solo y sus botones no llegan a
/// los 44 puntos que necesita alguien con el pulso tembloroso.
struct ControlDePasos: View {
    let titulo: String
    /// El valor ya con su unidad: «70 mg/dL», «5 h».
    let valor: String
    /// Cómo se dice en voz alta, cuando la unidad escrita no se lee bien.
    var valorHablado: String? = nil
    let puedeBajar: Bool
    let puedeSubir: Bool
    let identificador: String
    let alBajar: () -> Void
    let alSubir: () -> Void

    @Environment(\.dynamicTypeSize) private var tamanoLetra

    var body: some View {
        // Con la letra de accesibilidad el título y los botones no caben en un renglón: los
        // botones bajan (P-15).
        let disposicion = tamanoLetra.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Tema.Espacio.unidad * 2))
            : AnyLayout(HStackLayout(spacing: Tema.Espacio.unidad * 2))
        disposicion {
            VStack(alignment: .leading, spacing: Tema.Espacio.unidad) {
                Text(titulo)
                    .font(Tema.Tipografia.etiqueta)
                    .foregroundStyle(Tema.Colores.textoSecundario)
                Text(valor)
                    .font(Tema.Tipografia.tituloTarjeta)
                    .foregroundStyle(Tema.Colores.textoPrincipal)
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(titulo): \(valorHablado ?? valor)")
            .accessibilityIdentifier(identificador)

            HStack(spacing: Tema.Espacio.unidad * 2) {
                boton("minus", etiqueta: "Bajar \(titulo)", activo: puedeBajar, accion: alBajar)
                    .accessibilityIdentifier("\(identificador)Menos")
                boton("plus", etiqueta: "Subir \(titulo)", activo: puedeSubir, accion: alSubir)
                    .accessibilityIdentifier("\(identificador)Mas")
            }
        }
    }

    private func boton(
        _ simbolo: String, etiqueta: String, activo: Bool, accion: @escaping () -> Void
    ) -> some View {
        Button(action: accion) {
            Image(systemName: simbolo)
                .font(.title3.weight(.semibold))
                .frame(width: Tema.Medida.botonPrincipal, height: Tema.Medida.areaTocable)
                .foregroundStyle(activo ? Tema.Colores.azulPrimario : Tema.Colores.textoSecundario)
                .background(Tema.Colores.azulClaro.opacity(activo ? 1 : 0.4))
                .clipShape(RoundedRectangle(cornerRadius: Tema.Radio.campo))
        }
        .buttonStyle(.plain)
        .disabled(!activo)
        .accessibilityLabel(etiqueta)
    }
}

/// Una opción entre varias, con título y explicación. La elegida no se distingue solo por
/// el color: cambia el símbolo, el borde se engruesa y lleva el rasgo de «seleccionado».
struct OpcionElegible: View {
    let titulo: String
    var descripcion: String? = nil
    var icono: String? = nil
    let elegida: Bool
    let identificador: String
    let alTocar: () -> Void

    var body: some View {
        Button(action: alTocar) {
            VStack(alignment: .leading, spacing: Tema.Espacio.unidad * 2) {
                HStack(alignment: .firstTextBaseline, spacing: Tema.Espacio.unidad * 2) {
                    Image(systemName: elegida ? "largecircle.fill.circle" : "circle")
                        .foregroundStyle(elegida ? Tema.Colores.azulPrimario : Tema.Colores.textoSecundario)
                    Text(titulo)
                        .font(Tema.Tipografia.tituloTarjeta)
                        .foregroundStyle(Tema.Colores.textoPrincipal)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                    if let icono {
                        Image(systemName: icono)
                            .foregroundStyle(Tema.Colores.textoSecundario)
                            .accessibilityHidden(true)
                    }
                }
                if let descripcion {
                    // Sobre el azul claro el gris secundario no llega a 4.5:1, así que la
                    // explicación va siempre en el color principal.
                    Text(descripcion)
                        .font(Tema.Tipografia.etiqueta)
                        .foregroundStyle(Tema.Colores.textoPrincipal)
                        .multilineTextAlignment(.leading)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(Tema.Espacio.interior)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(elegida ? Tema.Colores.azulClaro : Tema.Colores.superficie)
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
        .accessibilityIdentifier(identificador)
    }
}

/// Pone sus piezas lado a lado, o apiladas, **todas del mismo tamaño**: el de la más grande.
///
/// Existe por las dos tarjetas de sensor del alta. Si una se viera más grande que la otra,
/// la pantalla estaría recomendando una, y tener sensor es opcional (RF-06).
struct MismoTamano: Layout {
    var apilado: Bool
    var separacion: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let ancho = proposal.width ?? 0
        let pieza = tamanoDePieza(ancho: ancho, subviews: subviews)
        let huecos = separacion * CGFloat(max(subviews.count - 1, 0))
        return apilado
            ? CGSize(width: ancho, height: pieza.height * CGFloat(subviews.count) + huecos)
            : CGSize(width: ancho, height: pieza.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let pieza = tamanoDePieza(ancho: bounds.width, subviews: subviews)
        for (indice, subvista) in subviews.enumerated() {
            let salto = CGFloat(indice)
            let origen = apilado
                ? CGPoint(x: bounds.minX, y: bounds.minY + salto * (pieza.height + separacion))
                : CGPoint(x: bounds.minX + salto * (pieza.width + separacion), y: bounds.minY)
            subvista.place(at: origen, proposal: ProposedViewSize(pieza))
        }
    }

    /// El ancho que le toca a cada una y el alto de la que más necesita con ese ancho.
    private func tamanoDePieza(ancho: CGFloat, subviews: Subviews) -> CGSize {
        guard !subviews.isEmpty else { return .zero }
        let cuantas = CGFloat(subviews.count)
        let anchoDePieza = apilado ? ancho : (ancho - separacion * (cuantas - 1)) / cuantas
        let alto = subviews
            .map { $0.sizeThatFits(ProposedViewSize(width: anchoDePieza, height: nil)).height }
            .max() ?? 0
        return CGSize(width: max(anchoDePieza, 0), height: alto)
    }
}

/// El botón principal de una pantalla: uno solo, grande y abajo.
struct BotonPrincipal: View {
    let titulo: String
    var activo: Bool = true
    var ocupado: Bool = false
    var destructivo: Bool = false
    let identificador: String
    let accion: () -> Void

    var body: some View {
        Button(action: accion) {
            ZStack {
                if ocupado {
                    ProgressView().tint(Tema.Colores.textoSobreColor)
                } else {
                    Text(titulo).font(Tema.Tipografia.tituloTarjeta)
                }
            }
            .frame(maxWidth: .infinity, minHeight: Tema.Medida.botonPrincipal)
            .foregroundStyle(Tema.Colores.textoSobreColor)
            .background(relleno)
            .clipShape(RoundedRectangle(cornerRadius: Tema.Radio.campo))
        }
        .buttonStyle(.plain)
        .disabled(!activo || ocupado)
        .accessibilityIdentifier(identificador)
    }

    private var relleno: Color {
        guard activo else { return Tema.Colores.textoSecundario }
        return destructivo ? Tema.Colores.hipoglucemia : Tema.Colores.azulPrimario
    }
}

extension UnidadGlucosa {
    /// Un valor guardado en mg/dL, escrito en esta unidad y con ella: «70 mg/dL»,
    /// «3.9 mmol/L».
    func texto(deMgDl mgDl: Double) -> String {
        switch self {
        case .mgDl: "\(Int(mgDl.rounded())) mg/dL"
        case .mmolL: "\(String(format: "%.1f", desdeMgDl(mgDl))) mmol/L"
        }
    }

    func hablado(deMgDl mgDl: Double) -> String {
        switch self {
        case .mgDl: "\(Int(mgDl.rounded())) miligramos por decilitro"
        case .mmolL: "\(String(format: "%.1f", desdeMgDl(mgDl))) milimoles por litro"
        }
    }
}

extension TipoUsuario {
    var nombreEnPantalla: String {
        switch self {
        case .tipo1: "Diabetes tipo 1"
        case .tipo2Insulinodependiente: "Diabetes tipo 2 con insulina"
        case .prediabetes: "Prediabetes"
        case .resistenciaInsulina: "Resistencia a la insulina"
        }
    }

    var identificador: String {
        "tipoUsuario_\(rawValue)"
    }
}
