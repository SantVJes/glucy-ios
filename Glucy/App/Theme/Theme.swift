import SwiftUI
import UIKit

/// Un color con su valor para modo claro y su valor para modo oscuro.
///
/// Los dos viven juntos para que nadie pueda cambiar uno sin ver el otro, y como números para
/// que las pruebas midan el contraste sin dibujar nada.
nonisolated struct ParDeColores: Sendable, Equatable {
    let claro: UInt32
    let oscuro: UInt32
}

/// Los tokens de color, tipografía, espacio y forma de toda la app.
///
/// **Este es el único archivo donde puede aparecer un color en hexadecimal.** Un hex suelto
/// dentro de una vista es un color que nadie volvió a revisar contra su contraste, y aquí el
/// contraste no es estética: la pantalla se lee de madrugada, con una hipoglucemia encima.
///
/// Los colores **no se ajustan «para que se vea mejor»**: cada uno está elegido por la razón
/// de contraste que da contra los fondos donde se usa, y `ContrasteTests` la vuelve a medir.
enum Tema {

    /// Los valores en hexadecimal. **Este es el único sitio de la app donde aparecen.**
    ///
    /// Cada par está medido contra los fondos donde se usa, en los dos modos, y las pruebas de
    /// `ContrasteTests` fallan si uno baja de 4.5:1 en texto o de 3:1 en bordes. Aquí el
    /// contraste no es estética: la pantalla se lee de madrugada, con una hipoglucemia encima.
    /// La tabla completa con cada razón está en `docs/modo-oscuro.md`.
    nonisolated enum Paleta {
        static let azulPrimario    = ParDeColores(claro: 0x1A56DB, oscuro: 0x7EA6FF)
        static let azulClaro       = ParDeColores(claro: 0xD1E2FF, oscuro: 0x1E3560)
        static let azulProfundo    = ParDeColores(claro: 0x0B2A6B, oscuro: 0xDCE6FF)

        static let fondo           = ParDeColores(claro: 0xF4F6FA, oscuro: 0x0B0F17)
        static let superficie      = ParDeColores(claro: 0xFFFFFF, oscuro: 0x171D28)

        static let textoPrincipal  = ParDeColores(claro: 0x111827, oscuro: 0xEEF1F6)
        static let textoSecundario = ParDeColores(claro: 0x667085, oscuro: 0x9BA4B4)

        static let enRango         = ParDeColores(claro: 0x0B7A54, oscuro: 0x5EE0A0)
        static let precaucion      = ParDeColores(claro: 0xB54708, oscuro: 0xFDB022)
        static let alertaAmbar     = ParDeColores(claro: 0xDC6803, oscuro: 0xF79009)
        static let hipoglucemia    = ParDeColores(claro: 0xCC2A1E, oscuro: 0xFF6259)

        static let textoSobreColor = ParDeColores(claro: 0xFFFFFF, oscuro: 0x0B0F17)
    }

    /// Los colores que usan las vistas. iOS elige el valor claro u oscuro al dibujar, según la
    /// apariencia del sistema: la app no fuerza ningún modo.
    enum Colores {
        /// Botones, enlaces, línea de glucosa medida, pestaña activa.
        static let azulPrimario = Color(Paleta.azulPrimario)
        /// Fondo de la opción elegida y de las tarjetas informativas.
        static let azulClaro = Color(Paleta.azulClaro)
        /// Las cifras grandes de glucosa.
        static let azulProfundo = Color(Paleta.azulProfundo)

        /// Fondo de todas las pantallas. En oscuro es casi negro y no negro puro: el negro
        /// puro deja estela al desplazarse en una pantalla OLED.
        static let fondo = Color(Paleta.fondo)
        /// Fondo de tarjetas. La separación se consigue con una superficie más clara que el
        /// fondo, no con sombras: se ven mal con brillo alto y bajo el sol.
        static let superficie = Color(Paleta.superficie)

        /// Títulos y texto de lectura. En oscuro es casi blanco y no blanco puro: el blanco
        /// puro sobre negro se corre para quien tiene astigmatismo.
        static let textoPrincipal = Color(Paleta.textoPrincipal)
        /// Etiquetas, unidades, pies de gráfica y el botón deshabilitado.
        static let textoSecundario = Color(Paleta.textoSecundario)

        /// Texto de estado favorable y franja de «guardado».
        static let enRango = Color(Paleta.enRango)
        /// Texto de la predicción cerca de un límite.
        static let precaucion = Color(Paleta.precaucion)
        /// **Solo borde e icono** de avisos, nunca letra, en ninguno de los dos modos.
        static let alertaAmbar = Color(Paleta.alertaAmbar)
        /// Episodios por debajo de 70, aviso clínico, error y borrado. En oscuro se separa
        /// del verde y del ámbar también por luminosidad, no solo por tono.
        static let hipoglucemia = Color(Paleta.hipoglucemia)

        /// Letra e icono **encima** de un relleno de `azulPrimario`, `enRango`,
        /// `hipoglucemia` o `textoSecundario`. No es lo mismo que `superficie`: en oscuro
        /// la superficie es casi negra y la letra sobre un botón también, pero significan
        /// cosas distintas y cambiar una no debe romper la otra.
        static let textoSobreColor = Color(Paleta.textoSobreColor)
    }

    /// Siete niveles, ninguno por debajo de 11 pt.
    ///
    /// Los cinco niveles de texto usan estilos relativos, así que Dynamic Type los mueve
    /// solo. Las dos cifras grandes van como tamaño base y la vista las escala con
    /// `@ScaledMetric`: un `Font` de tamaño fijo no crece con la letra del sistema, y esta
    /// app se diseña para el peor momento, no para el mejor.
    enum Tipografia {
        static let tamanoCifraGlucosa: CGFloat = 56      // bold
        static let tamanoCifraSecundaria: CGFloat = 44   // bold

        static let tituloPantalla = Font.system(.title2, weight: .semibold)     // 22
        static let tituloTarjeta = Font.system(.headline, weight: .semibold)    // 17
        static let textoLectura = Font.system(.body)                            // 16
        static let valorFila = Font.system(.subheadline, weight: .semibold)     // 15
        static let etiqueta = Font.system(.footnote)                            // 13
    }

    /// Rejilla de 4 pt.
    enum Espacio {
        static let unidad: CGFloat = 4
        static let margenLateral: CGFloat = 20
        static let entreTarjetas: CGFloat = 14
        static let interior: CGFloat = 16
    }

    enum Radio {
        static let tarjetaGrande: CGFloat = 20
        static let bloqueInterno: CGFloat = 16
        static let campo: CGFloat = 12
        /// Chips e interruptores: redondeo completo.
        static let completo: CGFloat = 999
    }

    enum Medida {
        static let botonPrincipal: CGFloat = 50
        static let renglonAjustes: CGFloat = 56
        static let chip: CGFloat = 36
        /// Lo que Apple pide como mínimo tocable, y lo que necesita alguien temblando por
        /// una hipoglucemia.
        static let areaTocable: CGFloat = 44
    }
}

extension Color {
    /// Un color que iOS resuelve al dibujar según la apariencia del sistema.
    ///
    /// `nonisolated` y con el cierre `@Sendable` a propósito: SwiftUI resuelve los colores
    /// desde su hilo de dibujo, no desde el principal. El target compila con todo aislado al
    /// actor principal por omisión, y un cierre que herede ese aislamiento tumba la app en
    /// cuanto se dibuja la primera pantalla.
    fileprivate nonisolated init(_ par: ParDeColores) {
        self.init(uiColor: UIColor { @Sendable rasgos in
            UIColor(hex: rasgos.userInterfaceStyle == .dark ? par.oscuro : par.claro)
        })
    }
}

extension UIColor {
    fileprivate nonisolated convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
