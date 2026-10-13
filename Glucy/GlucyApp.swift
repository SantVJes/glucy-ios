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
        dependencias = Self.dependencias(sobre: contenedor)

        // Aquí y no en una vista: cuando iOS despierta la app en segundo plano por una
        // muestra nueva no se dibuja ninguna pantalla, y el observador tiene que quedar
        // registrado en el arranque o esa entrega se pierde (RF-06).
        //
        // Ya no pide ningún permiso: eso lo hace la tarjeta «Con sensor» del alta, con su
        // explicación, y se puede saltar.
        let sincronizar = dependencias.sincronizarSensor
        Task { await sincronizar.iniciar() }
    }

    /// Con la base en memoria, que es como corren las pruebas de interfaz, tampoco se toca lo
    /// demás que es de la persona: nada se escribe ni se borra en su app Salud, y el ancla
    /// de la lectura del sensor es otra, para que una prueba no mueva la de verdad y la app
    /// deje de recibir lecturas que nunca guardó.
    private static func dependencias(sobre contenedor: ModelContainer) -> ContenedorDependencias {
        #if DEBUG
        if baseEnMemoria {
            let ancla = AnclaHealthKit(dominio: "pruebas-de-interfaz")
            // Cada arranque de prueba empieza sin ancla, igual que empieza sin base.
            ancla.borrar()
            return ContenedorDependencias(
                contenedor: contenedor, salud: SaludSoloLectura(real: HealthKitReal()), ancla: ancla
            )
        }
        #endif
        return ContenedorDependencias(contenedor: contenedor)
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
