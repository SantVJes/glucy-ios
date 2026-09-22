import Foundation
@testable import Glucy

/// Un OCR de mentira, para probar la pantalla y el caso de uso sin imágenes.
///
/// Devuelve lo que se le diga y lleva la cuenta de cuántas veces se le llamó.
actor OCRFalso: ServicioOCR {
    private var respuesta: [NumeroLeido]
    private var falla = false
    private(set) var vecesLlamado = 0

    init(respuesta: [NumeroLeido] = []) {
        self.respuesta = respuesta
    }

    func responder(_ numeros: [NumeroLeido]) {
        respuesta = numeros
        falla = false
    }

    func fallar() {
        falla = true
    }

    func numerosEn(imagen: Data) async throws -> [NumeroLeido] {
        vecesLlamado += 1
        if falla { throw ErrorOCR.imagenIlegible }
        return respuesta
    }
}
