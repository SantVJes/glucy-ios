import Foundation

/// Lo que el artefacto dice de sí mismo, leído del archivo y no escrito aquí.
///
/// Va junto al modelo y no en una constante de la app porque el artefacto se reemplaza sin
/// recompilar (RF-29: mensualmente o al detectar deriva del error). Una versión escrita a mano
/// en Swift se queda vieja el día que alguien copia un `.mlmodel` nuevo, y entonces la app
/// reporta una versión que no es la que calculó el número (RF-25).
nonisolated struct ModeloDescrito: Sendable, Equatable {
    /// Por ejemplo `v0.2.0-simulador`. Es lo que se guarda con cada predicción.
    let version: String
    /// 30 o 60. Sale del archivo: un modelo de 60 minutos cargado donde se esperaba el de 30
    /// predice bien y contesta otra pregunta.
    let horizonteMin: Int
    /// Los nombres de las entradas **tal como el artefacto las declara**, en el orden del
    /// contrato.
    let caracteristicas: [String]
    /// Si sus métricas pueden ir al documento final. Falso mientras el modelo esté entrenado
    /// con el simulador fisiológico y no con datos de personas (riesgo R-2).
    let metricasSePuedenReportar: Bool
}

/// El modelo predictivo, detrás de un protocolo para que el dominio no sepa que hay Core ML.
///
/// La inferencia corre **en el teléfono** (C-16): ningún dato de glucosa sale de aquí para
/// predecir, y la app predice en modo avión igual que con wifi (caso P-07).
nonisolated protocol RepositorioModelo: Sendable {
    /// Lo que el artefacto cargado declara de sí mismo.
    var descrito: ModeloDescrito { get }

    /// El número que sale del modelo, en mg/dL.
    ///
    /// - Parameter vector: el juego denso por nombre. Los huecos van como `NaN`, que es
    ///   información para el árbol y no un dato que falte por rellenar.
    func predecir(_ vector: [String: Double]) async throws -> Double
}

nonisolated enum ErrorModelo: Error, Equatable {
    /// El archivo no venía en el paquete de la app.
    case noEstaEnElPaquete(nombre: String)
    case noSePudoCargar(nombre: String, motivo: String)

    /// Las entradas que el artefacto declara no son las que la app calcula. **Es el error que
    /// este protocolo existe para atrapar**: con un nombre cambiado de sitio el modelo
    /// contesta un número plausible y equivocado, y nadie se entera.
    case contratoRoto(sobran: [String], faltan: [String])

    /// El artefacto no declara su horizonte o su versión en los metadatos. Sin eso no se puede
    /// cumplir RF-25, y una predicción sin versión no se puede auditar después.
    case metadatosIncompletos(falta: String)

    /// La salida no es la que se espera, o no es un número finito. Un `NaN` que llegara a la
    /// pantalla se dibujaría como un hueco o como un cero según quién lo lea.
    case salidaInesperada(detalle: String)
}
