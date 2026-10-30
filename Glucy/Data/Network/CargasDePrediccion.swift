import Foundation

/// Lo que viaja entre la app y los dos endpoints que explican una predicción: `GET /predict`
/// y `POST /explain`.
///
/// Son tipos aparte de los del dominio a propósito. `Proyeccion` es lo que la app calcula con
/// Core ML y lo que la pantalla dibuja; esto es **lo que contestó el servidor**, con sus
/// nombres y sus unidades. Mezclarlos haría que un cambio del contrato del backend llegara
/// hasta la vista, y que no se pudiera distinguir el número propio del ajeno —que es justo lo
/// que el paso siguiente tiene que comparar (C-16).

/// El modo con el que respondió el servidor (RF-21).
nonisolated enum ModoRemoto: String, Codable, Sendable {
    case sensor
    case sinSensor = "sin_sensor"
}

/// La alerta **derivada** del valor, no predicha como clase (RF-26).
nonisolated enum AlertaRemota: String, Codable, Sendable {
    case hipoglucemia
    case hiperglucemia
}

/// De dónde salió la explicación. No es un detalle interno: el reporte tiene que poder decir
/// cuántas salieron del modelo de lenguaje y cuántas de la plantilla determinista (P-13).
nonisolated enum OrigenExplicacion: String, Codable, Sendable {
    case modelo
    case plantilla
}

/// Una contribución SHAP en crudo: el nombre de la columna del modelo y su aporte en mg/dL.
///
/// Esta es la lista que vuelve a salir del teléfono en `POST /explain`, así que los nombres se
/// conservan tal cual: son el contrato con el pipeline y con glucy-ml, no texto para enseñar.
nonisolated struct ContribucionRemota: Codable, Sendable, Equatable {
    let variable: String
    let mgDl: Double

    enum CodingKeys: String, CodingKey {
        case variable
        case mgDl = "mg_dl"
    }
}

/// Una contribución **ya en palabras**, lista para la pantalla de factores.
///
/// Llega hecha del servidor y la app no traduce nada: un diccionario de nombres de
/// características repetido en Swift se queda viejo el día que el pipeline agrega una columna,
/// y nadie se entera hasta que alguien lee «rezago_45» en la pantalla.
nonisolated struct FactorRemoto: Codable, Sendable, Equatable {
    let nombre: String
    let mgDl: Double

    enum CodingKeys: String, CodingKey {
        case nombre
        case mgDl = "mg_dl"
    }
}

/// Una predicción del servidor, con sus factores y la versión que la calculó (RF-25).
nonisolated struct HorizonteRemoto: Codable, Sendable, Equatable {
    let horizonteMin: Int
    /// El instante al que apunta, que es `tsBase` más el horizonte y **no el reloj más el
    /// horizonte**. La app enseña esta hora.
    let tsObjetivo: Date
    let valorPredicho: Double
    let modeloVersion: String
    let alerta: AlertaRemota?
    let shap: [ContribucionRemota]
    let factores: [FactorRemoto]

    enum CodingKeys: String, CodingKey {
        case horizonteMin = "horizonte_min"
        case tsObjetivo = "ts_objetivo"
        case valorPredicho = "valor_predicho"
        case modeloVersion = "modelo_version"
        case alerta
        case shap
        case factores
    }
}

/// La respuesta completa de `GET /predict`.
nonisolated struct PrediccionRemota: Codable, Sendable, Equatable {
    let tsUtc: Date
    let modo: ModoRemoto
    /// La última lectura **de cualquier origen**. Puede no ser `valorBase`.
    let valorActual: Double?
    let antiguedadMin: Double?
    /// El instante de la última lectura **del sensor**, que es donde el servidor armó la fila
    /// y desde donde cuenta el horizonte. Es el campo que la app compara con el suyo: si los
    /// dos caminos no partieron del mismo punto, los dos números no son comparables.
    let tsBase: Date?
    let valorBase: Double?
    let puedeAlertarHipoglucemia: Bool
    let umbralHipo: Double
    let umbralHiper: Double
    /// Vacía en modo sin sensor, y entonces `aviso` dice por qué (RF-10b).
    let predicciones: [HorizonteRemoto]
    let aviso: String?

    enum CodingKeys: String, CodingKey {
        case tsUtc = "ts_utc"
        case modo
        case valorActual = "valor_actual"
        case antiguedadMin = "antiguedad_min"
        case tsBase = "ts_base"
        case valorBase = "valor_base"
        case puedeAlertarHipoglucemia = "puede_alertar_hipoglucemia"
        case umbralHipo = "umbral_hipo"
        case umbralHiper = "umbral_hiper"
        case predicciones
        case aviso
    }
}

/// Lo que se le manda a `POST /explain`, y **nada más**.
///
/// No hay nombre, ni apellidos, ni peso, ni notas, ni año de nacimiento, ni el UUID del
/// usuario: lo que identifica a la persona no sale del teléfono (regla 3). El servidor además
/// rechaza con `400` cualquier campo de más, así que un descuido aquí no acaba en el prompt
/// del modelo de lenguaje en silencio.
nonisolated struct ExplicacionPedida: Codable, Sendable, Equatable {
    /// Cuántas contribuciones acepta el servidor: ni más ni menos de lo que la pantalla de
    /// factores dibuja. Se comprueba antes de salir del teléfono, porque un `400` no se
    /// reintenta y se perdería la explicación sin que nada lo dijera.
    static let contribucionesShap = 5

    let valorActual: Double
    let valorPredicho: Double
    let horizonteMin: Int
    let modo: ModoRemoto
    let umbralHipo: Double
    let umbralHiper: Double
    let cobG: Double
    let iobUI: Double
    /// La hora del día, 0 a 23, en la zona de la persona.
    let horaLocal: Int
    let shap: [ContribucionRemota]
    /// Si la persona apagó el asistente en Ajustes. Lo manda el teléfono en cada petición en
    /// lugar de que el servidor guarde la preferencia, porque la preferencia es del teléfono
    /// (regla 1). Con `false` sale la plantilla determinista y no se llama a ningún modelo.
    let asistenteActivo: Bool

    enum CodingKeys: String, CodingKey {
        case valorActual = "valor_actual"
        case valorPredicho = "valor_predicho"
        case horizonteMin = "horizonte_min"
        case modo
        case umbralHipo = "umbral_hipo"
        case umbralHiper = "umbral_hiper"
        case cobG = "cob_g"
        case iobUI = "iob_ui"
        case horaLocal = "hora_local"
        case shap
        case asistenteActivo = "asistente_activo"
    }

    /// `true` si el sobre cumple lo que el servidor exige. Lo que no cumple no se manda.
    var sirveParaMandar: Bool {
        !shap.isEmpty && shap.count <= Self.contribucionesShap
            && (0...23).contains(horaLocal)
    }
}

/// La explicación, y de dónde salió.
nonisolated struct ExplicacionRemota: Codable, Sendable, Equatable {
    let explicacion: String
    let origen: OrigenExplicacion
    /// Por qué salió la plantilla, cuando salió: `sin_asistente`, `sin_respuesta` o
    /// `no_paso_validacion`. Se deja como texto y no como enumeración cerrada: un motivo
    /// nuevo del servidor no tiene por qué tirar la decodificación de una frase que ya llegó.
    let motivo: String?
    let modelo: String?
}
