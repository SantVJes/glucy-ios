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
    private let ancla: AnclaHealthKit
    /// La biometría, detrás de su protocolo. Nadie fuera de `Data/Seguridad/` sabe que
    /// existe LocalAuthentication.
    let candado: any Candado

    init(
        contenedor: ModelContainer,
        salud: any ServicioHealthKit = HealthKitReal(),
        ancla: AnclaHealthKit = AnclaHealthKit(),
        ocr: any ServicioOCR = VisionOCR(),
        servicioProductos: any ServicioProductos = OpenFoodFactsHTTP(),
        candado: any Candado = CandadoBiometrico()
    ) {
        self.candado = candado
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
        self.ancla = ancla
        sincronizarSensor = SincronizarLecturasDelSensor(
            servicio: salud, lecturas: lecturas, ancla: ancla, perfil: perfil
        )
    }

    /// La copia en Salud de lo que Glucy captura. Un solo caso de uso para los tres tipos.
    private var escribirEnSalud: EscribirEnHealthKit {
        EscribirEnHealthKit(servicio: salud, lecturas: lecturas, comidas: comidas, dosis: dosis)
    }

    /// La captura manual con su copia en Salud.
    var registrarManual: RegistrarLecturaManual {
        RegistrarLecturaManual(repositorio: lecturas, salud: escribirEnSalud)
    }

    /// La captura por foto con su copia en Salud. El origen `.fotoGlucometro` ya estaba en
    /// la lista de los que se escriben desde el paso 4.
    var registrarPorFoto: RegistrarLecturaPorFoto {
        RegistrarLecturaPorFoto(repositorio: lecturas, salud: escribirEnSalud)
    }

    /// El único camino por el que se escribe una comida (RF-37).
    var registrarComida: RegistrarComida {
        RegistrarComida(repositorio: comidas, salud: escribirEnSalud)
    }

    /// El único camino por el que se escribe una dosis (regla 7).
    var registrarDosis: RegistrarDosis {
        RegistrarDosis(repositorio: dosis, salud: escribirEnSalud)
    }

    var calcularInsulinaActiva: CalcularInsulinaActiva {
        CalcularInsulinaActiva(dosis: dosis)
    }

    var calcularCarbohidratosActivos: CalcularCarbohidratosActivos {
        CalcularCarbohidratosActivos(comidas: comidas)
    }

    /// Todo lo que dibuja la pantalla de inicio, ya resuelto.
    var consultarInicio: ConsultarInicio {
        ConsultarInicio(
            lecturas: lecturas,
            modo: ConsultarModo(lecturas: lecturas),
            carbohidratosActivos: calcularCarbohidratosActivos,
            insulinaActiva: calcularInsulinaActiva,
            perfil: perfil
        )
    }

    /// Los indicadores del periodo y el día típico (RF-16).
    var consultarHistorial: ConsultarHistorial {
        ConsultarHistorial(lecturas: lecturas, perfil: perfil)
    }

    var ajustesDeInsulina: ConsultarAjustesDeInsulina {
        ConsultarAjustesDeInsulina(perfil: perfil)
    }

    /// La única puerta que escribe el consentimiento.
    var completarAlta: CompletarAlta {
        CompletarAlta(perfil: perfil, salud: salud)
    }

    var guardarAjustes: GuardarAjustes {
        GuardarAjustes(perfil: perfil)
    }

    var consultarEntrada: ConsultarEntrada {
        ConsultarEntrada(perfil: perfil)
    }

    /// Lo que lleva el informe para el médico (RF-16).
    var armarInforme: ArmarInforme {
        ArmarInforme(
            historial: consultarHistorial, lecturas: lecturas, comidas: comidas, dosis: dosis,
            perfil: perfil
        )
    }

    var consultarColaPendiente: ConsultarColaPendiente {
        ConsultarColaPendiente(cola: cola)
    }

    var consultarCuantoHay: ConsultarCuantoHay {
        ConsultarCuantoHay(lecturas: lecturas, comidas: comidas, dosis: dosis)
    }

    /// El borrado de la cuenta: lo local y lo que Glucy escribió en Salud.
    var borrarTodo: BorrarTodo {
        BorrarTodo(
            perfil: perfil, lecturas: lecturas, comidas: comidas, dosis: dosis, cola: cola,
            productos: productos, salud: salud, ancla: ancla
        )
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
