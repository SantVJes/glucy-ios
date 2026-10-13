#if DEBUG
import Foundation

/// Salud para las pruebas de interfaz: lee de verdad y **no escribe ni borra nada**.
///
/// Las pruebas de interfaz corren con la base en memoria para no tocar los datos de quien las
/// corre en su propio teléfono. Sin esto, la glucosa, los carbohidratos y las dosis que una
/// prueba «registra» se copiarían a la app Salud de esa persona, y una prueba que borrara la
/// cuenta se llevaría lo que Glucy escribió ahí de verdad.
///
/// La lectura pasa tal cual: las pruebas del sensor necesitan el Salud real del teléfono.
nonisolated struct SaludSoloLectura: ServicioHealthKit {
    let real: any ServicioHealthKit

    var disponible: Bool { real.disponible }

    func pedirPermisos() async throws { try await real.pedirPermisos() }

    func muestrasNuevas(desde ancla: Data?) async throws -> LoteMuestras {
        try await real.muestrasNuevas(desde: ancla)
    }

    func observarGlucosa(alLlegarMuestras: @escaping @Sendable () async -> Void) async throws {
        try await real.observarGlucosa(alLlegarMuestras: alLlegarMuestras)
    }

    func unidadPreferida() async throws -> UnidadGlucosa { try await real.unidadPreferida() }

    func escribirGlucosa(_ dato: LecturaGlucosaDato) async throws {}
    func eliminarGlucosa(uuid: UUID) async throws {}
    func escribirCarbohidratos(_ dato: ComidaDato) async throws {}
    func eliminarCarbohidratos(uuid: UUID) async throws {}
    func escribirInsulina(_ dato: DosisInsulinaDato) async throws {}
    func eliminarInsulina(uuid: UUID) async throws {}
    func eliminarTodoLoPropio() async throws {}
}
#endif
