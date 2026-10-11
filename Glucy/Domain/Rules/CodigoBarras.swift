import Foundation

/// El código de barras de un producto, antes de salir a la red.
nonisolated enum CodigoBarras {

    /// EAN-13 y EAN-8 con su dígito verificador correcto. Un código mal leído se descarta
    /// aquí y no gasta una de las 15 consultas por minuto de Open Food Facts.
    ///
    /// El verificador es lo que le falta a la suma ponderada para llegar al siguiente
    /// múltiplo de diez. Los pesos alternan 3 y 1 **desde la derecha**, que es lo que hace
    /// que la misma cuenta sirva para trece y para ocho dígitos.
    static func esValido(_ codigo: String) -> Bool {
        guard codigo.count == 13 || codigo.count == 8 else { return false }

        // `wholeNumberValue` aceptaría dígitos de otros alfabetos; un código de barras solo
        // trae los diez ASCII.
        let digitos = codigo.compactMap { $0.isASCII ? $0.wholeNumberValue : nil }
        guard digitos.count == codigo.count, let verificador = digitos.last else { return false }

        let suma = digitos.dropLast().reversed().enumerated().reduce(0) { total, par in
            total + par.element * (par.offset.isMultiple(of: 2) ? 3 : 1)
        }
        return (10 - suma % 10) % 10 == verificador
    }

    /// El EAN-13 que corresponde a un UPC-E, o `nil` si no tiene forma de UPC-E.
    ///
    /// Un UPC-E son ocho dígitos, igual que un EAN-8, pero su verificador se calcula sobre
    /// el código expandido: sin expandirlo, `esValido` lo rechazaría siempre. Solo el
    /// escáner sabe cuál de los dos leyó, y por eso es él quien llama a esto.
    static func ean13(desdeUpce codigo: String) -> String? {
        let digitos = Array(codigo)
        guard digitos.count == 8, digitos.allSatisfy({ $0.isASCII && $0.isNumber }) else {
            return nil
        }

        let sistema = String(digitos[0])
        let cuerpo = digitos[1...6].map(String.init)
        let verificador = String(digitos[7])

        let fabricanteYProducto: String
        switch cuerpo[5] {
        case "0", "1", "2":
            fabricanteYProducto = cuerpo[0] + cuerpo[1] + cuerpo[5] + "0000"
                + cuerpo[2] + cuerpo[3] + cuerpo[4]
        case "3":
            fabricanteYProducto = cuerpo[0] + cuerpo[1] + cuerpo[2] + "00000"
                + cuerpo[3] + cuerpo[4]
        case "4":
            fabricanteYProducto = cuerpo[0] + cuerpo[1] + cuerpo[2] + cuerpo[3] + "00000"
                + cuerpo[4]
        default:
            fabricanteYProducto = cuerpo[0] + cuerpo[1] + cuerpo[2] + cuerpo[3] + cuerpo[4]
                + "0000" + cuerpo[5]
        }

        // Un UPC-A es un EAN-13 con un cero delante.
        return "0" + sistema + fabricanteYProducto + verificador
    }
}
