import CoreGraphics
import Foundation

/// Un número que el OCR encontró en la imagen, con dónde estaba y qué tan seguro estaba.
nonisolated struct NumeroLeido: Sendable, Equatable {
    let valor: Double

    /// De 0 a 1, tal como lo reporta el OCR.
    ///
    /// **No decide nada** (D-11, RF-05b). No se compara contra ningún umbral, no ordena
    /// candidatos y no se enseña en pantalla: enseñarla invitaría a confiar en ella. Se
    /// guarda para poder evaluar después si predice bien los errores.
    let confianza: Double

    /// En coordenadas normalizadas de la imagen (0–1, origen abajo a la izquierda, como las
    /// entrega Vision), para poder dibujar el recuadro ámbar encima.
    let caja: CGRect
}

/// El OCR del dispositivo, detrás de un protocolo.
///
/// Mismo motivo que con HealthKit en el paso 4: la integración continua no tiene cámara. Con
/// una diferencia a favor, eso sí: Vision **sí** corre en el simulador sobre una imagen ya
/// cargada, así que el OCR de verdad se puede probar, no solo con un doble.
nonisolated protocol ServicioOCR: Sendable {
    /// Devuelve todos los números que encontró, **sin elegir**.
    ///
    /// Quien elige es `SeleccionDeNumero`, que vive aparte justo para poder probarse sin
    /// imágenes y sin Vision.
    func numerosEn(imagen: Data) async throws -> [NumeroLeido]
}

/// Lo que puede salir mal al leer la imagen.
nonisolated enum ErrorOCR: Error, Equatable {
    case imagenIlegible
    case falloElReconocimiento(motivo: String)
}
