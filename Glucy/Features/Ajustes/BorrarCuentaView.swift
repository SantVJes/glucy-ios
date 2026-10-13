import SwiftUI

/// El estado de la barrera de borrado.
@Observable
final class BorrarCuentaViewModel {
    /// Las cifras de verdad. `nil` mientras se leen.
    private(set) var cuanto: CuantoHay?
    var textoDeConfirmacion = ""
    private(set) var borrando = false
    /// Lo local se borró, pero Salud no respondió. Se dice antes de salir.
    private(set) var saludQuedoSinLimpiar = false
    private(set) var fallo: String?

    /// La palabra que hay que teclear. Ni una casilla ni un toque largo.
    static let palabra = "borrar"

    private let cuantoHay: ConsultarCuantoHay
    private let borrarTodo: BorrarTodo

    init(cuantoHay: ConsultarCuantoHay, borrarTodo: BorrarTodo) {
        self.cuantoHay = cuantoHay
        self.borrarTodo = borrarTodo
    }

    func cargar() async {
        cuanto = try? await cuantoHay.ejecutar()
    }

    var puedeBorrar: Bool {
        textoDeConfirmacion.trimmingCharacters(in: .whitespaces).lowercased() == Self.palabra
            && !borrando
    }

    /// «Vas a borrar 412 lecturas, 96 comidas y 140 dosis, tu perfil y tus ajustes.»
    var textoDeLoQueSePierde: String {
        guard let cuanto else { return "Vas a borrar tus lecturas, tus comidas y tus dosis, tu perfil y tus ajustes." }
        let lecturas = cuanto.lecturas == 1 ? "1 lectura" : "\(cuanto.lecturas) lecturas"
        let comidas = cuanto.comidas == 1 ? "1 comida" : "\(cuanto.comidas) comidas"
        return "Vas a borrar \(lecturas), \(comidas) y \(cuanto.dosis) dosis, tu perfil y tus ajustes."
    }

    /// `true` si ya se puede salir sin decir nada más.
    func borrar() async -> Bool {
        guard puedeBorrar else { return false }
        borrando = true
        defer { borrando = false }
        do {
            let resultado = try await borrarTodo.ejecutar()
            saludQuedoSinLimpiar = !resultado.saludLimpia
            return resultado.saludLimpia
        } catch {
            fallo = "No se pudo borrar. No se perdió nada: inténtalo otra vez."
            return false
        }
    }
}

/// La barrera de borrar la cuenta: la única de la app, porque es lo único irreversible.
///
/// Enumera lo que se pierde con sus cifras y obliga a teclear la palabra. Un «¿estás seguro?»
/// sin números no informa de nada.
struct BorrarCuentaView: View {
    @State private var modelo: BorrarCuentaViewModel
    @FocusState private var tecladoAbierto: Bool
    private let alBorrar: () -> Void

    init(cuantoHay: ConsultarCuantoHay, borrarTodo: BorrarTodo, alBorrar: @escaping () -> Void) {
        self.alBorrar = alBorrar
        _modelo = State(initialValue: BorrarCuentaViewModel(cuantoHay: cuantoHay, borrarTodo: borrarTodo))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tema.Espacio.entreTarjetas) {
                if modelo.saludQuedoSinLimpiar {
                    yaBorrado
                } else {
                    barrera
                }
            }
            .padding(.horizontal, Tema.Espacio.margenLateral)
            .padding(.vertical, Tema.Espacio.margenLateral)
        }
        .background(Tema.Colores.fondo)
        .navigationTitle("Borrar mi cuenta")
        .navigationBarTitleDisplayMode(.inline)
        // Con el borrado hecho ya no hay a dónde regresar.
        .navigationBarBackButtonHidden(modelo.saludQuedoSinLimpiar || modelo.borrando)
        .task { await modelo.cargar() }
    }

    private var barrera: some View {
        VStack(alignment: .leading, spacing: Tema.Espacio.entreTarjetas) {
            VStack(alignment: .leading, spacing: Tema.Espacio.unidad * 3) {
                Text(modelo.textoDeLoQueSePierde + " También quito de Salud lo que Glucy escribió; "
                    + "lo que escribió la app de tu sensor se queda.")
                    .font(Tema.Tipografia.textoLectura)
                    .foregroundStyle(Tema.Colores.textoPrincipal)
                    .accessibilityIdentifier("loQueSePierde")
                Text("Esto no se puede deshacer y no hay copia en ningún servidor.")
                    .font(Tema.Tipografia.valorFila)
                    .foregroundStyle(Tema.Colores.textoPrincipal)
                Text(LocalizedStringKey("Escribe **\(BorrarCuentaViewModel.palabra)** para confirmar."))
                    .font(Tema.Tipografia.textoLectura)
                    .foregroundStyle(Tema.Colores.textoPrincipal)

                TextField("", text: $modelo.textoDeConfirmacion)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(Tema.Tipografia.tituloTarjeta)
                    .foregroundStyle(Tema.Colores.textoPrincipal)
                    .focused($tecladoAbierto)
                    .frame(minHeight: Tema.Medida.areaTocable)
                    .padding(.horizontal, Tema.Espacio.unidad * 3)
                    .background(Tema.Colores.fondo)
                    .clipShape(RoundedRectangle(cornerRadius: Tema.Radio.campo))
                    .accessibilityLabel("Escribe la palabra borrar para confirmar")
                    .accessibilityIdentifier("campoConfirmarBorrado")

                if let fallo = modelo.fallo {
                    Label(fallo, systemImage: "exclamationmark.triangle.fill")
                        .font(Tema.Tipografia.etiqueta)
                        .foregroundStyle(Tema.Colores.hipoglucemia)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(Tema.Espacio.interior)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Tema.Colores.superficie)
            .clipShape(RoundedRectangle(cornerRadius: Tema.Radio.tarjetaGrande))

            BotonPrincipal(
                titulo: "Borrar mi cuenta", activo: modelo.puedeBorrar, ocupado: modelo.borrando,
                destructivo: true, identificador: "botonBorrarCuenta"
            ) {
                tecladoAbierto = false
                Task {
                    if await modelo.borrar() { alBorrar() }
                }
            }
        }
    }

    /// Lo local ya no existe; lo de Salud no se pudo quitar. Media verdad dicha es mejor que
    /// un borrado que finge haber terminado.
    private var yaBorrado: some View {
        VStack(alignment: .leading, spacing: Tema.Espacio.entreTarjetas) {
            Text("Borré todo lo de Glucy. No pude borrar lo que había escrito en Salud; puedes "
                + "quitarlo desde la app Salud.")
                .font(Tema.Tipografia.textoLectura)
                .foregroundStyle(Tema.Colores.textoPrincipal)
                .fixedSize(horizontal: false, vertical: true)
                .padding(Tema.Espacio.interior)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Tema.Colores.superficie)
                .clipShape(RoundedRectangle(cornerRadius: Tema.Radio.tarjetaGrande))
                .accessibilityIdentifier("saludSinLimpiar")

            BotonPrincipal(titulo: "Entendido", identificador: "botonEntendidoBorrado", accion: alBorrar)
        }
    }
}
