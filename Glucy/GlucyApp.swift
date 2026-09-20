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
    }

    var body: some Scene {
        WindowGroup {
            PestanasView()
        }
        .modelContainer(contenedor)
        .environment(dependencias)
    }
}
