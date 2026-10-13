import SwiftUI
import UIKit

/// La cámara, envuelta para SwiftUI.
///
/// **La foto no se guarda en ningún lado.** Sale de aquí como `Data` en memoria, Vision la
/// lee y se suelta: no se escribe en disco, no va al carrete y no se sube (regla 6). Por eso
/// no hay ni un `UIImageWriteToSavedPhotosAlbum` ni un `savedPhotosAlbum` en este archivo, y
/// no debe haberlo nunca: es lo que comprueba el grep del apartado 9.
struct CapturaFotoView: UIViewControllerRepresentable {
    /// Recibe la foto ya comprimida, en memoria.
    let alCapturar: (Data) -> Void
    /// La persona cerró la cámara sin tomar nada.
    let alCancelar: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let controlador = UIImagePickerController()
        // Solo la cámara: el carrete no se toca, ni para leer ni para escribir.
        controlador.sourceType = .camera
        controlador.allowsEditing = false
        controlador.delegate = context.coordinator
        return controlador
    }

    func updateUIViewController(_ controlador: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinador {
        Coordinador(alCapturar: alCapturar, alCancelar: alCancelar)
    }

    final class Coordinador: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let alCapturar: (Data) -> Void
        private let alCancelar: () -> Void

        init(alCapturar: @escaping (Data) -> Void, alCancelar: @escaping () -> Void) {
            self.alCapturar = alCapturar
            self.alCancelar = alCancelar
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            defer { picker.dismiss(animated: true) }

            guard let imagen = info[.originalImage] as? UIImage,
                  let datos = imagen.jpegData(compressionQuality: 0.9) else {
                alCancelar()
                return
            }
            // `jpegData` devuelve los bytes en memoria. No hay ninguna escritura a disco:
            // nadie llama a `write(to:)` con esto.
            alCapturar(datos)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
            alCancelar()
        }
    }
}
