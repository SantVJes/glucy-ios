import Foundation
import Security

/// Dónde se guarda el token del backend.
///
/// Detrás de un protocolo para poder probar la sincronización sin tocar el Keychain del
/// simulador, que en las pruebas no siempre está disponible.
nonisolated protocol AlmacenDeToken: Sendable {
    func token() -> String?
    func guardar(token: String) throws
    func borrar() throws
}

/// El Keychain, y nunca `UserDefaults`.
///
/// `UserDefaults` es un archivo de texto dentro del contenedor de la app: en un teléfono con
/// jailbreak, o en un respaldo sin cifrar, el token se lee a simple vista. El Keychain está
/// cifrado por el hardware y, con `WhenUnlockedThisDeviceOnly`, **no viaja en el respaldo ni
/// a otro teléfono**: un token robado de un respaldo daría acceso a la serie de glucosa de
/// la persona en el servidor.
///
/// `ThisDeviceOnly` tiene un costo que conviene tener claro: al restaurar el teléfono el
/// token no está y hay que volver a obtenerlo. Es el costo correcto; una credencial que
/// sobrevive a la restauración es una credencial que también sobrevive a una copia.
nonisolated struct Llavero: AlmacenDeToken {
    /// La cuenta dentro del Keychain. No es un secreto, es una etiqueta.
    private let cuenta: String
    private let servicio: String

    init(servicio: String = "mx.glucy.backend", cuenta: String = "token") {
        self.servicio = servicio
        self.cuenta = cuenta
    }

    private var consulta: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: servicio,
            kSecAttrAccount as String: cuenta,
        ]
    }

    func token() -> String? {
        var consulta = self.consulta
        consulta[kSecReturnData as String] = true
        consulta[kSecMatchLimit as String] = kSecMatchLimitOne

        var resultado: CFTypeRef?
        guard SecItemCopyMatching(consulta as CFDictionary, &resultado) == errSecSuccess,
              let datos = resultado as? Data,
              let texto = String(data: datos, encoding: .utf8),
              !texto.isEmpty
        else {
            return nil
        }
        return texto
    }

    func guardar(token: String) throws {
        guard let datos = token.data(using: .utf8) else {
            throw ErrorLlavero.tokenIlegible
        }
        // Se borra antes de escribir: `SecItemAdd` sobre una cuenta que ya existe devuelve
        // `errSecDuplicateItem` y el token nuevo no entraría.
        SecItemDelete(consulta as CFDictionary)

        var atributos = consulta
        atributos[kSecValueData as String] = datos
        atributos[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

        let estado = SecItemAdd(atributos as CFDictionary, nil)
        guard estado == errSecSuccess else {
            throw ErrorLlavero.noSePudoGuardar(estado: estado)
        }
    }

    func borrar() throws {
        let estado = SecItemDelete(consulta as CFDictionary)
        // Borrar algo que no estaba no es una falla: el borrado de la cuenta lo llama sin
        // saber si había token.
        guard estado == errSecSuccess || estado == errSecItemNotFound else {
            throw ErrorLlavero.noSePudoBorrar(estado: estado)
        }
    }
}

nonisolated enum ErrorLlavero: Error, Equatable {
    case tokenIlegible
    case noSePudoGuardar(estado: OSStatus)
    case noSePudoBorrar(estado: OSStatus)
}
