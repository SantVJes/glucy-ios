import SwiftUI

/// Lo que se puede anotar en la pestaña «Registrar».
enum TipoDeRegistro: String, CaseIterable, Identifiable {
    case glucosa, comida, insulina

    var id: Self { self }

    /// Las opciones que se dibujan. Quien no se aplica insulina no ve la tercera: no sale en
    /// gris ni deshabilitada, no está. Una opción deshabilitada invita a preguntarse qué
    /// falta (RF-14).
    static func disponibles(registraInsulina: Bool) -> [TipoDeRegistro] {
        registraInsulina ? allCases : allCases.filter { $0 != .insulina }
    }

    var titulo: String {
        switch self {
        case .glucosa: "Glucosa"
        case .comida: "Comida"
        case .insulina: "Insulina"
        }
    }

    func icono(elegido: Bool) -> String {
        switch self {
        case .glucosa: elegido ? "drop.fill" : "drop"
        case .comida: "fork.knife"
        case .insulina: elegido ? "syringe.fill" : "syringe"
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
        case .insulina: "segmentoInsulina"
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
    var opciones: [TipoDeRegistro] = TipoDeRegistro.allCases

    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento
    @Environment(\.dynamicTypeSize) private var tamanoLetra
    @Namespace private var pildora

    var body: some View {
        // Con la letra de accesibilidad tres opciones no caben en un renglón sin cortarse,
        // así que se apilan (P-15).
        let apilado = tamanoLetra.isAccessibilitySize
        let disposicion = apilado
            ? AnyLayout(VStackLayout(spacing: Tema.Espacio.unidad))
            : AnyLayout(HStackLayout(spacing: Tema.Espacio.unidad))
        let forma = RoundedRectangle(
            cornerRadius: apilado ? Tema.Radio.tarjetaGrande : Tema.Radio.completo
        )

        return disposicion {
            ForEach(opciones) { tipo in
                segmento(tipo)
            }
        }
        .padding(Tema.Espacio.unidad)
        .background(Tema.Colores.superficie)
        .clipShape(forma)
        .overlay(
            forma.stroke(Tema.Colores.textoSecundario.opacity(0.25), lineWidth: 1)
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
                .foregroundStyle(estaElegido ? Tema.Colores.textoSobreColor : Tema.Colores.textoPrincipal)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, Tema.Espacio.unidad * 2)
                .padding(.vertical, Tema.Espacio.unidad)
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
