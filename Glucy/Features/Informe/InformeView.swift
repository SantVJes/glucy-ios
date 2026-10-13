import SwiftUI

/// La hoja del informe para el médico. Es una vista normal, con los mismos tokens que el
/// resto de la app, y es la que se rasteriza a PDF (RF-16).
///
/// Va siempre en claro y con la letra de tamaño normal: es una hoja para leer en una
/// consulta, no una pantalla. Y sale en mg/dL, que es la unidad interna.
struct InformeView: View {
    let informe: Informe

    /// El ancho de una hoja carta, en puntos.
    static let anchoDeHoja: CGFloat = 612

    var body: some View {
        VStack(alignment: .leading, spacing: Tema.Espacio.entreTarjetas) {
            encabezado
            if let identidad = informe.identidad { bloqueDeIdentidad(identidad) }
            cifras
            diaTipico
            registros
            aviso
        }
        .padding(Tema.Espacio.margenLateral * 2)
        .frame(width: Self.anchoDeHoja, alignment: .leading)
        .background(Tema.Colores.superficie)
        .environment(\.colorScheme, .light)
        .dynamicTypeSize(.large)
    }

    // MARK: - Partes

    private var encabezado: some View {
        VStack(alignment: .leading, spacing: Tema.Espacio.unidad) {
            Text("Informe de glucosa")
                .font(.system(.title, weight: .bold))
                .foregroundStyle(Tema.Colores.azulProfundo)
            Text("Del \(fecha(informe.desde)) al \(fecha(informe.hasta)) · \(TextosDeIndicadores.dias(informe.periodoDias))")
                .font(Tema.Tipografia.tituloTarjeta)
                .foregroundStyle(Tema.Colores.textoPrincipal)
            Text("Generado el \(fechaYHora(informe.generadoTsUtc)) · zona horaria \(informe.zonaHoraria)")
                .font(Tema.Tipografia.etiqueta)
                .foregroundStyle(Tema.Colores.textoSecundario)
        }
    }

    /// Solo existe si la persona encendió el interruptor.
    private func bloqueDeIdentidad(_ identidad: IdentidadDelInforme) -> some View {
        let nombre = [identidad.nombre, identidad.apellidos]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return bloque("Datos de la persona") {
            if !nombre.isEmpty { renglon("Nombre", nombre) }
            renglon("Año de nacimiento", String(identidad.anioNacimiento))
            if let peso = identidad.pesoKg {
                renglon("Peso", "\(peso == peso.rounded() ? String(Int(peso)) : String(peso)) kg")
            }
        }
    }

    /// Las tres cifras, cada una con sobre cuántas mediciones se calculó. La que todavía no
    /// significa nada no se presenta como si lo hiciera: se dice qué le falta.
    private var cifras: some View {
        bloque("Indicadores del periodo") {
            if let indicadores = informe.indicadores.indicadores {
                let sobre = TextosDeIndicadores.sobre(indicadores.n)
                let dias = TextosDeIndicadores.dias(informe.indicadores.diasConLecturas)
                renglon(
                    "Tiempo en rango (70–180 mg/dL)",
                    "\(TextosDeIndicadores.entero(indicadores.tir)) %", "\(sobre) de \(dias)"
                )
                renglon("Promedio", "\(TextosDeIndicadores.entero(indicadores.promedio)) mg/dL", sobre)
                if let gmi = informe.indicadores.gmi {
                    renglon("GMI", "\(String(format: "%.1f", gmi)) %", "estimación de A1c · \(sobre)")
                } else {
                    renglon("GMI", "No se calcula todavía", TextosDeIndicadores.gmiNoFiable)
                }
            } else {
                Text(TextosDeIndicadores.faltanDias)
                    .font(Tema.Tipografia.textoLectura)
                    .foregroundStyle(Tema.Colores.textoPrincipal)
                Text(TextosDeIndicadores.diasQueLlevas(informe.indicadores.diasConLecturas))
                    .font(Tema.Tipografia.textoLectura)
                    .foregroundStyle(Tema.Colores.textoSecundario)
            }
        }
    }

    /// La misma gráfica de Historial: no hay dos maneras de dibujar el día típico.
    @ViewBuilder
    private var diaTipico: some View {
        if informe.indicadores.indicadores != nil {
            bloque("Día típico") {
                Text("La marca oscura es la mediana de cada hora; la banda, entre qué valores "
                    + "cae la mitad de las mediciones (percentiles 25 y 75).")
                    .font(Tema.Tipografia.etiqueta)
                    .foregroundStyle(Tema.Colores.textoSecundario)
                GraficaGlucosa(contenido: .diaTipico(informe.diaTipico), resumen: "Día típico")
                if informe.horasSinDatos > 0 {
                    Text("\(informe.horasSinDatos) de las 24 horas no tienen suficientes "
                        + "mediciones y se quedan en blanco. No se rellenan.")
                        .font(Tema.Tipografia.etiqueta)
                        .foregroundStyle(Tema.Colores.textoSecundario)
                }
            }
        }
    }

    /// Cuánto de esto es un sensor y cuánto son pinchazos cambia cómo se lee toda la hoja.
    private var registros: some View {
        bloque("Lo que se registró en el periodo") {
            renglon("Lecturas de glucosa", String(informe.conteos.lecturas))
            ForEach(Self.origenesDeLectura, id: \.self) { origen in
                if let cuantas = informe.conteos.lecturasPorOrigen[origen], cuantas > 0 {
                    renglon("    \(Self.nombre(de: origen))", String(cuantas))
                }
            }
            renglon("Comidas", String(informe.conteos.comidas))
            renglon("Dosis de insulina", String(informe.conteos.dosis))
        }
    }

    /// Con todas sus letras y no en letra chica.
    private var aviso: some View {
        Text("Glucy no es un dispositivo médico certificado. Estas cifras las registró la persona "
            + "y no sustituyen una medición de laboratorio ni una indicación médica.")
            .font(Tema.Tipografia.textoLectura)
            .foregroundStyle(Tema.Colores.textoPrincipal)
            .padding(Tema.Espacio.interior)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(
                RoundedRectangle(cornerRadius: Tema.Radio.campo)
                    .stroke(Tema.Colores.textoSecundario, lineWidth: 1)
            )
    }

    // MARK: - Piezas

    private func bloque(_ titulo: String, @ViewBuilder _ contenido: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Tema.Espacio.unidad * 2) {
            Text(titulo)
                .font(Tema.Tipografia.tituloTarjeta)
                .foregroundStyle(Tema.Colores.azulProfundo)
            contenido()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func renglon(_ etiqueta: String, _ valor: String, _ pie: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(etiqueta)
                    .font(Tema.Tipografia.textoLectura)
                    .foregroundStyle(Tema.Colores.textoPrincipal)
                Spacer(minLength: Tema.Espacio.interior)
                Text(valor)
                    .font(Tema.Tipografia.valorFila)
                    .foregroundStyle(Tema.Colores.textoPrincipal)
            }
            if let pie {
                Text(pie)
                    .font(Tema.Tipografia.etiqueta)
                    .foregroundStyle(Tema.Colores.textoSecundario)
            }
        }
    }

    // MARK: - Formato

    private static let origenesDeLectura: [Origen] = [.sensor, .healthkit, .manual, .fotoGlucometro]

    private static func nombre(de origen: Origen) -> String {
        switch origen {
        case .sensor: "del sensor"
        case .healthkit: "de Salud"
        case .manual: "a mano"
        case .fotoGlucometro: "por foto del glucómetro"
        case .barcode, .ocrEtiqueta: "otro origen"
        }
    }

    private func fecha(_ fecha: Date) -> String {
        fecha.formatted(date: .long, time: .omitted)
    }

    private func fechaYHora(_ fecha: Date) -> String {
        fecha.formatted(date: .long, time: .shortened)
    }
}
