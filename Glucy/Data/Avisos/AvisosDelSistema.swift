import Foundation
import UIKit
import UserNotifications

/// Los avisos de verdad: notificación local del sistema y vibración.
///
/// Tres cosas que están así por una razón:
///
/// 1. **La notificación es local, no remota.** La predicción se calcula en el teléfono, así
///    que no hace falta que nadie empuje nada desde un servidor, y la alerta funciona en modo
///    avión igual que con wifi (caso P-07).
/// 2. **El identificador del aviso es el UUID de la alerta.** El sistema reemplaza un aviso
///    con el mismo identificador en lugar de apilar otro, así que una alerta no puede acabar
///    sonando dos veces aunque se intente entregar dos veces.
/// 3. **La vibración va en el actor principal y la notificación no.**
///    `UINotificationFeedbackGenerator` es de la interfaz y solo vale ahí;
///    `UNUserNotificationCenter` se puede llamar desde donde sea. Separarlas deja que el
///    aviso salga sin esperar a que la interfaz esté libre, que es justo lo que importa
///    cuando la app está en segundo plano.
nonisolated struct AvisosDelSistema: ServicioAvisos {

    /// El centro se pide en cada llamada y no se guarda. `UNUserNotificationCenter` es una
    /// clase del sistema con estado propio: guardarla en una `struct` `Sendable` sería
    /// afirmar algo de ella que no nos toca afirmar.
    private var centro: UNUserNotificationCenter { UNUserNotificationCenter.current() }

    func permiso() async -> PermisoDeAviso {
        switch await centro.notificationSettings().authorizationStatus {
        case .notDetermined:
            .sinPreguntar
        case .denied:
            .negado
        case .authorized, .provisional, .ephemeral:
            .concedido
        @unknown default:
            // Un estado que esta versión de iOS no tenía. Se trata como negado y se dice en
            // pantalla, en lugar de suponer que hay permiso y dejar a la persona esperando
            // un aviso que no va a llegar.
            .negado
        }
    }

    func pedirPermiso() async throws -> Bool {
        // Sin `.badge`: un número en el icono no dice nada que la persona pueda usar, y
        // sumaría un permiso más que pedir. Con `.sound` porque una hipoglucemia de
        // madrugada tiene que despertar.
        try await centro.requestAuthorization(options: [.alert, .sound])
    }

    func entregar(_ aviso: AvisoParaEntregar) async throws {
        guard await permiso() == .concedido else { throw ErrorAviso.sinPermiso }

        let contenido = UNMutableNotificationContent()
        contenido.title = aviso.titulo
        contenido.body = aviso.cuerpo
        contenido.sound = .default
        // `.timeSensitive` y no `.critical`: la segunda necesita un permiso que Apple concede
        // caso por caso a software médico, y Glucy **no es un dispositivo médico
        // certificado**. Pedirla sería afirmar lo contrario.
        //
        // Para que iOS respete este nivel y el aviso atraviese un «No molestar» hace falta la
        // capacidad «Time Sensitive Notifications» en el objetivo de Xcode. Sin ella esta
        // línea no falla: el sistema la ignora y el aviso sale como uno normal.
        contenido.interruptionLevel = .timeSensitive

        let peticion = UNNotificationRequest(
            identifier: aviso.identificador,
            content: contenido,
            // `nil` es «ahora». Un disparador por tiempo retrasaría un aviso cuyo valor está
            // justamente en llegar antes.
            trigger: nil
        )

        do {
            try await centro.add(peticion)
        } catch {
            throw ErrorAviso.elSistemaNoLoAcepto(detalle: String(describing: error))
        }

        if aviso.vibra { await Self.vibrar() }
    }

    @MainActor
    private static func vibrar() {
        let generador = UINotificationFeedbackGenerator()
        // `prepare` antes de disparar: sin él el motor táctil arranca frío y el primer aviso
        // se siente hasta medio segundo después, que es el que más importa.
        generador.prepare()
        generador.notificationOccurred(.warning)
    }
}
