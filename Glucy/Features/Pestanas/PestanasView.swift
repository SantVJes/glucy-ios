import SwiftUI

/// Las cuatro pestañas de la app.
enum Pestana: Hashable {
    case inicio, registrar, historial, ajustes
}

/// La carcasa de la app: cuatro pestañas, profundidad máxima dos niveles.
struct PestanasView: View {
    /// Después de borrar la cuenta la raíz vuelve al splash y al alta.
    let alBorrarCuenta: () -> Void

    @Environment(ContenedorDependencias.self) private var dependencias
    @State private var pestana = Pestana.inicio
    /// Arranca en glucosa, que es lo que se registra con más prisa.
    @State private var registro = TipoDeRegistro.glucosa

    var body: some View {
        TabView(selection: $pestana) {
            InicioView(
                consultar: dependencias.consultarInicio,
                sincronizar: dependencias.sincronizarSensor,
                ajustes: dependencias.ajustesDeInsulina,
                pedirAlServidor: dependencias.pedirFactoresYExplicacion,
                alAnotar: { tipo in
                    registro = tipo
                    pestana = .registrar
                }
            )
            .tabItem { Label("Inicio", systemImage: "house") }
            .tag(Pestana.inicio)

            RegistrarView(registro: $registro)
                .tabItem { Label("Registrar", systemImage: "plus.circle") }
                .tag(Pestana.registrar)

            HistorialView(
                consultar: dependencias.consultarHistorial, armarInforme: dependencias.armarInforme
            )
                .tabItem { Label("Historial", systemImage: "chart.xyaxis.line") }
                .tag(Pestana.historial)

            AjustesView(
                guardar: dependencias.guardarAjustes,
                pendientes: dependencias.consultarColaPendiente,
                completarAlta: dependencias.completarAlta,
                sincronizar: dependencias.sincronizarSensor,
                candado: dependencias.candado,
                cuantoHay: dependencias.consultarCuantoHay,
                borrarTodo: dependencias.borrarTodo,
                subirAlBackend: dependencias.subirAlBackend,
                alBorrarCuenta: alBorrarCuenta
            )
            .tabItem { Label("Ajustes", systemImage: "gearshape") }
            .tag(Pestana.ajustes)
        }
        .tint(Tema.Colores.azulPrimario)
    }
}
