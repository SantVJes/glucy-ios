import Foundation

/// El vector de características que recibe el modelo, en el orden del contrato.
///
/// **Es el archivo más delicado de la app.** El artefacto de Core ML recibe quince números en
/// un orden; si aquí se calculan o se ordenan distinto que en el pipeline que los calculó al
/// entrenar, la predicción se alimenta con las columnas cambiadas de lugar y **nada falla**:
/// sale un número plausible y equivocado, la pantalla lo dibuja, y nadie se entera.
///
/// La autoridad sobre los nombres, el orden y **cada fórmula** es
/// `app/services/pipeline/caracteristicas.py` de glucy-backend, que se declara como tal en su
/// encabezado. Aquí no se deriva nada: se copia, y `VectorDeCaracteristicasTests` lo fija.
///
/// Ya pasó una vez, el 29 de octubre de 2026 y en la dirección contraria: glucy-ml calculaba
/// la insulina activa con una aproximación lineal propia mientras el backend y esta app usaban
/// la curva de la referencia. A las tres horas de una dosis, 40 % contra 15.9 % de la dosis
/// activa. El modelo aprendió una columna que nadie le iba a dar en producción.
nonisolated enum VectorDeCaracteristicas {

    /// Los quince nombres del juego denso, **en su orden**. Copiados de
    /// `CARACTERISTICAS_DENSAS` del backend: no derivar, no ordenar por programa, no generar.
    static let densas: [String] = [
        "mg_dl", "rezago_5", "rezago_10", "rezago_15", "rezago_30", "rezago_60",
        "derivada_1", "derivada_2", "media_30", "media_60",
        "cob", "iob", "hora_sin", "hora_cos", "dia_semana",
    ]

    /// Los rezagos que pide el contrato, en minutos.
    static let rezagosMin = [5, 10, 15, 30, 60]

    /// Minutos que se consideran para los promedios móviles.
    static let ventanasMediaMin = [30, 60]

    /// Cuánto puede alejarse una lectura del instante que se le pide para seguir sirviendo:
    /// **media muestra**. Con 2.5 min cada instante tiene a lo más un candidato dentro de una
    /// serie de cinco minutos, así que no hay que decidir empates casi nunca.
    static let toleranciaRezagoMin = 2.5

    static let minutosPorDia = 1440.0

    /// Lo que no se puede calcular. **`NaN`, nunca cero**: un rezago de 60 minutos que no
    /// existe porque la serie empieza ahí no es una glucosa de cero. El modelo trata el `NaN`
    /// como información —aprendió para qué lado mandar la fila— y el cero como un valor real
    /// que arrastra el promedio hacia abajo.
    static let falta = Double.nan

    /// El juego denso para el instante `ahora`, a partir de la serie continua.
    ///
    /// - Parameter serie: lecturas **de la serie continua**, ordenadas de la más vieja a la
    ///   más nueva y todas en `ahora` o antes. Mirar una lectura posterior sería mirar hacia
    ///   adelante: a las 14:00 el teléfono no tiene las 14:05.
    /// - Parameter comidas: solo las que la persona registró. Una comida que no está no se
    ///   infiere (D-9, RF-37), así que una subida sin comida registrada entra al modelo como
    ///   una subida sin carbohidratos activos.
    /// - Parameter dosis: se filtra el bolo aquí dentro; la basal no se acumula como insulina
    ///   activa en este modelo.
    /// - Parameter zona: la zona horaria con la que se lee la hora del día. La del dato, no la
    ///   del teléfono de hoy: alguien que viajó tiene lecturas de dos zonas y la hora que vale
    ///   es la que era para esa persona en ese momento (regla 5).
    static func denso(
        serie: [LecturaGlucosaDato],
        comidas: [ComidaDato],
        dosis: [DosisInsulinaDato],
        ahora: Date,
        zona: TimeZone
    ) -> [String: Double] {
        let validas = serie.filter { !$0.atipica && $0.tsUtc <= ahora }
            .sorted { $0.tsUtc < $1.tsUtc }

        let actual = valorEn(validas, instante: ahora)
        let rezagos = rezagosMin.map {
            valorEn(validas, instante: ahora.addingTimeInterval(-Double($0) * 60))
        }
        let (sin, cos) = horaCiclica(minutosDelDia(ahora, zona: zona))

        var vector: [String: Double] = [
            "mg_dl": actual,
            "derivada_1": (actual - rezagos[0]) / 5,
            // `(actual − 2·r5 + r10) / 25`, que es la diferencia de las dos pendientes de
            // cinco minutos dividida entre cinco. Es la forma que tiene el backend, y `NaN`
            // se propaga solo: si falta cualquiera de los dos rezagos, la derivada es `NaN`
            // en lugar de un cero que el modelo leería como «no se está moviendo».
            "derivada_2": (actual - 2 * rezagos[0] + rezagos[1]) / 25,
            "cob": cobDe(comidas, ahora: ahora),
            "iob": iobDe(dosis, ahora: ahora),
            "hora_sin": sin,
            "hora_cos": cos,
            "dia_semana": diaSemana(ahora, zona: zona),
        ]
        for (minutos, valor) in zip(rezagosMin, rezagos) {
            vector["rezago_\(minutos)"] = valor
        }
        for minutos in ventanasMediaMin {
            vector["media_\(minutos)"] = media(
                validas, desde: ahora.addingTimeInterval(-Double(minutos) * 60), hasta: ahora
            )
        }
        return vector
    }

    /// El vector tal como lo recibe Core ML: **un diccionario por nombre**, con cada valor
    /// cuantizado a 32 bits.
    ///
    /// Por nombre y no por orden porque así está declarado el artefacto. Inspeccionado sobre
    /// `m1-v0.2.0-simulador`: es un `treeEnsembleRegressor` con **quince entradas `double`
    /// nombradas**, una por característica, y una salida `target`. Un arreglo ordenado no es
    /// lo que consume, y por eso el orden de `densas` sirve para presentar los factores pero
    /// no para alimentar el modelo.
    ///
    /// Cuantizado a 32 bits y entregado como `Double`, que suena raro y es lo correcto: los
    /// umbrales de los árboles son `float32` y XGBoost compara contra ellos con esa precisión,
    /// mientras la interfaz de Core ML pide `double`. Así que `Double(Float(v))` redondea a los
    /// bits con los que se entrenó y después los ensancha. Medido sobre ese artefacto, mandando
    /// la doble precisión sin redondear la predicción se desvía **hasta 1.57 mg/dL en 450 de
    /// 2 000 filas**; en M-2, hasta 2.78 en 621. No revienta nada: da otro número.
    ///
    /// El `NaN` se manda tal cual. El árbol trae 498 nodos con `missingValueTracksTrueChild`,
    /// o sea que Core ML sabe para qué lado mandar una fila con un hueco, que es lo mismo que
    /// hace XGBoost. Rellenar el hueco con un cero o con el último valor desvía **hasta
    /// 19.8 mg/dL**.
    ///
    /// Un nombre de más o de menos revienta, no se ignora: es justo el desajuste que produce
    /// números plausibles y equivocados.
    static func paraCoreML(
        _ vector: [String: Double], juego: [String] = densas
    ) throws -> [String: Double] {
        let delVector = Set(vector.keys)
        let delJuego = Set(juego)
        guard delVector == delJuego else {
            throw ErrorDeCaracteristicas.noEsDelJuego(
                sobran: delVector.subtracting(delJuego).sorted(),
                faltan: delJuego.subtracting(delVector).sorted()
            )
        }
        return vector.mapValues { Double(Float($0)) }
    }

    // MARK: - Las piezas, cada una con la forma que tiene en el backend

    /// El valor de la lectura válida más cercana a `instante`, a menos de media muestra, o
    /// `NaN`.
    ///
    /// **Por tiempo y no por posición**: `rezago_30` es «la lectura más cercana a hace 30
    /// minutos, si existe dentro de la tolerancia», no «la fila de seis atrás». La serie trae
    /// huecos —HealthKit entrega lo que la app del fabricante escribió, cuando lo escribió
    /// (RF-06b)— y buscar por posición devuelve un valor de otro momento con el nombre de
    /// este, sin que nada falle.
    static func valorEn(_ validas: [LecturaGlucosaDato], instante: Date) -> Double {
        let tolerancia = toleranciaRezagoMin * 60
        var mejor: LecturaGlucosaDato?
        var mejorDistancia = Double.infinity
        for lectura in validas {
            let distancia = abs(lectura.tsUtc.timeIntervalSince(instante))
            // Estricto, y recorriendo en orden, así que un empate exacto se queda con la
            // lectura más antigua: es lo que hace el `min` del backend sobre una lista
            // ordenada por tiempo.
            if distancia < mejorDistancia {
                (mejor, mejorDistancia) = (lectura, distancia)
            }
        }
        guard let mejor, mejorDistancia <= tolerancia else { return falta }
        return mejor.mgDl
    }

    /// Promedio de las lecturas válidas en **`(desde, hasta]`**, o `NaN` si no hay ninguna.
    ///
    /// Abierta por abajo y cerrada por arriba, como `_media` del backend. Con el borde
    /// inferior incluido, `media_30` sobre una serie de cinco minutos promediaría siete
    /// lecturas donde el servidor promedia seis, y en una subida eso mueve el promedio unos
    /// cuantos mg/dL en cada fila.
    static func media(_ validas: [LecturaGlucosaDato], desde: Date, hasta: Date) -> Double {
        let dentro = validas.filter { $0.tsUtc > desde && $0.tsUtc <= hasta }
        guard !dentro.isEmpty else { return falta }
        return dentro.reduce(0) { $0 + $1.mgDl } / Double(dentro.count)
    }

    /// Carbohidratos activos de las comidas registradas **hasta** `ahora`.
    ///
    /// Sin comidas es 0 y no `NaN`: no hay nada que absorber, no es un dato que falte. Se
    /// filtra lo posterior a `ahora` antes de llamar a la regla porque `Carbohidratos.cob`
    /// trata una comida futura como entera y activa —correcto para el registro, mirar hacia
    /// adelante aquí— mientras el pipeline del backend la deja fuera.
    static func cobDe(_ comidas: [ComidaDato], ahora: Date) -> Double {
        Carbohidratos.cobTotal(
            comidas: comidas.filter { $0.tsUtc <= ahora }.map {
                (
                    carbsG: $0.carbsG,
                    minutos: ahora.timeIntervalSince($0.tsUtc) / 60,
                    absorcionMin: $0.tiempoAbsorcionMin
                )
            }
        )
    }

    /// Insulina activa de los **boles** aplicados hasta `ahora`, cada uno con la duración de
    /// acción que tenía guardada.
    ///
    /// Se filtra lo futuro por lo mismo que en el COB: `Insulina.fraccionActiva` devuelve 1
    /// para minutos negativos, que es lo correcto para una dosis ya puesta y sería mirar hacia
    /// adelante al armar una fila.
    static func iobDe(_ dosis: [DosisInsulinaDato], ahora: Date) -> Double {
        dosis
            .filter { $0.tipo == .bolo && $0.tsUtc <= ahora }
            .reduce(0) { total, d in
                total + Insulina.iob(
                    dosis: [(unidades: d.unidades, minutos: ahora.timeIntervalSince(d.tsUtc) / 60)],
                    diaH: d.duracionAccionH
                )
            }
    }

    /// La hora del día como seno y coseno, no como un número de 0 a 23.
    ///
    /// Las 23:50 y las 00:10 están a veinte minutos y como números están a 23 horas. Un modelo
    /// de árboles puede aprender a partir el día en trozos, pero no que los extremos se tocan,
    /// y la medianoche es justo cuando pasa lo que más importa: la hipoglucemia nocturna.
    static func horaCiclica(_ minutos: Double) -> (sin: Double, cos: Double) {
        let angulo = 2 * Double.pi * minutos.truncatingRemainder(dividingBy: minutosPorDia)
            / minutosPorDia
        return (Foundation.sin(angulo), Foundation.cos(angulo))
    }

    /// Minutos transcurridos del día en `zona`, **con los segundos**.
    ///
    /// Con segundos porque los cuenta el backend. Una muestra que no cae en el minuto exacto
    /// daría otro ángulo que en producción, y eso es otra columna que no coincide.
    static func minutosDelDia(_ instante: Date, zona: TimeZone) -> Double {
        var calendario = Calendar(identifier: .gregorian)
        calendario.timeZone = zona
        let p = calendario.dateComponents([.hour, .minute, .second], from: instante)
        return Double(p.hour ?? 0) * 60 + Double(p.minute ?? 0) + Double(p.second ?? 0) / 60
    }

    /// Día de la semana con **lunes = 0 y domingo = 6**, en `zona`.
    ///
    /// Es la convención de `weekday()` de Python, que es con la que se entrenó. `Calendar` de
    /// Foundation numera domingo = 1 y sábado = 7, así que hay que convertir. Sin convertir,
    /// el modelo recibiría un lunes donde aprendió un domingo: un número válido, en la columna
    /// correcta, y equivocado.
    static func diaSemana(_ instante: Date, zona: TimeZone) -> Double {
        var calendario = Calendar(identifier: .gregorian)
        calendario.timeZone = zona
        let domingoEsUno = calendario.component(.weekday, from: instante)
        return Double((domingoEsUno + 5) % 7)
    }
}

nonisolated enum ErrorDeCaracteristicas: Error, Equatable {
    /// El vector no cuadra con el juego del contrato. Lleva las dos listas porque el nombre
    /// que sobra y el que falta suelen ser el mismo renombrado.
    case noEsDelJuego(sobran: [String], faltan: [String])
}
