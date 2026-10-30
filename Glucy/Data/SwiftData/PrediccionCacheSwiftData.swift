import Foundation
import SwiftData

/// La caché de predicciones sobre SwiftData.
///
/// **Una fila por horizonte**: guardar reemplaza en lugar de insertar. Sin eso la tabla
/// crecería una fila por minuto —la pantalla se recalcula cada minuto— y en una semana
/// tendría diez mil filas de las que solo dos valen.
///
/// No encola para subir: la predicción que le importa al backend es la que él mismo genera, y
/// devolverle la del teléfono sería un viaje redondo sin valor.
@ModelActor
actor PrediccionCacheSwiftData: RepositorioPrediccionCache {

    func guardar(_ dato: PrediccionGuardadaDato) throws {
        let horizonte = dato.horizonteMin
        var descriptor = FetchDescriptor<PrediccionCache>(
            predicate: #Predicate { $0.horizonteMin == horizonte }
        )
        descriptor.fetchLimit = 1

        let json = FactoresSerializados.json(factores: dato.factores, shap: dato.shap)
        if let fila = try modelContext.fetch(descriptor).first {
            fila.tsUtc = dato.tsUtc
            fila.zonaHoraria = dato.zonaHoraria
            fila.valorMgDl = dato.valorMgDl
            fila.modo = dato.modo
            fila.versionModelo = dato.versionModelo
            // La explicación nueva solo pisa a la anterior si llegó: una pasada sin red no
            // tiene por qué borrar la frase que ya se había guardado.
            if let explicacion = dato.explicacion { fila.explicacion = explicacion }
            if let json { fila.shapJson = json }
        } else {
            modelContext.insert(PrediccionCache(
                uuid: dato.uuid,
                tsUtc: dato.tsUtc,
                zonaHoraria: dato.zonaHoraria,
                horizonteMin: dato.horizonteMin,
                valorMgDl: dato.valorMgDl,
                modo: dato.modo,
                versionModelo: dato.versionModelo,
                explicacion: dato.explicacion,
                shapJson: json
            ))
        }
        try modelContext.save()
    }

    func ultima(horizonteMin: Int) throws -> PrediccionGuardadaDato? {
        var descriptor = FetchDescriptor<PrediccionCache>(
            predicate: #Predicate { $0.horizonteMin == horizonteMin }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first.map(Self.dato)
    }

    func todas() throws -> [PrediccionGuardadaDato] {
        try modelContext
            .fetch(FetchDescriptor<PrediccionCache>(
                sortBy: [SortDescriptor(\.horizonteMin, order: .forward)]
            ))
            .map(Self.dato)
    }

    func eliminarTodo() throws {
        for fila in try modelContext.fetch(FetchDescriptor<PrediccionCache>()) {
            modelContext.delete(fila)
        }
        try modelContext.save()
    }

    /// El puente a valor vive aquí y no junto al `@Model` porque las dos listas salen de
    /// deserializar un campo de texto, que es cosa de esta capa y no del modelo.
    private static func dato(_ fila: PrediccionCache) -> PrediccionGuardadaDato {
        let guardado = FactoresSerializados.desde(json: fila.shapJson)
        return PrediccionGuardadaDato(
            uuid: fila.uuid,
            tsUtc: fila.tsUtc,
            zonaHoraria: fila.zonaHoraria,
            horizonteMin: fila.horizonteMin,
            valorMgDl: fila.valorMgDl,
            modo: fila.modo,
            versionModelo: fila.versionModelo,
            explicacion: fila.explicacion,
            factores: guardado?.comoFactores ?? [],
            shap: guardado?.shap ?? []
        )
    }
}
