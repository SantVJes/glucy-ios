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
    /// El OCR, detrás de su protocolo. Nadie fuera de `Data/OCR/` sabe que existe Vision.
    let ocr: any ServicioOCR
    /// La base de productos, detrás de su protocolo. Nadie fuera de `Data/Network/` sabe
    /// que existe Open Food Facts.
    let servicioProductos: any ServicioProductos
    let productos: any RepositorioProductos

    init(
        contenedor: ModelContainer,
        salud: any ServicioHealthKit = HealthKitReal(),
        ancla: AnclaHealthKit = AnclaHealthKit(),
        ocr: any ServicioOCR = VisionOCR(),
        servicioProductos: any ServicioProductos = OpenFoodFactsHTTP()
    ) {
        perfil = PerfilSwiftData(modelContainer: contenedor)
        let lecturas = LecturasSwiftData(modelContainer: contenedor)
        self.lecturas = lecturas
        comidas = ComidasSwiftData(modelContainer: contenedor)
        dosis = DosisSwiftData(modelContainer: contenedor)
        cola = ColaSwiftData(modelContainer: contenedor)
        self.salud = salud
        self.ocr = ocr
        self.servicioProductos = servicioProductos
        productos = ProductosSwiftData(modelContainer: contenedor)
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

    /// La captura por foto con su copia en Salud. El origen `.fotoGlucometro` ya estaba en
    /// la lista de los que se escriben desde el paso 4.
    var registrarPorFoto: RegistrarLecturaPorFoto {
        RegistrarLecturaPorFoto(
            repositorio: lecturas,
            salud: EscribirEnHealthKit(servicio: salud, lecturas: lecturas)
        )
    }

    /// El único camino por el que se escribe una comida (RF-37).
    var registrarComida: RegistrarComida {
        RegistrarComida(repositorio: comidas)
    }

    /// El producto de un código de barras: primero la caché, después la red.
    var buscarProducto: BuscarProductoPorCodigo {
        BuscarProductoPorCodigo(servicio: servicioProductos, cache: productos, comidas: comidas)
    }

    /// Para las pruebas y las vistas previas: contenedor en memoria, sin tocar el disco.
    static func enMemoria() throws -> ContenedorDependencias {
        ContenedorDependencias(contenedor: try ContenedorGlucy.crear(enMemoria: true))
    }
}
