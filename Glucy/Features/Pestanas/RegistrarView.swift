import SwiftUI

/// La pestaña «Registrar»: qué se va a anotar, y debajo su pantalla.
///
struct RegistrarView: View {
    @Environment(ContenedorDependencias.self) private var dependencias
    /// Lo que se está anotando. Lo guarda `PestanasView` y no esta vista porque los accesos
    /// rápidos de Inicio traen aquí con la opción ya elegida.
    @Binding var registro: TipoDeRegistro
    /// Arranca sin insulina y la agrega al leer el perfil: a quien la ocultó no se le dibuja
    /// ni un instante (RF-14).
    @State private var opciones = TipoDeRegistro.disponibles(registraInsulina: false)

    var body: some View {
        // Las pantallas están siempre montadas y la que no toca solo se oculta. Con un
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

            if opciones.contains(.insulina) {
                RegistroInsulinaView(
                    registrar: dependencias.registrarDosis,
                    calcular: dependencias.calcularInsulinaActiva,
                    ajustes: dependencias.ajustesDeInsulina,
                    visible: registro == .insulina
                )
                .pantalla(de: .insulina, elegida: registro)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            SelectorDeRegistro(elegido: $registro, opciones: opciones)
                .padding(.horizontal, Tema.Espacio.margenLateral)
                .padding(.vertical, Tema.Espacio.unidad * 2)
                .background(Tema.Colores.fondo)
        }
        // Cada vez que se entra a la pestaña: el interruptor se va a mover desde Ajustes.
        .task {
            opciones = TipoDeRegistro.disponibles(
                registraInsulina: await dependencias.ajustesDeInsulina.registraInsulina()
            )
            if !opciones.contains(registro) { registro = .glucosa }
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
