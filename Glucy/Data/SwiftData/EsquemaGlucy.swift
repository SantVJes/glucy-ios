import Foundation
import SwiftData

/// Las diez tablas del paso 1, declaradas juntas.
///
/// Si falta una, SwiftData no la crea y la app no se cae al arrancar sino al primer acceso:
/// el error aparece lejos de su causa y cuesta una tarde encontrarlo.
nonisolated enum EsquemaGlucyV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [Perfil.self, LecturaGlucosa.self, Comida.self, DosisInsulina.self,
         EventoContexto.self, Alerta.self, PrediccionCache.self, ProductoCache.self,
         ColaSincronizacion.self, ColaXapi.self]
    }
}

/// Hay una sola versión, pero el plan existe desde hoy: cuando llegue la segunda, el camino
/// de migración ya tiene dónde escribirse y los datos de las pruebas de campo no se pierden.
nonisolated enum PlanMigracionGlucy: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [EsquemaGlucyV1.self] }
    static var stages: [MigrationStage] { [] }
}
