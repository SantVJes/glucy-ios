import SwiftUI

/// Lo que se puede anotar en la pestaña «Registrar». La insulina del paso 7 entra aquí como
/// un caso más y el selector la dibuja sin que nadie lo toque.
enum TipoDeRegistro: String, CaseIterable, Identifiable {
    case glucosa, comida

    var id: Self { self }

    var titulo: String {
        switch self {
        case .glucosa: "Glucosa"
        case .comida: "Comida"
        }
    }

    func icono(elegido: Bool) -> String {
        switch self {
        case .glucosa: elegido ? "drop.fill" : "drop"
        case .comida: "fork.knife"
        }
    }

    /// Su lugar en el selector, de izquierda a derecha. La pantalla se desliza hacia ese
    /// mismo lado.
    var posicion: Int {
        Self.allCases.firstIndex(of: self) ?? 0
    }

    /// La píldora del selector y las pantallas de abajo se mueven con la misma curva: con
    /// dos distintas se nota que una llega antes que la otra.
    static let animacionDeCambio = Animation.snappy(duration: 0.3)

    var identificador: String {
        switch self {
        case .glucosa: "segmentoGlucosa"
        case .comida: "segmentoComida"
        }
    }
}

/// El selector de arriba de «Registrar».
///
/// Es propio y no el control segmentado del sistema porque ese se pinta solo: con el iPhone
/// en modo oscuro sale oscuro en medio de una pantalla clara, y no usa ningún color de
/// `Tema`.
///
/// El elegido no se distingue solo por el color: es una píldora rellena, va en negrita y,
/// donde el símbolo lo tiene, cambia a su versión rellena.
struct SelectorDeRegistro: View {
    @Binding var elegido: TipoDeRegistro

    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento
    @Namespace private var pildora

    var body: some View {
        HStack(spacing: Tema.Espacio.unidad) {
            ForEach(TipoDeRegistro.allCases) { tipo in
                segmento(tipo)
            }
        }
        .padding(Tema.Espacio.unidad)
        .background(Tema.Colores.superficie)
        .clipShape(Capsule())
        .overlay(
            Capsule().stroke(Tema.Colores.textoSecundario.opacity(0.25), lineWidth: 1)
        )
        .sensoryFeedback(.selection, trigger: elegido)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Qué quieres registrar")
        .accessibilityIdentifier("selectorDeRegistro")
    }

    private func segmento(_ tipo: TipoDeRegistro) -> some View {
        let estaElegido = tipo == elegido
        return Button {
            withAnimation(reducirMovimiento ? nil : TipoDeRegistro.animacionDeCambio) {
                elegido = tipo
            }
        } label: {
            Label(tipo.titulo, systemImage: tipo.icono(elegido: estaElegido))
                .font(Tema.Tipografia.valorFila.weight(estaElegido ? .semibold : .regular))
                // Blanco sobre `azulPrimario`: 6.2:1. La letra azul sobre `azulClaro` de los
                // chips se queda en 4.14:1 y aquí no alcanza.
                .foregroundStyle(estaElegido ? Tema.Colores.superficie : Tema.Colores.textoPrincipal)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, Tema.Espacio.interior)
                .frame(maxWidth: .infinity, minHeight: Tema.Medida.areaTocable)
                .background {
                    if estaElegido {
                        Capsule()
                            .fill(Tema.Colores.azulPrimario)
                            .matchedGeometryEffect(id: "elegido", in: pildora)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(estaElegido ? [.isSelected] : [])
        .accessibilityIdentifier(tipo.identificador)
    }
}
