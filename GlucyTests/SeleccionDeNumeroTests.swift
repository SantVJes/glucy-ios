import CoreGraphics
import Testing
@testable import Glucy

/// Cuál de los números de la pantalla es la glucosa.
///
/// Se prueba sin imágenes y sin Vision, que es justo para lo que la regla vive aparte.
struct SeleccionDeNumeroTests {

    /// Una caja en coordenadas normalizadas. Lo que importa es la altura, que es el tamaño
    /// del número en la pantalla, y la posición vertical para el desempate.
    private func numero(
        _ valor: Double, confianza: Double = 0.5, alto: Double = 0.1, y: Double = 0.5
    ) -> NumeroLeido {
        NumeroLeido(
            valor: valor,
            confianza: confianza,
            caja: CGRect(x: 0.1, y: y, width: 0.2, height: alto)
        )
    }

    /// Prueba 8 — la pantalla enseña la fecha, la hora y el valor. Elegir mal es peor que
    /// no leer nada, porque la persona confirma sin mirar.
    @Test("8: entre 12, 0830 y 112, la selección devuelve 112")
    func descartaFechaYHora() {
        let leidos = [
            numero(12, alto: 0.05),      // la fecha
            numero(830, alto: 0.05),     // la hora, ya sin los dos puntos
            numero(112, alto: 0.20)      // la glucosa
        ]

        #expect(SeleccionDeNumero.glucosa(entre: leidos)?.valor == 112)
    }

    /// Prueba 9 — en todo glucómetro el valor es el número más grande de la pantalla.
    @Test("9: entre dos números en rango, gana el de caja más alta")
    func ganaElMasGrande() {
        let leidos = [
            numero(95, alto: 0.08),      // un promedio, en chiquito
            numero(140, alto: 0.25)      // la lectura
        ]

        #expect(SeleccionDeNumero.glucosa(entre: leidos)?.valor == 140)
    }

    /// Prueba 10 — el desempate existe para que la elección no dependa del orden en que el
    /// OCR entregue los números.
    @Test("10: entre dos del mismo tamaño, gana el de arriba")
    func desempataElDeArriba() {
        // En coordenadas de Vision el origen está abajo, así que «arriba» es mayor y.
        let arriba = numero(150, alto: 0.2, y: 0.7)
        let abajo = numero(90, alto: 0.2, y: 0.2)

        #expect(SeleccionDeNumero.glucosa(entre: [abajo, arriba])?.valor == 150)
        // Y al revés, para que no sea el orden de la lista el que decide.
        #expect(SeleccionDeNumero.glucosa(entre: [arriba, abajo])?.valor == 150)
    }

    /// Prueba 11 · RF-03 — no hay candidato: se dice y se ofrece escribirlo.
    @Test("11 · RF-03: sin ningún candidato válido devuelve nil")
    func sinCandidatoDevuelveNil() {
        #expect(SeleccionDeNumero.glucosa(entre: []) == nil)

        // Solo fecha y hora, nada en rango fisiológico.
        #expect(SeleccionDeNumero.glucosa(entre: [numero(12), numero(830), numero(2026)]) == nil)

        // Un decimal no es una lectura de glucómetro.
        #expect(SeleccionDeNumero.glucosa(entre: [numero(112.5)]) == nil)

        // Los extremos sí entran: 20 y 600 son válidos.
        #expect(SeleccionDeNumero.glucosa(entre: [numero(20)])?.valor == 20)
        #expect(SeleccionDeNumero.glucosa(entre: [numero(600)])?.valor == 600)
        #expect(SeleccionDeNumero.glucosa(entre: [numero(19)]) == nil)
        #expect(SeleccionDeNumero.glucosa(entre: [numero(601)]) == nil)
    }

    /// Prueba 12 · D-11 — la confianza se guarda pero **no decide nada**. Si ordenara, el
    /// número «más seguro» ganaría al más grande y la app señalaría la hora.
    @Test("12 · D-11: la selección no usa la confianza para ordenar")
    func laConfianzaNoOrdena() {
        let casiSeguroPeroChico = numero(95, confianza: 0.99, alto: 0.08)
        let dudosoPeroGrande = numero(140, confianza: 0.11, alto: 0.25)

        // Gana el grande, aunque el OCR esté mucho menos seguro de él.
        #expect(SeleccionDeNumero.glucosa(entre: [casiSeguroPeroChico, dudosoPeroGrande])?.valor == 140)

        // Y con la confianza invertida, el resultado es exactamente el mismo: la confianza
        // no participa.
        let mismosTamanosOtraConfianza = [
            numero(95, confianza: 0.10, alto: 0.08),
            numero(140, confianza: 0.90, alto: 0.25)
        ]
        #expect(SeleccionDeNumero.glucosa(entre: mismosTamanosOtraConfianza)?.valor == 140)
    }
}
