import Foundation
import SwiftData

/// Las diez tablas tal como nacieron en el paso 1.
///
/// Las cinco que cambiaron después están congeladas en `EsquemasAnteriores.swift`: cada
/// versión tiene que describir la base **como era**, no como es hoy, o el plan de migración
/// no la distingue de la siguiente.
///
/// Si falta una, SwiftData no la crea y la app no se cae al arrancar sino al primer acceso:
/// el error aparece lejos de su causa y cuesta una tarde encontrarlo.
nonisolated enum EsquemaGlucyV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [EsquemaGlucyV1.Perfil.self, EsquemaGlucyV1.LecturaGlucosa.self,
         EsquemaGlucyV1.Comida.self, EsquemaGlucyV1.DosisInsulina.self, EventoContexto.self,
         Alerta.self, PrediccionCache.self, EsquemaGlucyV1.ProductoCache.self,
         ColaSincronizacion.self, ColaXapi.self]
    }
}

/// Las mismas diez, con los tres campos que pide RF-05b en `LecturaGlucosa`:
/// `valorLeidoOcr`, `fueCorregido` y `confianzaOcr`. `Comida` y `ProductoCache` siguen como en
/// la V1.
nonisolated enum EsquemaGlucyV2: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [EsquemaGlucyV1.Perfil.self, Glucy.LecturaGlucosa.self, EsquemaGlucyV1.Comida.self,
         EsquemaGlucyV1.DosisInsulina.self, EventoContexto.self, Alerta.self,
         PrediccionCache.self, EsquemaGlucyV1.ProductoCache.self, ColaSincronizacion.self,
         ColaXapi.self]
    }
}

/// Las mismas diez, con `porciones` en `Comida` —cuántas porciones se comió la persona, que
/// no es lo mismo que cuántos gramos trae una— y `encontrado` en `ProductoCache`, para poder
/// guardar también el «no lo tengo» de Open Food Facts.
nonisolated enum EsquemaGlucyV3: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(3, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [EsquemaGlucyV1.Perfil.self, LecturaGlucosa.self, Comida.self,
         EsquemaGlucyV1.DosisInsulina.self, EventoContexto.self, Alerta.self,
         PrediccionCache.self, ProductoCache.self, ColaSincronizacion.self, ColaXapi.self]
    }
}

/// Las mismas diez, con `motivo` opcional en `DosisInsulina` —lo que la persona no dijo no se
/// inventa— y `registraInsulina` en `Perfil`, para poder ocultar el registro de insulina a
/// quien no se la aplica (RF-14).
nonisolated enum EsquemaGlucyV4: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(4, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [EsquemaGlucyV4.Perfil.self, LecturaGlucosa.self, Comida.self, DosisInsulina.self,
         EventoContexto.self, Alerta.self, PrediccionCache.self, ProductoCache.self,
         ColaSincronizacion.self, ColaXapi.self]
    }
}

/// Las mismas diez, con los cinco campos que el formulario F-1 pide y el perfil no tenía: el
/// consentimiento con su fecha, la unidad preferida, el nombre de la insulina rápida, el
/// interruptor de sincronización y el del candado.
nonisolated enum EsquemaGlucyV5: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(5, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [EsquemaGlucyV5.Perfil.self, LecturaGlucosa.self, Comida.self, DosisInsulina.self,
         EventoContexto.self, Alerta.self, PrediccionCache.self, ProductoCache.self,
         ColaSincronizacion.self, ColaXapi.self]
    }
}

/// Las mismas diez, con `asistenteActivo` en `Perfil`: el interruptor del asistente de
/// explicaciones. Nace encendido, porque la frase es la mitad de lo que hace la app.
nonisolated enum EsquemaGlucyV6: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(6, 0, 0) }

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
        [EsquemaGlucyV1.self, EsquemaGlucyV2.self, EsquemaGlucyV3.self, EsquemaGlucyV4.self,
         EsquemaGlucyV5.self, EsquemaGlucyV6.self]
    }

    /// Ligeras las cinco: los campos nuevos son opcionales o traen valor por omisión, y un
    /// campo que pasa a opcional no pierde lo que tenía, así que SwiftData puede migrar sin
    /// que nadie escriba cómo rellenar las filas existentes.
    ///
    /// La quinta es la del interruptor del asistente. `asistenteActivo` nace en `true`, así
    /// que quien ya tenía la app sigue viendo la frase después de actualizar: una etapa ligera
    /// no toca las filas que ya existen, y el valor por omisión es lo que leen.
    static var stages: [MigrationStage] {
        [.lightweight(fromVersion: EsquemaGlucyV1.self, toVersion: EsquemaGlucyV2.self),
         .lightweight(fromVersion: EsquemaGlucyV2.self, toVersion: EsquemaGlucyV3.self),
         .lightweight(fromVersion: EsquemaGlucyV3.self, toVersion: EsquemaGlucyV4.self),
         .lightweight(fromVersion: EsquemaGlucyV4.self, toVersion: EsquemaGlucyV5.self),
         .lightweight(fromVersion: EsquemaGlucyV5.self, toVersion: EsquemaGlucyV6.self)]
    }
}
