//
//  GlucyApp.swift
//  Glucy
//
//  Created by Jesus Santiago Velasco on 19/09/26.
//

import SwiftUI
import SwiftData

@main
struct GlucyApp: App {
    private let contenedor: ModelContainer
    private let dependencias: ContenedorDependencias

    init() {
        do {
            contenedor = try ContenedorGlucy.crear()
        } catch {
            // Sin base local no hay app: el teléfono es el dueño del dato (regla 1) y todo
            // lo demás se apoya en esto. Caerse aquí, al arrancar, es preferible a caerse
            // más tarde con el error lejos de su causa.
            fatalError("No se pudo abrir la base de datos local: \(error)")
        }
        dependencias = ContenedorDependencias(contenedor: contenedor)

        // Aquí y no en una vista: cuando iOS despierta la app en segundo plano por una
        // muestra nueva no se dibuja ninguna pantalla, y el observador tiene que quedar
        // registrado en el arranque o esa entrega se pierde (RF-06).
        //
        // Pedir el permiso al arrancar es provisional: el onboarding del paso 9 lo va a
        // pedir con su explicación y permitirá saltárselo. Si ya se contestó, iOS no vuelve
        // a mostrar la hoja.
        let sincronizar = dependencias.sincronizarSensor
        Task { await sincronizar.iniciar() }
    }

    var body: some Scene {
        WindowGroup {
            PestanasView()
        }
        .modelContainer(contenedor)
        .environment(dependencias)
    }
}
