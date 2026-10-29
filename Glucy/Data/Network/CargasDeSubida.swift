import Foundation

// Lo que de verdad sube al backend, y nada más.
//
// Son estructuras **aparte** de los `…Dato` del dominio, y eso es a propósito. Si subiera el
// `Dato` completo con un `JSONEncoder` configurado en snake_case, cualquier campo nuevo en el
// dominio empezaría a viajar sin que nadie lo decidiera. Y entre esos campos están `nota`,
// `nombre`, `apellidos` y `pesoKg`, que **nunca salen del teléfono** (regla 3).
//
// Con estas estructuras lo que viaja está escrito campo por campo: agregar uno es un cambio
// visible en el diff. El servidor además rechaza lo que no reconoce (`extra="forbid"`), así que
// un campo de más no se ignora en silencio: manda el renglón a cuarentena con su motivo.
//
// Los nombres son los de las columnas del servidor (decisión 2.1 del paso 1 del backend) y los
// valores de los enums ya coinciden con los del Python, así que no se traduce nada.

// MARK: - Lecturas de glucosa

/// Las seis columnas de `glucose_readings` que llena el teléfono.
///
/// De los dieciséis campos de `LecturaGlucosaDato` suben siete. Se quedan: `nota` (regla 3),
/// `confianzaOcr` y `valorLeidoOcr` porque no deciden nada (D-11) y `origen` ya dice que vino
/// de una foto, `atipica` porque el pipeline la recalcula, y las banderas que solo tienen
/// sentido en el teléfono.
nonisolated struct LecturaSubida: Codable, Sendable, Equatable {
    let uuid: UUID
    let tsUtc: Date
    let zonaHoraria: String
    let mgDl: Double
    let origen: Origen
    let contexto: ContextoComida?

    /// `contexto` es el único campo con nombre distinto a los dos lados: en Swift se llama
    /// así a secas y la columna es `contexto_comida`. Sin esta clave explícita el servidor
    /// lo rechazaría y el renglón acabaría en cuarentena sin que nada más fallara.
    enum CodingKeys: String, CodingKey {
        case uuid
        case tsUtc = "ts_utc"
        case zonaHoraria = "zona_horaria"
        case mgDl = "mg_dl"
        case origen
        case contexto = "contexto_comida"
    }

    init(_ dato: LecturaGlucosaDato) {
        uuid = dato.uuid
        tsUtc = dato.tsUtc
        zonaHoraria = dato.zonaHoraria
        mgDl = dato.mgDl
        origen = dato.origen
        contexto = dato.contexto
    }
}

// MARK: - Comidas

/// Las columnas de `meals` que llena el teléfono.
///
/// **`carbsG` son los gramos totales, ya multiplicados por las porciones.** `porciones`
/// viaja solo como información: si el servidor volviera a multiplicar, los carbohidratos
/// activos saldrían al doble y nadie lo notaría hasta ver las métricas raras (caso P-11).
///
/// `proteinaG`, `grasaG` y `fibraG` no se mandan porque la app no las captura; son columnas
/// del servidor y se quedan nulas.
nonisolated struct ComidaSubida: Codable, Sendable, Equatable {
    let uuid: UUID
    let tsUtc: Date
    let zonaHoraria: String
    let carbsG: Double
    let origen: Origen
    let tiempoAbsorcionMin: Int
    let porciones: Double
    let codigoBarras: String?

    enum CodingKeys: String, CodingKey {
        case uuid
        case tsUtc = "ts_utc"
        case zonaHoraria = "zona_horaria"
        case carbsG = "carbs_g"
        case origen
        case tiempoAbsorcionMin = "tiempo_absorcion_min"
        case porciones
        case codigoBarras = "codigo_barras"
    }

    init(_ dato: ComidaDato) {
        uuid = dato.uuid
        tsUtc = dato.tsUtc
        zonaHoraria = dato.zonaHoraria
        carbsG = dato.carbsG
        origen = dato.origen
        tiempoAbsorcionMin = dato.tiempoAbsorcionMin
        porciones = dato.porciones
        codigoBarras = dato.codigoBarras
    }
}

// MARK: - Dosis de insulina

/// Las columnas de `insulin_doses` que llena el teléfono.
///
/// Es una dosis que la persona **dice haberse aplicado**. Ninguno de los campos que
/// necesitaría una calculadora de bolo está aquí, ni va a estar (regla 7).
nonisolated struct DosisSubida: Codable, Sendable, Equatable {
    let uuid: UUID
    let tsUtc: Date
    let zonaHoraria: String
    let unidades: Double
    let tipo: TipoInsulina
    let motivo: MotivoDosis?

    enum CodingKeys: String, CodingKey {
        case uuid
        case tsUtc = "ts_utc"
        case zonaHoraria = "zona_horaria"
        case unidades
        case tipo
        case motivo
    }

    init(_ dato: DosisInsulinaDato) {
        uuid = dato.uuid
        tsUtc = dato.tsUtc
        zonaHoraria = dato.zonaHoraria
        unidades = dato.unidades
        tipo = dato.tipo
        motivo = dato.motivo
    }
}

// MARK: - Perfil

/// Los seis parámetros clínicos del perfil, y ni uno más (C-7).
///
/// Es la carga reducida que anticipaba `PerfilDato`: el pipeline necesita los umbrales y la
/// duración de acción de la insulina para el IOB y para derivar la alerta, y no tenían por
/// dónde llegar. Lo que identifica a la persona —nombre, apellidos, peso, notas— **no está
/// en esta estructura**, así que no puede viajar por descuido.
///
/// De la fecha de nacimiento sube **solo el año**: para calcular la edad sobra, y el día
/// exacto es un dato identificador de más.
nonisolated struct PerfilSubido: Codable, Sendable, Equatable {
    let tipoUsuario: TipoUsuario
    let anioNacimiento: Int
    let umbralHipo: Double
    let umbralHiper: Double
    let tipoInsulinaRapida: String?
    let duracionAccionInsulina: Double

    enum CodingKeys: String, CodingKey {
        case tipoUsuario = "tipo_usuario"
        case anioNacimiento = "anio_nacimiento"
        case umbralHipo = "umbral_hipo"
        case umbralHiper = "umbral_hiper"
        case tipoInsulinaRapida = "tipo_insulina_rapida"
        case duracionAccionInsulina = "duracion_accion_insulina"
    }

    init(_ dato: PerfilDato, calendario: Calendar = Calendar(identifier: .gregorian)) {
        tipoUsuario = dato.tipoUsuario
        anioNacimiento = calendario.component(.year, from: dato.fechaNacimiento)
        umbralHipo = dato.umbralHipo
        umbralHiper = dato.umbralHiper
        tipoInsulinaRapida = dato.tipoInsulinaRapida
        duracionAccionInsulina = dato.duracionAccionInsulinaH
    }
}

// MARK: - El sobre y la respuesta

/// El sobre de los tres POST de lote: `{"items": [...]}`.
nonisolated struct Lote<Renglon: Encodable & Sendable>: Encodable, Sendable {
    let items: [Renglon]
}

/// Un renglón que el servidor no aceptó, con su motivo.
///
/// Lleva el motivo y no solo el uuid porque un dato rechazado sin rastro es una falla
/// invisible (RF-22): el teléfono lo guarda en la cola para poder mostrarlo.
nonisolated struct RenglonEnCuarentena: Decodable, Sendable, Equatable {
    /// `nil` cuando el renglón ni siquiera traía un uuid legible.
    let uuid: UUID?
    let motivo: String
}

/// La respuesta de los tres POST de lote. **Cada renglón sale en exactamente una lista.**
nonisolated struct RespuestaLote: Decodable, Sendable, Equatable {
    let aceptados: [UUID]
    let duplicados: [UUID]
    let cuarentena: [RenglonEnCuarentena]

    /// Aceptado y duplicado terminan igual de bien: el dato ya está del otro lado.
    ///
    /// Un uuid repetido **no es un conflicto**, es un duplicado, y la app reintenta lotes a
    /// propósito. Si un duplicado contara como error, un reintento normal dejaría media cola
    /// marcada en rojo.
    var resueltos: [UUID] { aceptados + duplicados }
}
