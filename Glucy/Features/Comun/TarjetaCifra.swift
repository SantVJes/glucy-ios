import SwiftUI

/// Una cifra con su título y su pie: qué es, cuánto es y sobre qué se calculó.
///
/// El pie no es opcional a propósito: una cifra que no dice de dónde sale es un adorno
/// (RF-16).
struct TarjetaCifra: View {
    let titulo: String
    let cifra: String
    var unidad: String? = nil
    let pie: String
    /// Cómo se dice la cifra en voz alta, cuando la unidad escrita no se lee bien («UI»,
    /// «mg/dL»). Si falta, VoiceOver lee lo que se ve.
    var cifraHablada: String? = nil
    var identificador: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: Tema.Espacio.unidad) {
            Text(titulo)
                .font(Tema.Tipografia.etiqueta)
                .foregroundStyle(Tema.Colores.textoSecundario)

            Text(cifra)
                .font(.system(.title2, weight: .bold))
                .foregroundStyle(Tema.Colores.azulProfundo)

            if let unidad {
                Text(unidad)
                    .font(Tema.Tipografia.etiqueta)
                    .foregroundStyle(Tema.Colores.textoSecundario)
            }

            Text(pie)
                .font(Tema.Tipografia.etiqueta)
                .foregroundStyle(Tema.Colores.textoSecundario)
                .padding(.top, Tema.Espacio.unidad)
        }
        // Crece hacia abajo lo que haga falta: ninguna línea se corta (P-15).
        .fixedSize(horizontal: false, vertical: true)
        .padding(Tema.Espacio.interior)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Tema.Colores.superficie)
        .clipShape(RoundedRectangle(cornerRadius: Tema.Radio.bloqueInterno))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(titulo): \(cifraHablada ?? [cifra, unidad].compactMap { $0 }.joined(separator: " ")). \(pie)")
        .accessibilityIdentifier(identificador ?? "")
    }
}
