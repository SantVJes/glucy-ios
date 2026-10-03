import Foundation
import HealthKit

/// La única implementación de `ServicioHealthKit`, y el único archivo de la app que importa
/// HealthKit. Lo demás habla con el protocolo, y por eso las pruebas corren sin Salud.
nonisolated final class HealthKitReal: ServicioHealthKit, @unchecked Sendable {
    // `@unchecked` porque `HKHealthStore` no está marcado `Sendable` en todas las versiones
    // del SDK, aunque Apple documenta que es seguro usarlo desde cualquier hilo. No hay
    // ningún estado mutable propio: todo es `let`.
    private let store = HKHealthStore()

    /// La primera consulta, sin ancla, puede traer años de sensor. Por lotes se guarda sin
    /// cargarlos todos en memoria.
    private static let tamanoLote = 500

    private static let mgDl = HKUnit.gramUnit(with: .milli).unitDivided(by: .literUnit(with: .deci))

    private let tipoGlucosa = HKQuantityType(.bloodGlucose)
    private let tipoCarbohidratos = HKQuantityType(.dietaryCarbohydrates)
    private let tipoInsulina = HKQuantityType(.insulinDelivery)

    var disponible: Bool { HKHealthStore.isHealthDataAvailable() }

    // MARK: - Permisos

    func pedirPermisos() async throws {
        guard disponible else { throw ErrorHealthKit.noDisponible }
        // Se lee solo glucosa. Se escribe glucosa, carbohidratos e insulina: lo que Glucy
        // captura. La hoja de Salud los muestra por separado y la persona elige cada uno.
        try await store.requestAuthorization(
            toShare: [tipoGlucosa, tipoCarbohidratos, tipoInsulina],
            read: [tipoGlucosa]
        )
    }

    // MARK: - Lectura

    func muestrasNuevas(desde ancla: Data?) async throws -> LoteMuestras {
        guard disponible else { throw ErrorHealthKit.noDisponible }

        let descriptor = HKAnchoredObjectQueryDescriptor(
            predicates: [.quantitySample(type: tipoGlucosa)],
            anchor: ancla.flatMap(Self.deserializar),
            limit: Self.tamanoLote
        )
        let resultado = try await descriptor.result(for: store)

        // Las borradas en Salud (`resultado.deletedObjects`) no se tocan en el teléfono: el
        // teléfono es el dueño del dato y un borrado del otro lado no es una instrucción.
        let propia = HKSource.default()
        let muestras = resultado.addedSamples.map { muestra in
            MuestraGlucosa(
                uuid: muestra.uuid,
                // HealthKit convierte a mg/dL aunque la persona vea mmol/L en Salud: la
                // cantidad se guarda sin unidad de presentación.
                valor: muestra.quantity.doubleValue(for: Self.mgDl),
                unidad: .mgDl,
                ts: muestra.startDate,
                zonaHoraria: muestra.metadata?[HKMetadataKeyTimeZone] as? String,
                contexto: Self.contexto(desde: muestra.metadata),
                // Por el `HKSource` y no por el origen: una muestra que Glucy escribió
                // vuelve en la consulta, y guardarla otra vez sería el primer paso de la
                // serie duplicada (RF-15b, caso P-14).
                esPropia: muestra.sourceRevision.source.bundleIdentifier == propia.bundleIdentifier
            )
        }

        return LoteMuestras(
            muestras: muestras,
            ancla: Self.serializar(resultado.newAnchor),
            hayMas: resultado.addedSamples.count + resultado.deletedObjects.count >= Self.tamanoLote
        )
    }

    func observarGlucosa(alLlegarMuestras: @escaping @Sendable () async -> Void) async throws {
        guard disponible else { throw ErrorHealthKit.noDisponible }

        let consulta = HKObserverQuery(sampleType: tipoGlucosa, predicate: nil) { _, terminar, error in
            let terminar = TerminarObservador(terminar)
            Task {
                // Se llama siempre, también si la consulta falló. Si no se llama, iOS deja
                // de despertar la app en segundo plano sin avisar, y días después nadie
                // entiende por qué ya no se actualiza sola (paso 4, apartado 2.4).
                defer { terminar.llamar() }
                guard error == nil else { return }
                await alLlegarMuestras()
            }
        }
        store.execute(consulta)
        try await store.enableBackgroundDelivery(for: tipoGlucosa, frequency: .immediate)
    }

    // MARK: - Escritura

    func escribirGlucosa(_ dato: LecturaGlucosaDato) async throws {
        guard disponible else { throw ErrorHealthKit.noDisponible }

        var metadatos: [String: Any] = Self.metadatosDeSincronizacion(uuid: dato.uuid)
        metadatos[HKMetadataKeyTimeZone] = dato.zonaHoraria
        if let comida = Self.momentoComida(desde: dato.contexto) {
            metadatos[HKMetadataKeyBloodGlucoseMealTime] = comida.rawValue
        }

        let muestra = HKQuantitySample(
            type: tipoGlucosa,
            quantity: HKQuantity(unit: Self.mgDl, doubleValue: dato.mgDl),
            start: dato.tsUtc,
            end: dato.tsUtc,
            metadata: metadatos
        )
        try await store.save(muestra)
    }

    func eliminarGlucosa(uuid: UUID) async throws {
        guard disponible else { throw ErrorHealthKit.noDisponible }

        // Por el identificador que Glucy le puso y **solo entre lo que Glucy escribió**:
        // un deshacer nunca puede borrar una muestra del fabricante.
        let predicado = NSCompoundPredicate(andPredicateWithSubpredicates: [
            HKQuery.predicateForObjects(from: HKSource.default()),
            HKQuery.predicateForObjects(
                withMetadataKey: HKMetadataKeySyncIdentifier,
                allowedValues: [uuid.uuidString]
            ),
        ])
        _ = try await store.deleteObjects(of: tipoGlucosa, predicate: predicado)
    }

    func escribirCarbohidratos(gramos: Double, ts: Date) async throws {
        guard disponible else { throw ErrorHealthKit.noDisponible }
        let muestra = HKQuantitySample(
            type: tipoCarbohidratos,
            quantity: HKQuantity(unit: .gram(), doubleValue: gramos),
            start: ts,
            end: ts,
            metadata: [HKMetadataKeyTimeZone: TimeZone.current.identifier]
        )
        try await store.save(muestra)
    }

    func escribirInsulina(unidades: Double, ts: Date, tipo: TipoInsulina) async throws {
        guard disponible else { throw ErrorHealthKit.noDisponible }
        let motivo: HKInsulinDeliveryReason = switch tipo {
        case .bolo: .bolus
        case .basal: .basal
        }
        let muestra = HKQuantitySample(
            type: tipoInsulina,
            quantity: HKQuantity(unit: .internationalUnit(), doubleValue: unidades),
            start: ts,
            end: ts,
            // HealthKit rechaza una muestra de insulina sin este metadato.
            metadata: [
                HKMetadataKeyInsulinDeliveryReason: motivo.rawValue,
                HKMetadataKeyTimeZone: TimeZone.current.identifier,
            ]
        )
        try await store.save(muestra)
    }

    // MARK: - Unidades

    func unidadPreferida() async throws -> UnidadGlucosa {
        guard disponible else { throw ErrorHealthKit.noDisponible }
        let unidades = try await store.preferredUnits(for: [tipoGlucosa])
        guard let unidad = unidades[tipoGlucosa] else { return .mgDl }
        return unidad == Self.mgDl ? .mgDl : .mmolL
    }

    // MARK: - Traducciones

    /// El UUID de la lectura como identificador de sincronización de HealthKit. Con él,
    /// escribir dos veces la misma lectura reemplaza la muestra en lugar de duplicarla, y
    /// el deshacer sabe cuál borrar.
    private static func metadatosDeSincronizacion(uuid: UUID) -> [String: Any] {
        [
            HKMetadataKeySyncIdentifier: uuid.uuidString,
            HKMetadataKeySyncVersion: 1,
        ]
    }

    /// Salud solo distingue antes y después de comer. «Antes de dormir» y «otro» no tienen
    /// equivalente y viajan sin el metadato en lugar de forzarlos a uno que no es.
    private static func momentoComida(desde contexto: ContextoComida?) -> HKBloodGlucoseMealTime? {
        switch contexto {
        case .enAyunas, .antesDeComer: .preprandial
        case .dosHorasDespues: .postprandial
        case .antesDeDormir, .otro, nil: nil
        }
    }

    private static func contexto(desde metadatos: [String: Any]?) -> ContextoComida? {
        guard let valor = metadatos?[HKMetadataKeyBloodGlucoseMealTime] as? NSNumber,
              let momento = HKBloodGlucoseMealTime(rawValue: valor.intValue) else { return nil }
        return switch momento {
        case .preprandial: .antesDeComer
        case .postprandial: .dosHorasDespues
        @unknown default: nil
        }
    }

    private static func serializar(_ ancla: HKQueryAnchor) -> Data? {
        try? NSKeyedArchiver.archivedData(withRootObject: ancla, requiringSecureCoding: true)
    }

    /// Un ancla ilegible vale lo mismo que ninguna: se trae todo y la idempotencia del
    /// repositorio descarta lo que ya estaba.
    private static func deserializar(_ datos: Data) -> HKQueryAnchor? {
        try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: datos)
    }
}

/// El `completionHandler` del observador, para poder llevarlo a un `Task`. HealthKit no lo
/// declara `Sendable`, pero está hecho para llamarse desde cualquier hilo, una vez.
private nonisolated struct TerminarObservador: @unchecked Sendable {
    let llamar: () -> Void
    init(_ llamar: @escaping () -> Void) { self.llamar = llamar }
}
