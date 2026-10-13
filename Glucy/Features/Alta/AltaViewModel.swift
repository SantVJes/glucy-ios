import Foundation

/// Los cinco pasos del alta, en orden.
enum PasoDeAlta: Int, CaseIterable, Hashable {
    case nombre = 1, tipoYAnio, sensor, parametros, consentimiento
}

/// El estado del alta del perfil.
///
/// **No decide quién puede darse de alta ni guarda nada por su cuenta**: la edad mínima, los
/// rangos y el consentimiento los resuelven `ReglasDePerfil`, `Validacion` y `CompletarAlta`.
/// Aquí vive lo que la persona lleva tecleado, y se le da forma de texto a lo que falta.
@Observable
final class AltaViewModel {

    // Paso 1
    var nombre = ""
    var apellidos = ""

    // Paso 2
    var tipoUsuario: TipoUsuario?
    var textoAnio = ""

    // Paso 3. `nil` hasta que la persona elige: ninguna de las dos tarjetas viene marcada.
    private(set) var usaSensor: Bool?
    /// Se intentó pedir el permiso de Salud y no se pudo. No es un error: es el modo sin
    /// sensor, y la pantalla lo dice con calma.
    private(set) var seguimosSinSensor = false
    private(set) var pidiendoPermiso = false

    // Paso 4
    var unidad = UnidadGlucosa.mgDl
    private(set) var umbralHipo = ConfiguracionDominio.umbralHipoPorOmision
    private(set) var umbralHiper = ConfiguracionDominio.umbralHiperPorOmision
    var textoPeso = ""
    var tipoInsulinaRapida = ""
    private(set) var duracionAccionH = ConfiguracionDominio.duracionAccionPorOmisionH

    // Paso 5
    private(set) var guardando = false
    private(set) var fallo: String?

    private let completar: CompletarAlta

    init(completar: CompletarAlta) {
        self.completar = completar
    }

    // MARK: - Paso 1

    /// El nombre y los apellidos son opcionales (F-1): vacíos, se continúa.
    var nombreValido: Bool {
        ReglasDePerfil.esNombreValido(nombre, maximo: ConfiguracionDominio.nombreMaximo)
            && ReglasDePerfil.esNombreValido(apellidos, maximo: ConfiguracionDominio.apellidosMaximo)
    }

    var mensajeDeNombre: String? {
        nombreValido ? nil : "Usa solo letras y espacios, sin números ni signos."
    }

    // MARK: - Paso 2

    var anio: Int? {
        Int(textoAnio.trimmingCharacters(in: .whitespaces))
    }

    /// Se dice aquí, antes de continuar: quien tiene 14 años no debe llenar el resto del
    /// formulario para que al final se le diga que no.
    func mensajeDeAnio(ahora: Date = Date()) -> String? {
        // Mientras se teclea no se regaña: con dos cifras todavía no hay año.
        guard textoAnio.count >= 4, let anio else { return nil }
        switch ReglasDePerfil.validarAnio(anio, ahora: ahora) {
        case nil: return nil
        case .edadInsuficiente:
            return "Glucy es para personas de \(ConfiguracionDominio.edadMinima) años o más."
        case .marcaDeTiempoFutura: return "Ese año todavía no llega. Revísalo."
        default: return "Revisa el año: escríbelo con sus cuatro cifras."
        }
    }

    func puedeContinuarDelTipo(ahora: Date = Date()) -> Bool {
        guard tipoUsuario != nil, let anio else { return false }
        return ReglasDePerfil.validarAnio(anio, ahora: ahora) == nil
    }

    /// Quien no se aplica insulina no ve sus dos preguntas (RF-14).
    var registraInsulina: Bool {
        tipoUsuario.map(ReglasDePerfil.registraInsulinaPorOmision(para:)) ?? false
    }

    // MARK: - Paso 3

    func elegir(usaSensor nuevo: Bool) {
        usaSensor = nuevo
        if nuevo { seguimosSinSensor = false }
    }

    /// `true` si se puede pasar al siguiente paso.
    ///
    /// «Sin sensor» no pide nada. «Con sensor» pide el permiso de lectura **después** de
    /// haber enseñado para qué, y si no se puede pedir, el alta sigue en modo sin sensor:
    /// se queda en este paso solo para decirlo.
    func continuarDelSensor() async -> Bool {
        guard let usaSensor else { return false }
        guard usaSensor else { return true }

        pidiendoPermiso = true
        defer { pidiendoPermiso = false }
        if await completar.pedirPermisoDeSalud() { return true }

        self.usaSensor = false
        seguimosSinSensor = true
        return false
    }

    // MARK: - Paso 4

    var peso: Double? {
        RegistroGlucosaViewModel.numero(desde: textoPeso)
    }

    /// El peso es opcional: vacío vale. Escrito, tiene que estar entre 25 y 300 kg.
    var mensajeDePeso: String? {
        guard !textoPeso.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        guard let peso,
              (ConfiguracionDominio.pesoMinimoKg...ConfiguracionDominio.pesoMaximoKg).contains(peso)
        else {
            return "Escribe tu peso en kilos, entre \(Int(ConfiguracionDominio.pesoMinimoKg)) "
                + "y \(Int(ConfiguracionDominio.pesoMaximoKg)), o déjalo en blanco."
        }
        return nil
    }

    var puedeContinuarDeParametros: Bool {
        mensajeDePeso == nil
            && tipoInsulinaRapida.count <= ConfiguracionDominio.tipoInsulinaMaximo
    }

    static let pasoDeUmbral = 5.0
    static let pasoDeDuracion = 0.5

    func moverUmbralHipo(_ pasos: Double) {
        umbralHipo = Self.acotar(
            umbralHipo + pasos * Self.pasoDeUmbral, a: ConfiguracionDominio.umbralHipoConfigurable
        )
    }

    func moverUmbralHiper(_ pasos: Double) {
        umbralHiper = Self.acotar(
            umbralHiper + pasos * Self.pasoDeUmbral, a: ConfiguracionDominio.umbralHiperConfigurable
        )
    }

    func moverDuracion(_ pasos: Double) {
        duracionAccionH = Self.acotar(
            duracionAccionH + pasos * Self.pasoDeDuracion,
            a: ConfiguracionDominio.duracionAccionConfigurableH
        )
    }

    static func acotar(_ valor: Double, a rango: ClosedRange<Double>) -> Double {
        min(max(valor, rango.lowerBound), rango.upperBound)
    }

    static func textoDeHoras(_ horas: Double) -> String {
        horas == horas.rounded() ? "\(Int(horas)) h" : "\(horas) h"
    }

    // MARK: - Paso 5

    /// La fecha del consentimiento, a la vista antes de aceptar.
    func textoDeHoy(ahora: Date = Date()) -> String {
        ahora.formatted(date: .long, time: .omitted)
    }

    /// `true` si el alta quedó guardada. El consentimiento lo escribe `CompletarAlta`, con
    /// la fecha de este momento.
    func aceptar(ahora: Date = Date()) async -> Bool {
        guard !guardando, let tipoUsuario, let anio else { return false }
        guardando = true
        defer { guardando = false }

        do {
            try await completar.ejecutar(
                nombre: nombre,
                apellidos: apellidos,
                tipoUsuario: tipoUsuario,
                anioNacimiento: anio,
                pesoKg: peso,
                unidadPreferida: unidad,
                usaSensor: usaSensor ?? false,
                umbralHipo: umbralHipo,
                umbralHiper: umbralHiper,
                tipoInsulinaRapida: tipoInsulinaRapida,
                duracionAccionH: duracionAccionH,
                aceptaConsentimiento: true,
                ahora: ahora
            )
            fallo = nil
            return true
        } catch let rechazo as Rechazo {
            fallo = Self.mensaje(de: rechazo)
            return false
        } catch {
            fallo = "No se pudo guardar tu perfil. Inténtalo otra vez."
            return false
        }
    }

    /// Dice qué corregir, no qué regla se rompió.
    static func mensaje(de rechazo: Rechazo) -> String {
        switch rechazo {
        case .edadInsuficiente:
            "Glucy es para personas de \(ConfiguracionDominio.edadMinima) años o más."
        case .marcaDeTiempoFutura, .perfilNoValido(.anioNacimiento):
            "Revisa tu año de nacimiento."
        case .perfilNoValido(.nombre), .perfilNoValido(.apellidos):
            "En tu nombre y tus apellidos usa solo letras y espacios."
        case .perfilNoValido(.peso):
            "Revisa tu peso: va en kilos, entre \(Int(ConfiguracionDominio.pesoMinimoKg)) "
                + "y \(Int(ConfiguracionDominio.pesoMaximoKg))."
        case .perfilNoValido(.umbralHipo), .perfilNoValido(.umbralHiper):
            "Revisa tus umbrales."
        case .perfilNoValido(.tipoInsulina):
            "El nombre de tu insulina es demasiado largo."
        case .perfilNoValido(.duracionAccion):
            "Revisa cuánto te dura la insulina."
        case .perfilNoValido(.absorcion):
            "Revisa el tiempo de absorción."
        case .sinConsentimiento:
            "Sin tu consentimiento Glucy no puede guardar tus datos."
        default:
            "No se pudo guardar tu perfil. Inténtalo otra vez."
        }
    }
}
