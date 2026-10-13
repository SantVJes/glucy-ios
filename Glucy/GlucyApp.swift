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
            contenedor = try ContenedorGlucy.crear(enMemoria: Self.baseEnMemoria)
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
        // Ya no pide ningún permiso: eso lo hace la tarjeta «Con sensor» del alta, con su
        // explicación, y se puede saltar.
        let sincronizar = dependencias.sincronizarSensor
        Task { await sincronizar.iniciar() }
    }

    /// Las pruebas de interfaz arrancan con una base en memoria: recorren el alta desde
    /// cero cada vez y no tocan los datos de quien las corre en su propio teléfono. Solo
    /// existe en la compilación de desarrollo.
    private static var baseEnMemoria: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-GlucyBaseEnMemoria")
        #else
        false
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RaizView(modelo: RaizViewModel(
                consultar: dependencias.consultarEntrada,
                candado: dependencias.candado,
                sincronizar: dependencias.sincronizarSensor
            ))
        }
        .modelContainer(contenedor)
        .environment(dependencias)
    }
}
