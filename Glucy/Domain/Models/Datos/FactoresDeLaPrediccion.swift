import Foundation

/// Una de las cinco cosas que más movieron la predicción, lista para enseñarse.
///
/// **El nombre llega hecho del servidor y la app no traduce nada.** Repetir en Swift el
/// diccionario de nombres de características lo deja viejo el día que el pipeline agrega una
/// columna, y nadie se entera hasta que alguien lee «rezago_45» en la pantalla.
nonisolated struct FactorDeLaPrediccion: Sendable, Equatable, Identifiable {
    var id: String { nombre }

    /// En palabras, por ejemplo «la insulina que sigue activa».
    let nombre: String
    /// Cuánto aportó, en mg/dL y con signo: positivo sube la estimación, negativo la baja.
    let mgDl: Double

    /// Si se puede enseñar.
    ///
    /// Un nombre que es el de una columna del modelo no es una frase: si llega así, el
    /// servidor no lo tradujo y es un error suyo. No se enseña y **no se inventa una
    /// traducción** (plan de la fase 3).
    ///
    /// Se comprueba contra la lista de características que la app ya tiene, que es el contrato
    /// con el pipeline, y no solo contra el guion bajo: `iob` y `cob` no llevan ninguno y son
    /// nombres de columna igual. El guion bajo se sigue mirando por lo que no esté en esa
    /// lista, como los nombres del juego disperso.
    var sePuedeEnsenar: Bool {
        guard !nombre.isEmpty, !nombre.contains("_") else { return false }
        return !VectorDeCaracteristicas.densas.contains(nombre)
    }

    /// Si empuja la glucosa hacia arriba. Va aparte del signo para que la pantalla no tenga
    /// que decidirlo: el color no es el único portador de la información y cada factor lleva
    /// además su flecha y su cifra.
    var sube: Bool { mgDl > 0 }
}

/// Una contribución SHAP en crudo, con el nombre de la columna del modelo.
///
/// Se guarda tal cual porque es lo que `POST /explain` necesita recibir: ahí los nombres son
/// el contrato con el pipeline y con glucy-ml, no texto para enseñar.
nonisolated struct ContribucionDeLaPrediccion: Sendable, Equatable, Codable {
    let variable: String
    let mgDl: Double
}

/// Lo que el servidor aportó sobre una predicción: los factores, la frase, y si su número
/// coincide con el del teléfono.
nonisolated struct FactoresYExplicacion: Sendable, Equatable {
    let horizonteMin: Int
    /// El número **del servidor**. El que la pantalla enseña es el del teléfono (C-16); este
    /// está aquí para poder compararlos.
    let valorDelServidorMgDl: Double
    /// El instante desde el que el servidor predijo. Si no es el mismo que usó el teléfono,
    /// los dos números no son comparables y no hay desacuerdo que registrar.
    let tsBase: Date?
    let factores: [FactorDeLaPrediccion]
    let shap: [ContribucionDeLaPrediccion]
    /// En español llano. `nil` cuando no llegó.
    let explicacion: String?
    /// Si la frase salió de la plantilla determinista y no del modelo de lenguaje (P-13). El
    /// reporte tiene que poder decir cuántas fueron de cada una.
    let deLaPlantilla: Bool
    /// Cuánto se separan los dos números, cuando los dos partieron del mismo instante. `nil`
    /// si no son comparables.
    ///
    /// **Un desacuerdo silencioso entre los dos caminos no lo ve nadie** hasta que alguien
    /// compara dos pantallas, así que se guarda en lugar de descartarse. La pantalla sigue
    /// enseñando el número del teléfono: es el que se calculó con la fila que el teléfono
    /// armó y el que sigue saliendo sin red.
    let desacuerdoMgDl: Double?

    /// Los factores que de verdad se pueden dibujar.
    var paraLaPantalla: [FactorDeLaPrediccion] {
        factores.filter(\.sePuedeEnsenar)
    }

    /// Lo que se guardó la última vez, para que la pantalla se pinte al instante y sin red.
    ///
    /// `tsBase` y el desacuerdo quedan en `nil` a propósito: de lo guardado no se sabe si los
    /// dos caminos partieron del mismo instante, y un desacuerdo que no se puede afirmar no se
    /// afirma. `valorDelServidorMgDl` lleva el valor propio porque solo se usa para contar el
    /// desacuerdo, que aquí no hay.
    static func deLoGuardado(_ guardado: PrediccionGuardadaDato) -> FactoresYExplicacion {
        FactoresYExplicacion(
            horizonteMin: guardado.horizonteMin,
            valorDelServidorMgDl: guardado.valorMgDl,
            tsBase: nil,
            factores: guardado.factores,
            shap: guardado.shap,
            explicacion: guardado.explicacion,
            deLaPlantilla: false,
            desacuerdoMgDl: nil
        )
    }
}
