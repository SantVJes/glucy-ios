import Accessibility
import Charts
import SwiftUI

/// A qué serie pertenece un punto de la gráfica. De esto depende cómo se dibuja, y es
/// la regla que no se puede romper: lo medido y lo proyectado **nunca** se parecen
/// (RF-10, y el requisito no funcional de honestidad de la predicción).
nonisolated enum SerieGrafica: String, Sendable, CaseIterable {
    /// Línea continua. Es un dato que existió.
    case medida
    /// Línea punteada y más delgada. Es un cálculo. **En la fase 1 nunca se produce.**
    case proyectada
}

nonisolated struct PuntoGrafica: Sendable, Equatable, Identifiable {
    let id: UUID
    let ts: Date
    let mgDl: Double
    let serie: SerieGrafica
    /// Para poder desglosar por origen en la fase 6 (RF-32) sin tocar la gráfica.
    let origen: Origen
}

nonisolated enum TramosDeSerie {
    /// Parte una serie ordenada allí donde el hueco entre dos puntos pasa de
    /// `interpolacionMaximaMin`. Cada tramo se dibuja como una línea aparte, así que un
    /// hueco se ve como un hueco en lugar de como una recta que nadie midió (RF-06b).
    static func partir(
        _ puntos: [PuntoGrafica],
        huecoMaximoMin: Double = ConfiguracionDominio.interpolacionMaximaMin
    ) -> [[PuntoGrafica]] {
        var tramos: [[PuntoGrafica]] = []
        for punto in puntos {
            if let anterior = tramos.last?.last,
               punto.ts.timeIntervalSince(anterior.ts) / 60 <= huecoMaximoMin {
                tramos[tramos.count - 1].append(punto)
            } else {
                tramos.append([punto])
            }
        }
        return tramos
    }
}

/// Lo que la gráfica puede enseñar. Las dos pantallas usan la misma gráfica para que la
/// banda, la escala y la accesibilidad sean una sola cosa y no dos que se separan.
nonisolated enum ContenidoGrafica: Sendable, Equatable {
    /// La glucosa en el tiempo. `unirConLinea` solo es `true` en modo sensor.
    case serie(tramos: [[PuntoGrafica]], unirConLinea: Bool, ventana: ClosedRange<Date>)
    /// La mediana y la banda P25–P75 de cada hora que tiene suficientes mediciones.
    case diaTipico([HoraTipica])
}

/// La gráfica de glucosa de Inicio y de Historial.
///
/// Nunca dibuja algo que no se midió: sin sensor no hay línea entre los puntos, con sensor
/// un hueco corta la línea, y en el día típico una hora sin datos se queda en blanco.
struct GraficaGlucosa: View {
    let contenido: ContenidoGrafica
    /// Una frase con cada cifra y su unidad. Es lo que VoiceOver dice de la gráfica.
    let resumen: String

    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento

    private static let escala = ConfiguracionDominio.escalaGraficaMgDl
    private static let objetivo = ConfiguracionDominio.rangoObjetivo
    private static let alto = Tema.Espacio.unidad * 55

    var body: some View {
        grafica
            .chartYScale(domain: Self.escala)
            .chartYAxis {
                AxisMarks(
                    position: .leading,
                    values: [
                        Self.escala.lowerBound, Self.objetivo.lowerBound,
                        Self.objetivo.upperBound, Self.escala.upperBound,
                    ]
                ) {
                    AxisGridLine().foregroundStyle(Tema.Colores.textoSecundario.opacity(0.3))
                    AxisValueLabel().foregroundStyle(Tema.Colores.textoSecundario)
                }
            }
            .frame(height: Self.alto)
            // Con «reducir movimiento» la gráfica no se anima al cambiar: aparece.
            .animation(reducirMovimiento ? nil : .easeInOut, value: contenido)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(resumen)
            // Lo que enciende Audio Graphs: sin esto VoiceOver anuncia «gráfica» y nada
            // más, y la curva no existe para quien no la ve.
            .accessibilityChartDescriptor(DescriptorDeGrafica(contenido: contenido, resumen: resumen))
            .accessibilityIdentifier("graficaGlucosa")
    }

    @ViewBuilder
    private var grafica: some View {
        switch contenido {
        case let .serie(tramos, unirConLinea, ventana):
            Chart {
                bandaObjetivo
                if unirConLinea {
                    // Modo sensor: la serie es continua y la recta entre dos muestras
                    // seguidas sí describe lo que pasó. Un `LineMark` por tramo, con su
                    // propia `series`, para que el hueco corte la línea (RF-06b).
                    ForEach(Array(tramos.enumerated()), id: \.offset) { indice, tramo in
                        ForEach(tramo) { punto in
                            LineMark(
                                x: .value("Hora", punto.ts),
                                y: .value("Glucosa", Self.enEscala(punto.mgDl)),
                                series: .value("Tramo", "\(punto.serie.rawValue)-\(indice)")
                            )
                            .lineStyle(Self.trazo(de: punto.serie))
                            .foregroundStyle(Tema.Colores.azulPrimario)
                        }
                    }
                }
                // Un punto por cada medición real. Sin sensor es lo único que hay: unir dos
                // pinchazos separados por horas dibujaría una glucosa que nadie midió
                // (RF-23).
                ForEach(tramos.flatMap { $0 }.filter { $0.serie == .medida }) { punto in
                    PointMark(
                        x: .value("Hora", punto.ts),
                        y: .value("Glucosa", Self.enEscala(punto.mgDl))
                    )
                    // Lo que se sale de la escala se queda en el borde, con otra forma.
                    .symbol(Self.escala.contains(punto.mgDl)
                        ? BasicChartSymbolShape.circle : BasicChartSymbolShape.triangle)
                    .symbolSize(unirConLinea ? 24 : 70)
                    .foregroundStyle(Tema.Colores.azulPrimario)
                }
            }
            .chartXScale(domain: ventana)
            .chartXAxis {
                if ventana.upperBound.timeIntervalSince(ventana.lowerBound) > 86_400 {
                    AxisMarks(values: .stride(by: .day)) {
                        AxisGridLine().foregroundStyle(Tema.Colores.textoSecundario.opacity(0.3))
                        AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                            .foregroundStyle(Tema.Colores.textoSecundario)
                    }
                } else {
                    AxisMarks(values: .stride(by: .hour)) {
                        AxisGridLine().foregroundStyle(Tema.Colores.textoSecundario.opacity(0.3))
                        AxisValueLabel(format: .dateTime.hour().minute())
                            .foregroundStyle(Tema.Colores.textoSecundario)
                    }
                }
            }

        case let .diaTipico(horas):
            Chart {
                bandaObjetivo
                // Cada hora es un bloque suelto, sin nada que la una con la de al lado: una
                // hora sin suficientes mediciones se queda en blanco.
                ForEach(horas) { hora in
                    RectangleMark(
                        xStart: .value("Hora", Double(hora.hora) + 0.1),
                        xEnd: .value("Hora", Double(hora.hora) + 0.9),
                        yStart: .value("Percentil 25", Self.enEscala(hora.p25)),
                        yEnd: .value("Percentil 75", Self.enEscala(hora.p75))
                    )
                    .foregroundStyle(Tema.Colores.azulPrimario.opacity(0.35))

                    RuleMark(
                        xStart: .value("Hora", Double(hora.hora) + 0.1),
                        xEnd: .value("Hora", Double(hora.hora) + 0.9),
                        y: .value("Mediana", Self.enEscala(hora.mediana))
                    )
                    .lineStyle(StrokeStyle(lineWidth: 3))
                    .foregroundStyle(Tema.Colores.azulProfundo)
                }
            }
            .chartXScale(domain: 0.0...24.0)
            .chartXAxis {
                AxisMarks(values: [0.0, 6.0, 12.0, 18.0, 24.0]) { valor in
                    AxisGridLine().foregroundStyle(Tema.Colores.textoSecundario.opacity(0.3))
                    AxisValueLabel {
                        if let hora = valor.as(Double.self) {
                            Text("\(Int(hora)) h")
                        }
                    }
                    .foregroundStyle(Tema.Colores.textoSecundario)
                }
            }
        }
    }

    /// El rango objetivo, **detrás** de la serie. Lleva su etiqueta porque en escala de
    /// grises la banda se vuelve un gris claro y sin ella nadie sabe qué es.
    @ChartContentBuilder
    private var bandaObjetivo: some ChartContent {
        RectangleMark(
            yStart: .value("Desde", Self.objetivo.lowerBound),
            yEnd: .value("Hasta", Self.objetivo.upperBound)
        )
        .foregroundStyle(Tema.Colores.enRango.opacity(0.12))
        .annotation(position: .overlay, alignment: .topLeading) {
            Text(Self.etiquetaDeLaBanda)
                .font(Tema.Tipografia.etiqueta)
                .foregroundStyle(Tema.Colores.textoPrincipal)
                .padding(Tema.Espacio.unidad)
        }
    }

    static let etiquetaDeLaBanda =
        "\(Int(objetivo.lowerBound))–\(Int(objetivo.upperBound)) · tu rango objetivo"

    private static func enEscala(_ mgDl: Double) -> Double {
        min(max(mgDl, escala.lowerBound), escala.upperBound)
    }

    /// Lo medido, continuo. Lo proyectado, punteado **y más delgado**: quien no distingue el
    /// color distingue el grosor, y quien ve borroso de madrugada distingue el trazo.
    private static func trazo(de serie: SerieGrafica) -> StrokeStyle {
        switch serie {
        case .medida: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
        case .proyectada: StrokeStyle(lineWidth: 1.5, dash: [5, 4])
        }
    }
}

/// La gráfica para quien no la ve: es lo que Audio Graphs reproduce con sonido.
///
/// Lleva los valores verdaderos, no los recortados a la escala del dibujo.
nonisolated struct DescriptorDeGrafica: AXChartDescriptorRepresentable {
    let contenido: ContenidoGrafica
    let resumen: String

    func makeChartDescriptor() -> AXChartDescriptor {
        switch contenido {
        case let .serie(tramos, unirConLinea, ventana):
            let puntos = tramos.flatMap { $0 }
            let series = SerieGrafica.allCases.compactMap { serie -> AXDataSeriesDescriptor? in
                let suyos = puntos.filter { $0.serie == serie }
                guard !suyos.isEmpty else { return nil }
                return AXDataSeriesDescriptor(
                    name: serie == .medida ? "Glucosa medida" : "Glucosa proyectada",
                    isContinuous: unirConLinea,
                    dataPoints: suyos.map {
                        AXDataPoint(x: $0.ts.timeIntervalSince1970, y: $0.mgDl)
                    }
                )
            }
            return AXChartDescriptor(
                title: "Glucosa",
                summary: resumen,
                xAxis: AXNumericDataAxisDescriptor(
                    title: "Hora",
                    range: (ventana.lowerBound.timeIntervalSince1970)...(ventana.upperBound.timeIntervalSince1970),
                    gridlinePositions: [],
                    valueDescriptionProvider: { segundos in
                        Date(timeIntervalSince1970: segundos)
                            .formatted(date: .abbreviated, time: .shortened)
                    }
                ),
                yAxis: Self.ejeDeGlucosa(valores: puntos.map(\.mgDl)),
                series: series
            )

        case let .diaTipico(horas):
            func serie(_ nombre: String, _ valor: KeyPath<HoraTipica, Double>) -> AXDataSeriesDescriptor {
                AXDataSeriesDescriptor(
                    name: nombre,
                    // Las horas no se unen: entre dos con datos puede haber una en blanco.
                    isContinuous: false,
                    dataPoints: horas.map { AXDataPoint(x: Double($0.hora), y: $0[keyPath: valor]) }
                )
            }
            return AXChartDescriptor(
                title: "Tu día típico",
                summary: resumen,
                xAxis: AXNumericDataAxisDescriptor(
                    title: "Hora del día",
                    range: 0...23,
                    gridlinePositions: [],
                    valueDescriptionProvider: { "\(Int($0)) horas" }
                ),
                yAxis: Self.ejeDeGlucosa(valores: horas.flatMap { [$0.p25, $0.p75] }),
                series: [
                    serie("Mediana", \.mediana),
                    serie("Percentil 25", \.p25),
                    serie("Percentil 75", \.p75),
                ]
            )
        }
    }

    private static func ejeDeGlucosa(valores: [Double]) -> AXNumericDataAxisDescriptor {
        let escala = ConfiguracionDominio.escalaGraficaMgDl
        let minimo = min(escala.lowerBound, valores.min() ?? escala.lowerBound)
        let maximo = max(escala.upperBound, valores.max() ?? escala.upperBound)
        return AXNumericDataAxisDescriptor(
            title: "Glucosa",
            range: minimo...maximo,
            gridlinePositions: [],
            valueDescriptionProvider: { "\(Int($0.rounded())) miligramos por decilitro" }
        )
    }
}
