import CoreGraphics
import Foundation

/// Cuál de los números de la pantalla es la glucosa.
///
/// Una pantalla de glucómetro no enseña un número: enseña la fecha, la hora, a veces la
/// unidad y a veces un promedio. El OCR los va a leer todos. **Elegir mal es peor que no
/// leer nada**, porque la persona confirma sin mirar.
///
/// Esta regla vive aparte de Vision a propósito: así se prueba sin imágenes, con una lista
/// de números escrita a mano.
nonisolated enum SeleccionDeNumero {

    /// La glucosa entre los números leídos, o `nil` si no hay ningún candidato válido, que
    /// es el caso de RF-03.
    ///
    /// El orden de la regla importa:
    ///
    /// 1. Se descarta lo que no sea un número entero.
    /// 2. Se descarta lo que esté fuera del rango fisiológico que ya conocen las reglas del
    ///    paso 1. Una fecha «12» se cae sola aquí.
    /// 3. De lo que queda gana **el de caja más alta**: en todo glucómetro el valor
    ///    es el número más grande de la pantalla. No el de mayor confianza; el más grande.
    /// 4. Si quedan dos del mismo tamaño, gana el de arriba.
    ///
    /// **La confianza no participa.** No ordena, no desempata y no se compara contra ningún
    /// umbral (D-11): si decidiera, existiría un atajo para guardar sin mirar, y es justo lo
    /// que RF-02 prohíbe.
    static func glucosa(entre numeros: [NumeroLeido]) -> NumeroLeido? {
        numeros
            .filter { esCandidato($0.valor) }
            .max { izquierdo, derecho in
                if izquierdo.caja.height != derecho.caja.height {
                    return izquierdo.caja.height < derecho.caja.height
                }
                // Mismo tamaño: gana el de arriba. En coordenadas normalizadas de Vision el
                // origen está abajo, así que «arriba» es mayor `maxY`. El desempate existe
                // para que la elección sea estable y no dependa del orden de llegada.
                return izquierdo.caja.maxY < derecho.caja.maxY
            }
    }

    /// El número de un renglón leído, o `nil` si ese renglón no puede ser una glucosa en
    /// mg/dL.
    ///
    /// Se queda con los dígitos de la cadena: un «112 mg/dL» leído junto sigue siendo 112.
    /// Pero **antes** descarta dos formas que, ya sin su separador, caen dentro del rango y
    /// se propondrían como lectura:
    ///
    /// - Un decimal. Un glucómetro en mmol/L que muestra «6.2» se leería como 62, que se ve
    ///   como hipoglucemia cuando el valor de verdad son 112 mg/dL.
    /// - Una hora. «5:26» se leería como 526.
    static func valor(deTexto texto: String) -> Double? {
        guard !texto.contains(":") else { return nil }

        let caracteres = Array(texto)
        for i in caracteres.indices.dropFirst().dropLast()
        where (caracteres[i] == "." || caracteres[i] == ",")
            && caracteres[i - 1].isNumber && caracteres[i + 1].isNumber {
            return nil
        }

        let digitos = texto.filter(\.isNumber)
        guard !digitos.isEmpty else { return nil }
        return Double(digitos)
    }

    /// Entero y dentro del rango fisiológico. Los dos límites salen de
    /// `ConfiguracionDominio`, no se escriben aquí.
    private static func esCandidato(_ valor: Double) -> Bool {
        guard valor == valor.rounded() else { return false }
        return (ConfiguracionDominio.glucosaMinima...ConfiguracionDominio.glucosaMaxima)
            .contains(valor)
    }
}
