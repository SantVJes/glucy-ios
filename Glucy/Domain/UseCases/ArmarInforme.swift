import Foundation

/// Quién es la persona, para el encabezado del informe. Solo existe si ella lo pidió.
nonisolated struct IdentidadDelInforme: Sendable, Equatable {
    let nombre: String
    let apellidos: String
    /// Solo el año: es todo lo que la app sabe de su nacimiento (F-1).
    let anioNacimiento: Int
    let pesoKg: Double?
}

/// Las tres cifras del periodo, tal como las resolvió `ConsultarHistorial`.
nonisolated struct IndicadoresDelPeriodo: Sendable, Equatable {
    /// `nil` cuando no hay tres días con mediciones. El informe lo dice; no pone un cero.
    let indicadores: Indicadores?
    let diasConLecturas: Int
    /// Con menos de catorce días el GMI no significa nada y el informe no lo presenta.
    let gmiEsFiable: Bool

    /// El GMI que se puede enseñar. `nil` mientras no sea fiable: presentar el de tres días
    /// como si fuera un GMI es desinformar a quien lo va a leer en una consulta.
    var gmi: Double? {
        gmiEsFiable ? indicadores?.gmi : nil
    }
}

nonisolated struct ConteosDelPeriodo: Sendable, Equatable {
    let lecturas: Int
    let comidas: Int
    let dosis: Int
    /// Cuántas lecturas por origen. Es lo que le dice al médico cuánto de esto es sensor y
    /// cuánto son pinchazos, que cambia cómo se lee el resto de la hoja.
    let lecturasPorOrigen: [Origen: Int]
}

/// Lo que lleva el informe para el médico.
///
/// No tiene dónde llevar las notas ni el identificador interno del perfil: lo que no le dice
/// nada a un médico no sale del teléfono. Tampoco ninguna predicción: en la fase 1 no hay
/// modelo.
nonisolated struct Informe: Sendable, Equatable {
    let periodoDias: Int
    let desde: Date
    let hasta: Date
    let generadoTsUtc: Date
    /// Identificador de `TimeZone` del dispositivo (regla 5).
    let zonaHoraria: String
    /// `nil` cuando la persona no quiso incluir sus datos. No es un campo vacío: es que no va.
    let identidad: IdentidadDelInforme?
    let indicadores: IndicadoresDelPeriodo
    let diaTipico: [HoraTipica]
    let horasSinDatos: Int
    let conteos: ConteosDelPeriodo
}

/// Lo que lleva el informe del médico. Se arma en el dominio y no sabe que existe un PDF:
/// así se puede probar sin rasterizar nada (RF-16).
nonisolated struct ArmarInforme: Sendable {
    let historial: ConsultarHistorial
    let lecturas: any RepositorioLecturas
    let comidas: any RepositorioComidas
    let dosis: any RepositorioDosis
    let perfil: any RepositorioPerfil

    /// - Parameter dias: el periodo elegido en Historial. No se vuelve a preguntar.
    /// - Parameter conIdentidad: si `false`, el informe no trae nombre, apellidos, año de
    ///   nacimiento ni peso. Compartir el archivo es la persona entregando sus propios datos
    ///   a quien ella decide, no una subida (regla 3), pero la decisión tiene que ser suya.
    /// - Parameter ahora: se pasa, no se toma de `Date()` dentro, para poder probarlo.
    func ejecutar(dias: Int, conIdentidad: Bool, ahora: Date) async throws -> Informe {
        // Las cifras no se recalculan: son las mismas que la pantalla acaba de enseñar. Si el
        // informe y la pantalla pudieran dar números distintos, algún día los darían.
        let estado = try await historial.ejecutar(periodoDias: dias, ahora: ahora)

        let horas = Double(dias) * 24
        let desde = ahora.addingTimeInterval(-horas * 3600)
        let delPeriodo = try await lecturas.entre(desde: desde, hasta: ahora)
        var porOrigen: [Origen: Int] = [:]
        for lectura in delPeriodo {
            porOrigen[lectura.origen, default: 0] += 1
        }

        var identidad: IdentidadDelInforme?
        if conIdentidad, let actual = try await perfil.actual() {
            identidad = IdentidadDelInforme(
                nombre: actual.nombre,
                apellidos: actual.apellidos,
                anioNacimiento: ReglasDePerfil.anio(de: actual.fechaNacimiento),
                pesoKg: actual.pesoKg
            )
        }

        return Informe(
            periodoDias: dias,
            desde: desde,
            hasta: ahora,
            generadoTsUtc: ahora,
            zonaHoraria: TimeZone.current.identifier,
            identidad: identidad,
            indicadores: IndicadoresDelPeriodo(
                indicadores: estado.indicadores,
                diasConLecturas: estado.diasConLecturas,
                gmiEsFiable: estado.gmiEsFiable
            ),
            diaTipico: estado.diaTipico,
            horasSinDatos: estado.horasSinDatos,
            conteos: ConteosDelPeriodo(
                lecturas: delPeriodo.count,
                comidas: try await comidas.recientes(horas: horas, hasta: ahora).count,
                dosis: try await dosis.recientes(horas: horas, hasta: ahora).count,
                lecturasPorOrigen: porOrigen
            )
        )
    }
}
