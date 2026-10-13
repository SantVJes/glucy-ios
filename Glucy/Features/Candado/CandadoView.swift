import SwiftUI

/// El candado. Se dibuja **encima** de la app, no en lugar de ella: al abrirse, la persona
/// vuelve exactamente a donde estaba.
///
/// La hoja de Face ID sale sola. Este botón existe para quien la cerró o no pasó: nadie se
/// queda fuera, porque el sistema ofrece el código del teléfono.
struct CandadoView: View {
    let alDesbloquear: () -> Void

    var body: some View {
        VStack(spacing: Tema.Espacio.entreTarjetas) {
            Image(systemName: "lock.fill")
                .font(.system(size: 44))
                .foregroundStyle(Tema.Colores.azulPrimario)
                .accessibilityHidden(true)

            Text("Glucy está bloqueada")
                .font(Tema.Tipografia.tituloPantalla)
                .foregroundStyle(Tema.Colores.textoPrincipal)
                .multilineTextAlignment(.center)

            Text("Ábrela con Face ID, Touch ID o el código de tu teléfono.")
                .font(Tema.Tipografia.textoLectura)
                .foregroundStyle(Tema.Colores.textoSecundario)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            BotonPrincipal(titulo: "Desbloquear", identificador: "botonDesbloquear", accion: alDesbloquear)
        }
        .padding(.horizontal, Tema.Espacio.margenLateral)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Tema.Colores.fondo.ignoresSafeArea())
        .accessibilityAddTraits(.isModal)
    }
}
