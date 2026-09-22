import Foundation
import SwiftData

/// Las diez tablas tal como nacieron en el paso 1.
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

/// Las mismas diez, con los tres campos que pide RF-05b en `LecturaGlucosa`:
/// `valorLeidoOcr`, `fueCorregido` y `confianzaOcr`.
nonisolated enum EsquemaGlucyV2: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [Perfil.self, LecturaGlucosa.self, Comida.self, DosisInsulina.self,
         EventoContexto.self, Alerta.self, PrediccionCache.self, ProductoCache.self,
         ColaSincronizacion.self, ColaXapi.self]
    }
}

/// El plan se dejó escrito en el paso 2 «para cuando llegue la segunda versión». Llegó.
///
/// **Por qué versionar y no simplemente agregar los campos:** si el modelo cambia sin que
/// exista un camino de migración, SwiftData no sabe abrir la base vieja y **la borra al
/// arrancar**. En desarrollo es una molestia; en las pruebas de campo de la fase 7, con
/// semanas de datos de una persona real, es un desastre que no se puede deshacer.
nonisolated enum PlanMigracionGlucy: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [EsquemaGlucyV1.self, EsquemaGlucyV2.self]
    }

    /// Ligera: los tres campos nuevos son opcionales o traen valor por omisión, así que
    /// SwiftData puede migrar sin que nadie escriba cómo rellenar las filas existentes.
    static var stages: [MigrationStage] {
        [.lightweight(fromVersion: EsquemaGlucyV1.self, toVersion: EsquemaGlucyV2.self)]
    }
}
