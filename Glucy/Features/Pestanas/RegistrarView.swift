import SwiftUI

/// La pestaña «Registrar»: qué se va a anotar, y debajo su pantalla.
///
/// Arranca en glucosa, que es lo que se registra con más prisa.
struct RegistrarView: View {
    @Environment(ContenedorDependencias.self) private var dependencias
    @State private var registro = TipoDeRegistro.glucosa

    var body: some View {
        // Las dos pantallas están siempre montadas y la que no toca solo se oculta. Con un
        // `switch` la que se va se destruye con todo y su ViewModel: quien pasaba a Comida a
        // media captura de una glucosa volvía a un campo vacío y al principio de la pantalla.
        ZStack {
            RegistroGlucosaView(
                registrar: dependencias.registrarManual,
                registrarPorFoto: dependencias.registrarPorFoto,
                ocr: dependencias.ocr,
                visible: registro == .glucosa
            )
            .pantalla(de: .glucosa, elegida: registro)

            RegistroComidaView(
                registrar: dependencias.registrarComida,
                buscar: dependencias.buscarProducto,
                ocr: dependencias.ocr,
                visible: registro == .comida
            )
            .pantalla(de: .comida, elegida: registro)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            SelectorDeRegistro(elegido: $registro)
                .padding(.horizontal, Tema.Espacio.margenLateral)
                .padding(.vertical, Tema.Espacio.unidad * 2)
                .background(Tema.Colores.fondo)
        }
    }
}

private extension View {
    /// Oculta sin desmontar: ni se ve ni se toca. Que VoiceOver no la lea lo resuelve cada
    /// pantalla con su `visible`.
    ///
    /// La que no se ve espera corrida hacia su lado del selector, así que al elegirla entra
    /// desde ahí y la otra se va hacia el suyo: la pantalla se mueve hacia donde se movió
    /// la píldora. Es un desplazamiento corto y no de pantalla entera, que con el teclado y
    /// la barra inferior encima se ve pesado. Quien anima es el selector, y con «reducir
    /// movimiento» no anima nada.
    func pantalla(de tipo: TipoDeRegistro, elegida: TipoDeRegistro) -> some View {
        let visible = tipo == elegida
        let lado: CGFloat = tipo.posicion < elegida.posicion ? -1 : 1
        return opacity(visible ? 1 : 0)
            .offset(x: visible ? 0 : lado * Tema.Espacio.unidad * 6)
            .allowsHitTesting(visible)
    }
}
