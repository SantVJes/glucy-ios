import Foundation
import SwiftData

/// Quién le da los repositorios a quién.
///
/// Se crea una vez en `GlucyApp` y se inyecta con `.environment(...)`. Las pantallas piden
/// el protocolo, nunca la implementación: por eso en las pruebas se puede meter una falsa
/// sin levantar SwiftData.
@Observable
final class ContenedorDependencias {
    let perfil: any RepositorioPerfil
    let lecturas: any RepositorioLecturas
    let comidas: any RepositorioComidas
    let dosis: any RepositorioDosis
    let cola: any RepositorioCola
    /// Salud, detrás de su protocolo. Nadie fuera de `Data/HealthKit/` sabe que existe
    /// HealthKit.
    let salud: any ServicioHealthKit
    let sincronizarSensor: SincronizarLecturasDelSensor

    init(
        contenedor: ModelContainer,
        salud: any ServicioHealthKit = HealthKitReal(),
        ancla: AnclaHealthKit = AnclaHealthKit()
    ) {
        perfil = PerfilSwiftData(modelContainer: contenedor)
        let lecturas = LecturasSwiftData(modelContainer: contenedor)
        self.lecturas = lecturas
        comidas = ComidasSwiftData(modelContainer: contenedor)
        dosis = DosisSwiftData(modelContainer: contenedor)
        cola = ColaSwiftData(modelContainer: contenedor)
        self.salud = salud
        sincronizarSensor = SincronizarLecturasDelSensor(
            servicio: salud, lecturas: lecturas, ancla: ancla
        )
    }

    /// La captura manual con su copia en Salud.
    var registrarManual: RegistrarLecturaManual {
        RegistrarLecturaManual(
            repositorio: lecturas,
            salud: EscribirEnHealthKit(servicio: salud, lecturas: lecturas)
        )
    }

    /// Para las pruebas y las vistas previas: contenedor en memoria, sin tocar el disco.
    static func enMemoria() throws -> ContenedorDependencias {
        ContenedorDependencias(contenedor: try ContenedorGlucy.crear(enMemoria: true))
    }
}
