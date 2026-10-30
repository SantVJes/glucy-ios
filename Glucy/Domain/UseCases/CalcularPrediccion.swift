import Foundation

/// Hacia dónde va la glucosa: el aviso que se deriva del número predicho.
///
/// Se deriva del valor y no se predice como clase, para que la persona vea la curva y entienda
/// por qué apareció el aviso (RF-26). **No lleva ninguna indicación de tratamiento** (regla 7):
/// dice qué va a pasar, no qué hacer.
nonisolated enum AvisoPrevisto: Sendable, Equatable {
    case bajaPrevista
    case altaPrevista
}

/// Una predicción lista para la pantalla.
nonisolated struct Proyeccion: Sendable, Equatable, Identifiable {
    /// La lectura del sensor desde la que se predijo. Es el punto donde arranca la línea
    /// punteada, y no es necesariamente la última lectura que la persona tomó: un pinchazo no
    /// entra al juego denso.
    struct Base: Sendable, Equatable {
        let ts: Date
        let mgDl: Double
    }

    /// El horizonte, que es lo que distingue una predicción de la otra. No un `UUID()` nuevo
    /// en cada pasada: la pantalla se repinta cada minuto y un id distinto cada vez hace que
    /// la gráfica se vuelva a animar entera.
    var id: Int { horizonteMin }

    /// 30 o 60, contados **desde `base`** y no desde el reloj.
    let horizonteMin: Int
    let valorMgDl: Double
    /// El instante al que apunta: `base` más el horizonte. La pantalla enseña esta hora, no
    /// «dentro de media hora»: con una lectura de doce minutos de antigüedad, una predicción a
    /// 30 minutos alcanza a dieciocho.
    let objetivo: Date
    let base: Base
    /// Con qué versión del artefacto se calculó (RF-25).
    let versionModelo: String
    let aviso: AvisoPrevisto?
}

/// Por qué no hay predicción, cuando no hay. Se dice en pantalla en lugar de dejar el hueco:
/// un número ausente sin explicación se lee como una falla de la app.
nonisolated enum SinProyeccion: Error, Sendable, Equatable {
    /// Modo sin sensor. **La app declara que no puede anticipar una hipoglucemia** (RF-10b,
    /// regla 8, caso P-04) y no rellena con nada que parezca una predicción.
    case sinSensor
    /// Con sensor, pero todavía no hay serie suficiente para armar el vector.
    case serieInsuficiente
    /// El artefacto no cargó, o su contrato no cuadra con lo que la app calcula.
    case sinModelo(detalle: String)
    /// El modelo contestó algo que no es una glucosa posible. No se enseña y no se recorta a
    /// los límites: un valor recortado se lee como una predicción y es un síntoma.
    case fueraDeRango(valorMgDl: Double)
}

/// La predicción a 30 y 60 minutos, calculada **en el teléfono** (C-16).
///
/// Tres decisiones que conviene leer antes del código:
///
/// 1. **Solo en modo sensor.** El juego denso se construye sobre la serie continua; sin ella,
///    un modelo que depende de rezagos entrega basura con apariencia de predicción. En modo sin
///    sensor no hay número y la pantalla lo declara (RF-10b).
/// 2. **La fila se arma en el instante de la última lectura del sensor, no en el del reloj.**
///    Es la decisión que más cambia el resultado y la que menos se nota. El entrenamiento armó
///    cada fila sobre el instante de una lectura, así que `mg_dl` nunca faltaba; con el reloj
///    de pared, pasados 2.5 minutos —media muestra— `mg_dl` queda en `NaN` y los rezagos
///    resuelven a la lectura equivocada. Medido sobre `m1-v0.2.0-simulador`: eso pasa el 47 %
///    de las veces y en esas filas el RMSE va de 11.9 a 125.2 mg/dL, con el modelo contestando
///    su propia media. Era el error que tenía `GET /predict` y se arregló ahí también.
/// 3. **Nada se recorta en silencio.** Si el modelo devuelve algo imposible se dice que no hay
///    predicción, con el valor, en lugar de pegarlo al límite del rango.
nonisolated struct CalcularPrediccion: Sendable {
    let lecturas: any RepositorioLecturas
    let comidas: any RepositorioComidas
    let dosis: any RepositorioDosis
    /// Opcional, como en `ConsultarInicio`: sin perfil los umbrales son los de por omisión.
    /// No se exige un repositorio para poder predecir, y así nadie tiene que fabricar un
    /// perfil vacío solo para pedir un número.
    let perfil: (any RepositorioPerfil)?
    /// Uno por horizonte. Vacío si ninguno cargó, y entonces no hay predicción y se dice.
    let modelos: [any RepositorioModelo]

    /// Cuánta serie hace falta **antes de la base**. El rezago más largo es de 60 minutos y la
    /// media más larga también, más la media muestra de tolerancia: con 90 sobra y sigue siendo
    /// barato. La consulta le suma la frescura, porque la base puede tener quince minutos.
    static let ventanaSerieMin = 90.0

    /// - Parameter modo: lo decide `ConsultarModo` con la regla de frescura, y se pasa en lugar
    ///   de recalcularlo para que no haya dos respuestas distintas en la misma pantalla.
    /// - Parameter ahora: se pasa, no se toma de `Date()` dentro, para poder probarlo.
    func ejecutar(
        modo: ModoApp, ahora: Date = Date()
    ) async throws -> Result<[Proyeccion], SinProyeccion> {
        guard modo == .sensor else { return .failure(.sinSensor) }
        guard !modelos.isEmpty else {
            return .failure(.sinModelo(detalle: "no se cargó ningún artefacto"))
        }

        // La serie, de una sola consulta, y de ahí sale la base. `hasta: ahora` deja fuera
        // cualquier lectura con fecha futura: HealthKit entrega lo que la app del fabricante
        // escribió, y una marca adelantada por un reloj mal puesto daría una predicción sobre
        // un instante que ya pasó.
        //
        // La ventana lleva la frescura sumada porque la base puede tener hasta quince minutos
        // y el vector necesita noventa **antes de la base**, no antes del reloj.
        let desde = ahora.addingTimeInterval(
            -(Self.ventanaSerieMin + ConfiguracionDominio.frescuraSensorMin) * 60
        )
        let serie = try await lecturas.entre(desde: desde, hasta: ahora)
            // Solo la serie continua y sin atípicas. Mezclar pinchazos metería rezagos falsos:
            // es lo que hace `solo_sensor` en el entrenamiento, y las atípicas las deja fuera
            // `_validas` del pipeline.
            .filter { ($0.origen == .sensor || $0.origen == .healthkit) && !$0.atipica }

        // Viene ordenada de la más vieja a la más nueva, así que la base es la última. No es
        // necesariamente la última lectura que la persona tomó: un pinchazo capturado hace un
        // minuto no entra al juego denso, que se construye sobre la serie continua.
        guard let base = serie.last else { return .failure(.serieInsuficiente) }

        let vector = VectorDeCaracteristicas.denso(
            serie: serie,
            comidas: try await comidas.recientes(
                horas: Double(ConfiguracionDominio.absorcionConfigurableMin.upperBound) / 60,
                hasta: base.tsUtc
            ),
            dosis: try await dosis.recientes(
                horas: ConfiguracionDominio.duracionAccionConfigurableH.upperBound,
                hasta: base.tsUtc
            ),
            ahora: base.tsUtc,
            // La zona de la lectura, no la del teléfono de hoy: quien viajó tiene lecturas de
            // dos zonas y la hora que vale es la que era para esa persona (regla 5).
            zona: TimeZone(identifier: base.zonaHoraria) ?? .current
        )
        // Con el instante de la lectura como base esto no debería faltar nunca; si falta, algo
        // se rompió antes y es mejor no enseñar nada que enseñar un número sacado de la media.
        guard let actual = vector["mg_dl"], actual.isFinite else {
            return .failure(.serieInsuficiente)
        }

        let delPerfil = try? await perfil?.actual()
        let umbralHipo = delPerfil?.umbralHipo ?? ConfiguracionDominio.umbralHipoPorOmision
        let umbralHiper = delPerfil?.umbralHiper ?? ConfiguracionDominio.umbralHiperPorOmision

        var proyecciones: [Proyeccion] = []
        for modelo in modelos.sorted(by: { $0.descrito.horizonteMin < $1.descrito.horizonteMin }) {
            let valor: Double
            do {
                valor = try await modelo.predecir(VectorDeCaracteristicas.paraCoreML(vector))
            } catch let error as ErrorModelo {
                return .failure(.sinModelo(detalle: String(describing: error)))
            } catch let error as ErrorDeCaracteristicas {
                return .failure(.sinModelo(detalle: String(describing: error)))
            }
            guard (ConfiguracionDominio.glucosaMinima...ConfiguracionDominio.glucosaMaxima)
                .contains(valor)
            else {
                return .failure(.fueraDeRango(valorMgDl: valor))
            }
            proyecciones.append(
                Proyeccion(
                    horizonteMin: modelo.descrito.horizonteMin,
                    valorMgDl: valor,
                    objetivo: base.tsUtc.addingTimeInterval(
                        Double(modelo.descrito.horizonteMin) * 60
                    ),
                    base: Proyeccion.Base(ts: base.tsUtc, mgDl: base.mgDl),
                    versionModelo: modelo.descrito.version,
                    aviso: Self.aviso(
                        valorMgDl: valor, umbralHipo: umbralHipo, umbralHiper: umbralHiper
                    )
                )
            )
        }
        return .success(proyecciones)
    }

    /// El aviso sale de comparar el número con el umbral **del perfil**, no con el de por
    /// omisión: quien puso su umbral en 80 quiere que se le avise en 80.
    static func aviso(
        valorMgDl: Double, umbralHipo: Double, umbralHiper: Double
    ) -> AvisoPrevisto? {
        if valorMgDl < umbralHipo { return .bajaPrevista }
        if valorMgDl > umbralHiper { return .altaPrevista }
        return nil
    }
}
