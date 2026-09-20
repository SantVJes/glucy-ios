import SwiftUI

/// Los tokens de color, tipografía, espacio y forma de toda la app.
///
/// **Este es el único archivo donde puede aparecer un color en hexadecimal.** Un hex suelto
/// dentro de una vista es un color que nadie volvió a revisar contra su contraste, y aquí el
/// contraste no es estética: la pantalla se lee de madrugada, con una hipoglucemia encima.
///
/// Los once colores salen del Documento 1 y **no se redondean ni se ajustan «para que se vea
/// mejor»**: están elegidos por la razón de contraste que lleva cada uno al lado.
enum Tema {

    enum Colores {
        /// 6.2:1 sobre blanco. Botones, enlaces, línea de glucosa medida, pestaña activa.
        static let azulPrimario = Color(hex: 0x1A56DB)
        /// Fondo de la opción elegida y de las tarjetas informativas.
        static let azulClaro = Color(hex: 0xBBD5FF)
        /// 13.5:1. Las cifras grandes de glucosa.
        static let azulProfundo = Color(hex: 0x0B2A6B)

        /// Fondo de todas las pantallas salvo el splash.
        static let fondo = Color(hex: 0xF4F6FA)
        /// Fondo de tarjetas. La separación se consigue con blanco sobre el fondo, no con
        /// sombras: se ven mal con brillo alto y bajo el sol.
        static let superficie = Color(hex: 0xFFFFFF)

        /// 17.7:1. Títulos y texto de lectura.
        static let textoPrincipal = Color(hex: 0x111827)
        /// 4.8:1. Etiquetas, unidades, pies de gráfica.
        static let textoSecundario = Color(hex: 0x6B7280)

        /// 5.2:1. Texto de estado favorable.
        static let enRango = Color(hex: 0x0B7A54)
        /// 5.4:1. Texto de la predicción cerca de un límite.
        static let precaucion = Color(hex: 0xB54708)

        /// 2.4:1: **solo borde e icono** de avisos. Nunca como color de letra, porque no
        /// llega a 4.5:1 y quien lo use así deja un texto ilegible para media población.
        static let alertaAmbar = Color(hex: 0xF79009)

        /// 4.8:1. Episodios por debajo de 70, aviso clínico y borrado.
        static let hipoglucemia = Color(hex: 0xD92D20)
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
    /// El único punto de la app donde un color se escribe en hexadecimal.
    fileprivate init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}
