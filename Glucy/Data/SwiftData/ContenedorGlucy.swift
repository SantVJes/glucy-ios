import Foundation
import SwiftData

/// Quien crea la base de datos local.
nonisolated enum ContenedorGlucy {

    /// - Parameter enMemoria: `true` en las pruebas. Cada prueba levanta su propio
    ///   contenedor, no comparte estado con la siguiente y no deja archivos en el disco.
    ///
    /// Dos decisiones que no se ven en el código:
    ///
    /// - **No se toca la protección de archivos.** La base queda con la protección por
    ///   omisión de iOS, que permite leer y escribir después del primer desbloqueo. Subirla
    ///   a «completa» cifraría el archivo con el teléfono bloqueado y la entrega en segundo
    ///   plano de HealthKit del paso 4 dejaría de poder escribir, que es justo cuando más
    ///   falta hace.
    /// - **Nada de CloudKit.** El teléfono es el dueño del dato y el backend es la copia
    ///   (regla 1); un tercer sincronizador no está en el alcance.
    /// - Parameter url: dónde vive el archivo. Solo lo pasan las pruebas de migración, que
    ///   necesitan una base de verdad en disco: en memoria no hay nada que migrar.
    static func crear(enMemoria: Bool = false, url: URL? = nil) throws -> ModelContainer {
        // Siempre la versión más reciente del esquema; el plan se encarga de las viejas.
        let esquema = Schema(versionedSchema: EsquemaGlucyV2.self)
        let configuracion = if let url {
            ModelConfiguration(schema: esquema, url: url)
        } else {
            ModelConfiguration(schema: esquema, isStoredInMemoryOnly: enMemoria)
        }
        return try ModelContainer(
            for: esquema,
            migrationPlan: PlanMigracionGlucy.self,
            configurations: configuracion
        )
    }
}
