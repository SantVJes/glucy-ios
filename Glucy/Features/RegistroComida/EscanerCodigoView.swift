@preconcurrency import AVFoundation
import SwiftUI
import UIKit

/// El escáner de código de barras, envuelto para SwiftUI.
///
/// `AVCaptureMetadataOutput` y no el escáner de VisionKit: funciona en cualquier iPhone con
/// cámara y no obliga a escribir un segundo camino para cuando el dispositivo dice que no.
///
/// **De aquí no sale ninguna imagen.** Lo único que entrega es el texto del código; el video
/// se enseña en pantalla y no se graba, no se guarda y no se sube (regla 6).
struct EscanerCodigoView: UIViewRepresentable {
    /// El código leído. Puede llegar el mismo varias veces: quien lo recibe decide.
    let alLeer: (String) -> Void
    /// No hay cámara, o la persona no dio permiso. No es un error: se ofrece escribirlo.
    let alNoHaberCamara: () -> Void

    func makeUIView(context: Context) -> VistaPrevia {
        let vista = VistaPrevia()
        context.coordinator.preparar(en: vista)
        return vista
    }

    func updateUIView(_ vista: VistaPrevia, context: Context) {}

    static func dismantleUIView(_ vista: VistaPrevia, coordinator: Coordinador) {
        coordinator.detener()
    }

    func makeCoordinator() -> Coordinador {
        Coordinador(alLeer: alLeer, alNoHaberCamara: alNoHaberCamara)
    }

    final class VistaPrevia: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

        var capa: AVCaptureVideoPreviewLayer? { layer as? AVCaptureVideoPreviewLayer }
    }

    final class Coordinador: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        private let alLeer: (String) -> Void
        private let alNoHaberCamara: () -> Void

        private let sesion = AVCaptureSession()
        /// Arrancar y detener la sesión bloquea, así que va fuera del hilo principal.
        private let cola = DispatchQueue(label: "glucy.escaner")

        private var ultimoCodigo: String?
        private var ultimaEntrega = Date.distantPast

        init(alLeer: @escaping (String) -> Void, alNoHaberCamara: @escaping () -> Void) {
            self.alLeer = alLeer
            self.alNoHaberCamara = alNoHaberCamara
        }

        func preparar(en vista: VistaPrevia) {
            // El simulador no tiene cámara. Se comprueba antes de pedir permiso para no
            // enseñar un diálogo que no lleva a ningún lado.
            guard AVCaptureDevice.default(for: .video) != nil else {
                avisarQueNoHayCamara()
                return
            }

            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                configurar(en: vista)
            case .notDetermined:
                Task {
                    if await AVCaptureDevice.requestAccess(for: .video) {
                        configurar(en: vista)
                    } else {
                        alNoHaberCamara()
                    }
                }
            default:
                avisarQueNoHayCamara()
            }
        }

        func detener() {
            let sesion = sesion
            cola.async {
                if sesion.isRunning { sesion.stopRunning() }
            }
        }

        private func configurar(en vista: VistaPrevia) {
            let salida = AVCaptureMetadataOutput()
            guard let camara = AVCaptureDevice.default(for: .video),
                  let entrada = try? AVCaptureDeviceInput(device: camara),
                  sesion.canAddInput(entrada),
                  sesion.canAddOutput(salida) else {
                avisarQueNoHayCamara()
                return
            }

            sesion.addInput(entrada)
            sesion.addOutput(salida)
            salida.setMetadataObjectsDelegate(self, queue: .main)
            // Después de `addOutput`: antes, la lista de tipos disponibles está vacía y
            // pedir cualquiera lanza una excepción.
            salida.metadataObjectTypes = [.ean13, .ean8, .upce]
                .filter(salida.availableMetadataObjectTypes.contains)

            vista.capa?.session = sesion
            vista.capa?.videoGravity = .resizeAspectFill

            let sesion = sesion
            cola.async {
                if !sesion.isRunning { sesion.startRunning() }
            }
        }

        /// Fuera del ciclo de dibujo: esto se llama desde `makeUIView`, y cambiar el estado
        /// de la pantalla mientras se está dibujando no está permitido.
        private func avisarQueNoHayCamara() {
            Task { alNoHaberCamara() }
        }

        nonisolated func metadataOutput(
            _ salida: AVCaptureMetadataOutput,
            didOutput objetos: [AVMetadataObject],
            from conexion: AVCaptureConnection
        ) {
            guard let leido = objetos.first as? AVMetadataMachineReadableCodeObject,
                  let texto = leido.stringValue else { return }
            let esUpce = leido.type == .upce

            Task { @MainActor in
                self.entregar(texto, esUpce: esUpce)
            }
        }

        private func entregar(_ texto: String, esUpce: Bool) {
            // Un UPC-E y un EAN-8 miden lo mismo; solo aquí se sabe cuál se leyó.
            let codigo = esUpce ? (CodigoBarras.ean13(desdeUpce: texto) ?? texto) : texto

            // La cámara entrega el mismo código decenas de veces por segundo. Se repite
            // pasados dos segundos, para poder reintentar el que se leyó mal.
            let ahora = Date()
            if codigo == ultimoCodigo, ahora.timeIntervalSince(ultimaEntrega) < 2 { return }
            ultimoCodigo = codigo
            ultimaEntrega = ahora

            alLeer(codigo)
        }
    }
}
