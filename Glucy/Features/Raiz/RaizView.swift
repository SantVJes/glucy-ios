import SwiftUI

/// La raíz de la app: splash, después el alta o las pestañas, y encima el candado.
struct RaizView: View {
    @Environment(ContenedorDependencias.self) private var dependencias
    @Environment(\.scenePhase) private var fase
    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento
    @State private var modelo: RaizViewModel

    init(modelo: RaizViewModel) {
        _modelo = State(initialValue: modelo)
    }

    var body: some View {
        ZStack {
            switch modelo.pantalla {
            case .splash:
                SplashView()
            case .alta:
                AltaView(completar: dependencias.completarAlta) {
                    Task { await modelo.altaCompletada() }
                }
            case .dentro:
                PestanasView {
                    Task { await modelo.cuentaBorrada() }
                }
            }

            if modelo.bloqueada {
                CandadoView {
                    Task { await modelo.pedirEntrada() }
                }
            }
        }
        // El splash se desvanece; con «reducir movimiento», desaparece.
        .animation(reducirMovimiento ? nil : .easeOut(duration: 0.25), value: modelo.pantalla)
        .animation(reducirMovimiento ? nil : .easeOut(duration: 0.2), value: modelo.bloqueada)
        .task { await modelo.arrancar() }
        .onChange(of: fase) { _, nueva in
            switch nueva {
            case .background: modelo.salioASegundoPlano()
            case .active: Task { await modelo.volvio() }
            default: break
            }
        }
    }
}
