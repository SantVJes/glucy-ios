import SwiftUI

/// El estado «vacío, primer día» de las pestañas que todavía no hacen nada.
///
/// Nunca un cero ni una pantalla en blanco: las dos hacen pensar que la app está rota. Se
/// dice qué falta y por qué, en presente y de tú.
struct PendienteView: View {
    let titulo: String
    let mensaje: String
    let icono: String

    var body: some View {
        NavigationStack {
            VStack(spacing: Tema.Espacio.entreTarjetas) {
                Image(systemName: icono)
                    .font(.system(size: 44))
                    .foregroundStyle(Tema.Colores.textoSecundario)
                    .accessibilityHidden(true)

                Text(mensaje)
                    .font(Tema.Tipografia.textoLectura)
                    .foregroundStyle(Tema.Colores.textoSecundario)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, Tema.Espacio.margenLateral)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Tema.Colores.fondo)
            .navigationTitle(titulo)
        }
    }
}

#Preview {
    PendienteView(
        titulo: "Inicio",
        mensaje: "Todavía no tengo lecturas tuyas.",
        icono: "drop"
    )
}
