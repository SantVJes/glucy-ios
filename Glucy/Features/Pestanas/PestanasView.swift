import SwiftUI

/// La carcasa de la app: cuatro pestañas, profundidad máxima dos niveles.
///
/// Existe desde este paso y no desde el paso 8 porque, si no, la pantalla de registro
/// tendría que ser la raíz de la app y habría que desmontarla después.
///
/// En este paso solo **Registrar** hace algo. Las otras tres enseñan su estado vacío con su
/// texto: nunca un cero ni una pantalla en blanco.
struct PestanasView: View {
    @Environment(ContenedorDependencias.self) private var dependencias

    var body: some View {
        TabView {
            PendienteView(
                titulo: "Inicio",
                mensaje: "Todavía no tengo lecturas tuyas.",
                icono: "drop"
            )
            .tabItem { Label("Inicio", systemImage: "house") }

            RegistroGlucosaView(
                registrar: dependencias.registrarManual,
                registrarPorFoto: dependencias.registrarPorFoto,
                ocr: dependencias.ocr
            )
            .tabItem { Label("Registrar", systemImage: "plus.circle") }

            PendienteView(
                titulo: "Historial",
                mensaje: "Necesito al menos tres días de datos para calcular tu tiempo en rango.",
                icono: "chart.xyaxis.line"
            )
            .tabItem { Label("Historial", systemImage: "chart.xyaxis.line") }

            PendienteView(
                titulo: "Ajustes",
                mensaje: "Aquí van a estar tus umbrales y tu perfil.",
                icono: "gearshape"
            )
            .tabItem { Label("Ajustes", systemImage: "gearshape") }
        }
        .tint(Tema.Colores.azulPrimario)
    }
}
