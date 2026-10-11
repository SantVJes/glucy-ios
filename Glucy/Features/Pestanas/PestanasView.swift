import SwiftUI

/// Las cuatro pestañas de la app.
enum Pestana: Hashable {
    case inicio, registrar, historial, ajustes
}

/// La carcasa de la app: cuatro pestañas, profundidad máxima dos niveles.
///
/// **Ajustes** todavía enseña su estado vacío con su texto: nunca un cero ni una pantalla en
/// blanco.
struct PestanasView: View {
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

            HistorialView(consultar: dependencias.consultarHistorial)
                .tabItem { Label("Historial", systemImage: "chart.xyaxis.line") }
                .tag(Pestana.historial)

            PendienteView(
                titulo: "Ajustes",
                mensaje: "Aquí van a estar tus umbrales y tu perfil.",
                icono: "gearshape"
            )
            .tabItem { Label("Ajustes", systemImage: "gearshape") }
            .tag(Pestana.ajustes)
        }
        .tint(Tema.Colores.azulPrimario)
    }
}
