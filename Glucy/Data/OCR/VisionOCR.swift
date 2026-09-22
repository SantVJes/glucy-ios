import CoreGraphics
import Foundation
import ImageIO
import Vision

/// El OCR de Vision, en el dispositivo.
///
/// **El único archivo de la app que importa Vision.** La imagen entra como `Data`, se
/// procesa en memoria y se suelta: no se escribe en disco, no va al carrete, no se sube y
/// no se guarda «para depurar» (regla 6).
nonisolated struct VisionOCR: ServicioOCR {

    func numerosEn(imagen: Data) async throws -> [NumeroLeido] {
        guard let fuente = CGImageSourceCreateWithData(imagen as CFData, nil),
              let cgImagen = CGImageSourceCreateImageAtIndex(fuente, 0, nil) else {
            throw ErrorOCR.imagenIlegible
        }

        return try await reconocer(en: cgImagen)
    }

    /// Los objetos de Vision no son `Sendable`, así que la conversión a `NumeroLeido`
    /// ocurre **dentro** del manejador, antes de cruzar de vuelta. Devolver las
    /// observaciones y convertirlas después sería una carrera que el compilador no deja
    /// pasar, y con razón: Vision las entrega en su propia cola.
    private func reconocer(en imagen: CGImage) async throws -> [NumeroLeido] {
        try await withCheckedThrowingContinuation { continuacion in
            let peticion = VNRecognizeTextRequest { peticion, error in
                if let error {
                    continuacion.resume(
                        throwing: ErrorOCR.falloElReconocimiento(motivo: error.localizedDescription)
                    )
                    return
                }
                let observaciones = peticion.results as? [VNRecognizedTextObservation] ?? []
                continuacion.resume(returning: observaciones.compactMap(Self.numero(de:)))
            }

            // La foto ya se tomó, así que la velocidad no importa y la exactitud sí.
            peticion.recognitionLevel = .accurate

            // **Sin corrección de idioma.** Con ella encendida, Vision intenta convertir el
            // número en una palabra conocida y «112» puede volver «IIZ».
            peticion.usesLanguageCorrection = false

            do {
                try VNImageRequestHandler(cgImage: imagen, options: [:]).perform([peticion])
            } catch {
                continuacion.resume(
                    throwing: ErrorOCR.falloElReconocimiento(motivo: error.localizedDescription)
                )
            }
        }
    }

    /// Convierte una observación en número, si lo es.
    ///
    /// Se queda con los dígitos de la cadena: un «112 mg/dL» leído junto sigue siendo 112, y
    /// un «08:30» se queda en 0830, que después descarta `SeleccionDeNumero` por estar fuera
    /// de rango. Aquí no se elige nada, solo se traduce.
    private static func numero(de observacion: VNRecognizedTextObservation) -> NumeroLeido? {
        guard let candidato = observacion.topCandidates(1).first else { return nil }

        let digitos = candidato.string.filter(\.isNumber)
        guard !digitos.isEmpty, let valor = Double(digitos) else { return nil }

        return NumeroLeido(
            valor: valor,
            // Se guarda tal cual la reporta Vision. No se usa para nada más.
            confianza: Double(candidato.confidence),
            caja: observacion.boundingBox
        )
    }
}
