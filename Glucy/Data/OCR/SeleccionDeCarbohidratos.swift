import CoreGraphics
import Foundation

/// Cuál de los números de la etiqueta nutrimental son los carbohidratos.
///
/// Hermana de `SeleccionDeNumero`, y aparte de Vision por lo mismo: se prueba con una lista
/// de renglones escrita a mano.
nonisolated enum SeleccionDeCarbohidratos {

    /// Las etiquetas mexicanas dicen «Hidratos de carbono»; las importadas, cualquiera de
    /// las otras. Sin acentos y en minúsculas, que es como se comparan.
    private static let claves = ["hidratos de carbono", "carbohidratos", "carbohydrate", "glucidos"]

    /// En la tabla mexicana los azúcares y la fibra son renglones sangrados debajo de los
    /// hidratos de carbono. Tomar uno de esos por el total **subestima** los carbohidratos,
    /// que es el error que más daño hace: la persona cree haber comido menos de lo que comió.
    private static let exclusiones = ["azucares", "sugars", "fibra", "fiber"]

    /// Los gramos de carbohidratos por 100 g que dice la etiqueta, o `nil`.
    ///
    /// El orden de la regla importa:
    ///
    /// 1. Se busca el renglón que nombre los carbohidratos.
    /// 2. Se descarta el que además nombre los azúcares o la fibra.
    /// 3. Se toma el número de ese renglón; y si no trae —las tablas en columnas ponen el
    ///    nombre a la izquierda y la cifra a la derecha, en observaciones distintas— el del
    ///    renglón que esté a su misma altura y a su derecha.
    /// 4. Si no hay nada, `nil`, y eso es la captura manual (RF-13).
    ///
    /// **La confianza no participa** (D-11): lo que salga de aquí se enseña y se confirma,
    /// igual que el número del glucómetro.
    static func gramos(entre renglones: [TextoLeido]) -> Double? {
        // De arriba hacia abajo, para que la elección no dependa del orden en que el OCR
        // entregue los renglones. En coordenadas de Vision «arriba» es mayor `maxY`.
        let deArribaAbajo = renglones.sorted { $0.caja.maxY > $1.caja.maxY }

        for renglon in deArribaAbajo {
            let texto = normalizar(renglon.texto)
            guard let clave = claves.compactMap({ texto.range(of: $0) }).first,
                  !nombraUnaExclusion(texto) else { continue }

            // Lo que va después de la palabra, no antes: en «100 g · Hidratos de carbono
            // 75 g» el 100 es el tamaño de referencia, no los carbohidratos.
            if let enElRenglon = primerNumero(en: texto[clave.upperBound...]) {
                return enElRenglon
            }
            if let aLaDerecha = numeroALaDerecha(de: renglon, entre: deArribaAbajo) {
                return aLaDerecha
            }
        }
        return nil
    }

    /// El número de la celda más cercana que esté a la misma altura y a la derecha.
    private static func numeroALaDerecha(de renglon: TextoLeido, entre renglones: [TextoLeido]) -> Double? {
        renglones
            .filter { otro in
                otro != renglon
                    && otro.caja.minX >= renglon.caja.midX
                    && seSolapanEnVertical(otro.caja, renglon.caja)
                    && !nombraUnaExclusion(normalizar(otro.texto))
            }
            .sorted { $0.caja.minX < $1.caja.minX }
            .lazy
            .compactMap { primerNumero(en: Substring(normalizar($0.texto))) }
            .first
    }

    /// Se consideran del mismo renglón cuando comparten más de la mitad de la altura de la
    /// caja más baja. Con menos que eso, una celda del renglón de arriba o del de abajo
    /// —los azúcares— pasaría por vecina.
    private static func seSolapanEnVertical(_ una: CGRect, _ otra: CGRect) -> Bool {
        let compartido = min(una.maxY, otra.maxY) - max(una.minY, otra.minY)
        return compartido > min(una.height, otra.height) / 2
    }

    private static func nombraUnaExclusion(_ texto: String) -> Bool {
        exclusiones.contains { texto.contains($0) }
    }

    private static func normalizar(_ texto: String) -> String {
        texto.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
    }

    /// Acepta punto y coma decimal: las etiquetas mexicanas usan los dos.
    private static func primerNumero(en texto: Substring) -> Double? {
        guard let hallado = texto.firstMatch(of: /\d+(?:[.,]\d+)?/) else { return nil }
        return Double(hallado.0.replacingOccurrences(of: ",", with: "."))
    }
}
