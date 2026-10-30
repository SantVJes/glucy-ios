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

    /// mg/dL = mmol/L × 18.0182. Solo se usa al entrar: adentro todo es mg/dL.
    static let factorMmolLAMgDl = 18.0182

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
    /// Las otras dos opciones que se ofrecen al ajustar (RF-12b). No hay una cuarta.
    static let absorcionRapidaMin = 30
    static let absorcionLentaMin = 300
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

    /// Un año de nacimiento que da más que esto es un dedo que se fue de tecla, no una
    /// persona.
    static let edadMaxima = 120

    /// Los largos del formulario F-1.
    static let nombreMaximo = 40
    static let apellidosMaximo = 60
    static let tipoInsulinaMaximo = 40

    // MARK: - Arranque y candado

    /// El splash se va en cuanto se leyó el perfil, pero no antes de esto: más corto
    /// parpadea. No es una espera de adorno; el arranque en frío tiene que dejar ver el
    /// valor actual en menos de dos segundos.
    static let splashMinimoS = 0.4

    /// Cuánto puede estar la app en segundo plano sin que el candado vuelva a pedirse.
    /// Contestar un mensaje y volver no debe costar otro Face ID.
    static let graciaDelCandadoS = 60.0

    // MARK: - Indicadores

    /// GMI = `gmiIntercepto + gmiPendiente × promedio` (fórmula del consenso).
    static let gmiIntercepto = 3.31
    static let gmiPendiente = 0.02392

    // MARK: - Historial

    /// Por debajo de tres días distintos con lecturas, un porcentaje de tiempo en rango
    /// describe un día suelto y se lee como si describiera la semana (Documento 1, punto 8).
    static let diasMinimosIndicadores = 3

    /// La fórmula del GMI se validó sobre series de al menos 14 días. Con menos, el número
    /// sale igual y no significa nada, y es un dato que la persona puede llevar a consulta.
    static let diasMinimosGmi = 14

    /// Los tres periodos del historial (Documento 1, pantalla 6). No hay un cuarto.
    static let periodosHistorialDias = [7, 14, 30]

    /// Con una o dos lecturas en una hora, un cuartil no existe. La hora se queda vacía y la
    /// pantalla dice cuántas faltan, en lugar de dibujar una banda que nadie midió.
    static let lecturasMinimasPorHora = 3

    // MARK: - Gráficas

    /// Lo que la pantalla de inicio enseña en modo sensor: la serie es continua y tres
    /// horas caben con cada muestra a la vista (RF-08).
    static let ventanaInicioSensorH = 3.0

    /// Lo que enseña en modo sin sensor: con unos pocos pinchazos al día, en tres horas no
    /// habría casi nada que ver (RF-09).
    static let ventanaInicioSinSensorDias = 7.0

    /// La escala del eje Y, fija. Con escala automática la banda 70–180 cambia de tamaño en
    /// cada actualización y de madrugada eso se lee como que la glucosa se movió. Es el
    /// intervalo que reportan los sensores comerciales; lo que cae fuera se dibuja en el
    /// borde con otra forma, y su valor verdadero se dice en texto.
    static let escalaGraficaMgDl = 40.0...400.0

    // MARK: - Los dos caminos de la predicción (C-16)

    /// A partir de cuánta diferencia entre el número del teléfono y el del servidor se
    /// registra un desacuerdo.
    ///
    /// Un mg/dL: por debajo de eso la diferencia es redondeo —el teléfono cuantiza la entrada
    /// a 32 bits y el servidor no— y por encima significa que los dos caminos no armaron la
    /// misma fila. **Un desacuerdo silencioso no lo ve nadie** hasta que alguien compara dos
    /// pantallas, y ya pasó una vez: `GET /predict` armaba la fila con el reloj.
    static let desacuerdoQueSeRegistraMgDl = 1.0

    /// Cuánto pueden separarse los dos instantes base para que los dos números se consideren
    /// comparables. Medio minuto: si cada camino partió de una lectura distinta, la diferencia
    /// no dice nada de la implementación y compararlos sería inventar un problema.
    static let mismoInstanteBaseSeg = 30.0

    // MARK: - Avisos de hipoglucemia prevista (RF-10)

    /// Cuánto tiene que pasar para volver a avisar del mismo descenso.
    ///
    /// La pantalla se recalcula cada minuto, así que sin esta espera el mismo descenso
    /// avisaría sesenta veces por hora. Y veinte minutos no es un número redondo cualquiera:
    /// el criterio de aceptación del modelo es una tasa de falsas alarmas **≤ 15 %**, porque
    /// «un modelo que avisa de más se apaga solo», y una alerta repetida se siente igual que
    /// una falsa.
    static let esperaEntreAvisosMin = 20.0

    /// Cuánto tiene que empeorar la estimación para volver a avisar antes de esa espera.
    ///
    /// Pasar de «vas a 68» a «vas a 50» es información nueva y vale interrumpir otra vez;
    /// pasar de 68 a 66 no. Quince mg/dL es del orden del error del propio modelo a 30
    /// minutos (RMSE ≤ 20), así que por debajo de eso no hay un cambio del que fiarse.
    static let empeoraParaVolverAAvisarMgDl = 15.0
}
