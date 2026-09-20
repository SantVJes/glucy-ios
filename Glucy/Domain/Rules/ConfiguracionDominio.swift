import Foundation

/// Todas las constantes clínicas del dominio, en un solo lugar.
///
/// Ninguno de estos números se vuelve a escribir suelto en una vista, en un caso de uso ni
/// en una regla. Un umbral repetido en dos archivos es un umbral que algún día va a estar
/// en dos valores distintos, y aquí eso se traduce en una decisión clínica equivocada.
///
/// Son los mismos números de `referencia/reglas_clinicas.py` en glucy-backend. Si alguno
/// deja de coincidir, uno de los dos está mal.
///
/// Todo `Domain/` se declara `nonisolated`, aquí y en los demás archivos, porque el target
/// compila con `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`: sin esa palabra las reglas
/// quedarían atadas al hilo principal y no se podrían llamar desde la entrega en segundo
/// plano de HealthKit ni desde la cola de sincronización. El dominio no es de nadie.
nonisolated enum ConfiguracionDominio {

    // MARK: - Glucosa

    /// Rango fisiológico aceptable de una lectura (RF-05, caso P-02). Fuera de él la
    /// lectura no se guarda: va a cuarentena con su motivo, no se descarta en silencio.
    static let glucosaMinima = 20.0          // mg/dL
    static let glucosaMaxima = 600.0         // mg/dL

    static let umbralHipoPorOmision = 70.0   // mg/dL
    static let umbralHiperPorOmision = 180.0 // mg/dL

    /// Lo que el perfil puede mover. Mueve el TBR y el TAR, nunca el TIR.
    static let umbralHipoConfigurable = 50.0...90.0
    static let umbralHiperConfigurable = 140.0...300.0

    /// Rango objetivo del TIR. Es **fijo** aunque el perfil mueva sus umbrales: es la
    /// definición del indicador, y moverla haría incomparables los números con cualquier
    /// otra fuente clínica.
    static let rangoObjetivo = 70.0...180.0

    // MARK: - Carbohidratos

    /// Tiempo de absorción por omisión (D-8). Presets de 30 min (rápida) y 300 (lenta).
    static let absorcionPorOmisionMin = 180
    static let absorcionConfigurableMin = 30...300

    static let carbsMinimos = 0.0            // g
    static let carbsMaximos = 300.0          // g

    // MARK: - Insulina

    /// Duración de acción de la insulina. El perfil la pregunta porque sin ella la
    /// insulina activa se calcularía con una curva equivocada.
    static let duracionAccionPorOmisionH = 5.0
    static let duracionAccionConfigurableH = 2.0...8.0

    /// Pico de las insulinas rápidas. Las ultrarrápidas usan 55.
    static let picoInsulinaMin = 75.0

    static let insulinaMinima = 0.0          // UI
    static let insulinaMaxima = 50.0         // UI
    /// La pluma dosifica de media en media unidad; pedir más resolución es fingir una
    /// precisión que el dispositivo no tiene.
    static let insulinaResolucionUI = 0.5

    // MARK: - Frescura y serie continua

    /// Pasados 15 minutos la lectura del sensor ya no sirve para predecir: se degrada a
    /// modo sin sensor en lugar de proyectar con datos viejos (RF-06c, D-13, caso P-03).
    static let frescuraSensorMin = 15.0

    /// Solo se interpolan huecos de hasta 15 min y solo en la serie continua (RF-23).
    /// Interpolar entre dos pinchazos separados por horas sería inventar datos.
    static let interpolacionMaximaMin = 15.0

    /// Una serie continua no puede cambiar más rápido que esto; por encima es artefacto
    /// del sensor, no fisiología.
    static let tasaCambioImposible = 4.0     // mg/dL por minuto

    // MARK: - Perfil

    static let pesoMinimoKg = 25.0
    static let pesoMaximoKg = 300.0

    /// Por debajo de esta edad el proyecto no tiene consentimiento ni validación que lo
    /// respalde, así que la app no se usa.
    static let edadMinima = 15

    // MARK: - Indicadores

    /// GMI = `gmiIntercepto + gmiPendiente × promedio` (fórmula del consenso).
    static let gmiIntercepto = 3.31
    static let gmiPendiente = 0.02392
}
