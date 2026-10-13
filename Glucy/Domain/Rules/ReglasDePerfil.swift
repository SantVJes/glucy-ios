import Foundation

/// Las reglas del formulario del perfil (F-1) que no dependen de ninguna pantalla.
nonisolated enum ReglasDePerfil {

    /// `nil` si el año sirve. Se valida antes de dejar continuar, no al guardar: quien tiene
    /// 14 años no debe llenar el resto del formulario para que al final se le diga que no.
    static func validarAnio(_ anio: Int, ahora: Date) -> Rechazo? {
        let edad = edad(anioNacimiento: anio, ahora: ahora)
        // Un año que todavía no llega, igual que una marca de tiempo futura.
        guard edad >= 0 else { return .marcaDeTiempoFutura }
        guard edad >= ConfiguracionDominio.edadMinima else { return .edadInsuficiente }
        guard edad <= ConfiguracionDominio.edadMaxima else { return .perfilNoValido(.anioNacimiento) }
        return nil
    }

    /// La edad que da el año solo, sin mes ni día: es todo lo que se sabe de la persona, a
    /// propósito (F-1, minimización).
    static func edad(anioNacimiento: Int, ahora: Date) -> Int {
        calendario.component(.year, from: ahora) - anioNacimiento
    }

    /// El 1 de enero del año, en UTC. Es lo que se guarda: así ninguna fecha de nacimiento
    /// precisa entra a la base aunque el campo pudiera guardarla.
    static func fechaDeAnio(_ anio: Int) -> Date {
        calendario.date(from: DateComponents(year: anio, month: 1, day: 1)) ?? .distantPast
    }

    /// El año de una fecha guardada con `fechaDeAnio`, para enseñarlo en Ajustes.
    static func anio(de fecha: Date) -> Int {
        calendario.component(.year, from: fecha)
    }

    /// RF-14: el usuario secundario no se aplica insulina y una pestaña que no usa le estorba.
    /// Nace calculado y queda editable en Ajustes: lo que la persona elija después gana.
    static func registraInsulinaPorOmision(para tipo: TipoUsuario) -> Bool {
        switch tipo {
        case .tipo1, .tipo2Insulinodependiente: true
        case .prediabetes, .resistenciaInsulina: false
        }
    }

    /// Solo letras, espacios y acentos, hasta `maximo`. Vacío vale: el nombre y los
    /// apellidos son opcionales.
    static func esNombreValido(_ texto: String, maximo: Int) -> Bool {
        texto.count <= maximo && texto.allSatisfy { $0.isLetter || $0 == " " }
    }

    private static var calendario: Calendar {
        var calendario = Calendar(identifier: .gregorian)
        calendario.timeZone = .gmt
        return calendario
    }
}
