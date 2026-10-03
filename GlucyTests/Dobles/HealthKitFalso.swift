import Foundation
@testable import Glucy

/// Una Salud de mentira, para probar los casos de uso sin dispositivo. No importa HealthKit:
/// la integración continua no lo tiene.
///
/// Imita lo que importa de una consulta ancorada. Guarda todas las muestras que «escribió
/// el fabricante» y el ancla es la posición hasta donde ya se entregó, así que una consulta
/// con el ancla de la anterior trae solo lo que llegó después.
actor HealthKitFalso: ServicioHealthKit {
    nonisolated let disponible: Bool

    /// Lo que va a lanzar cualquier lectura. Así llega la revocación del permiso, un sensor
    /// apagado o Salud caída (RF-07, caso P-09).
    private var falloDeLectura: (any Error)?

    private var enSalud: [MuestraGlucosa] = []
    private(set) var anclasRecibidas: [Data?] = []
    private(set) var escritas: [LecturaGlucosaDato] = []
    private(set) var eliminadas: [UUID] = []

    init(disponible: Bool = true) {
        self.disponible = disponible
    }

    /// El fabricante escribió estas muestras en Salud.
    func agregar(_ muestras: [MuestraGlucosa]) {
        enSalud.append(contentsOf: muestras)
    }

    func fallarLecturas(con error: any Error) {
        falloDeLectura = error
    }

    func pedirPermisos() async throws {}

    func muestrasNuevas(desde ancla: Data?) async throws -> LoteMuestras {
        anclasRecibidas.append(ancla)
        if let falloDeLectura { throw falloDeLectura }

        let desde = ancla.map(Self.posicion) ?? 0
        return LoteMuestras(
            muestras: Array(enSalud[desde...]),
            ancla: Self.ancla(en: enSalud.count),
            hayMas: false
        )
    }

    func observarGlucosa(alLlegarMuestras: @escaping @Sendable () async -> Void) async throws {}

    func escribirGlucosa(_ dato: LecturaGlucosaDato) async throws {
        escritas.append(dato)
    }

    func eliminarGlucosa(uuid: UUID) async throws {
        eliminadas.append(uuid)
    }

    func escribirCarbohidratos(gramos: Double, ts: Date) async throws {}

    func escribirInsulina(unidades: Double, ts: Date, tipo: TipoInsulina) async throws {}

    func unidadPreferida() async throws -> UnidadGlucosa { .mgDl }

    private static func ancla(en posicion: Int) -> Data {
        Data(String(posicion).utf8)
    }

    private static func posicion(_ ancla: Data) -> Int {
        Int(String(decoding: ancla, as: UTF8.self)) ?? 0
    }
}

/// Lo que lanza Salud cuando la persona quita el permiso. Cualquier error sirve: al caso de
/// uso no le importa por qué no respondió.
struct PermisoRevocado: Error {}
