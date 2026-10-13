import SwiftUI

/// El splash (pantalla 1): la única con fondo azul lleno.
///
/// Se dibuja mientras se lee el perfil y se retira sola en cuanto eso termina; nunca espera
/// un toque ni hace esperar por adorno.
struct SplashView: View {
    @ScaledMetric private var tamanoMarca: CGFloat = Tema.Tipografia.tamanoCifraGlucosa

    var body: some View {
        VStack(spacing: Tema.Espacio.unidad * 3) {
            Image(systemName: "drop.fill")
                .font(.system(size: tamanoMarca))
                .accessibilityHidden(true)
            Text("Glucy")
                .font(.system(size: tamanoMarca, weight: .bold))
            Text("Tu glucosa, media hora antes")
                .font(Tema.Tipografia.tituloPantalla)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(Tema.Colores.textoSobreColor)
        .padding(.horizontal, Tema.Espacio.margenLateral)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Tema.Colores.azulPrimario.ignoresSafeArea())
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("splash")
    }
}
