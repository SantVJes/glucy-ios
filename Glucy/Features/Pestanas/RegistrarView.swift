import SwiftUI

/// La pestaña «Registrar»: qué se va a anotar, y debajo su pantalla.
///
/// Arranca en glucosa, que es lo que se registra con más prisa. La insulina del paso 7 entra
/// aquí como un tercer segmento.
struct RegistrarView: View {
    private enum Registro: Hashable { case glucosa, comida }

    @Environment(ContenedorDependencias.self) private var dependencias
    @State private var registro = Registro.glucosa

    var body: some View {
        Group {
            switch registro {
            case .glucosa:
                RegistroGlucosaView(
                    registrar: dependencias.registrarManual,
                    registrarPorFoto: dependencias.registrarPorFoto,
                    ocr: dependencias.ocr
                )
            case .comida:
                RegistroComidaView(
                    registrar: dependencias.registrarComida,
                    buscar: dependencias.buscarProducto,
                    ocr: dependencias.ocr
                )
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            Picker("Qué quieres registrar", selection: $registro) {
                Text("Glucosa").tag(Registro.glucosa)
                Text("Comida").tag(Registro.comida)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, Tema.Espacio.margenLateral)
            .padding(.vertical, Tema.Espacio.unidad * 2)
            .background(Tema.Colores.fondo)
            .accessibilityIdentifier("selectorDeRegistro")
        }
    }
}
