import Foundation
import Testing
@testable import Glucy

/// Las reglas del formulario del perfil (F-1): quién puede darse de alta y a quién se le
/// enseña el registro de insulina.
struct ReglasDePerfilTests {

    /// 19 de septiembre de 2025.
    private let ahora = Date(timeIntervalSince1970: 1_758_240_000)

    @Test("7 · F-1: con 14 años no se puede dar de alta; con 15, sí")
    func laEdadMinima() {
        #expect(ReglasDePerfil.edad(anioNacimiento: 2011, ahora: ahora) == 14)
        #expect(ReglasDePerfil.validarAnio(2011, ahora: ahora) == .edadInsuficiente)

        #expect(ReglasDePerfil.edad(anioNacimiento: 2010, ahora: ahora) == 15)
        #expect(ReglasDePerfil.validarAnio(2010, ahora: ahora) == nil)
        #expect(ReglasDePerfil.validarAnio(1958, ahora: ahora) == nil)
    }

    @Test("8 · F-1: un año que todavía no llega se rechaza")
    func elAnioFuturo() {
        #expect(ReglasDePerfil.validarAnio(2026, ahora: ahora) == .marcaDeTiempoFutura)
        #expect(ReglasDePerfil.validarAnio(2090, ahora: ahora) == .marcaDeTiempoFutura)
        // El año en curso no es futuro, pero tampoco alcanza la edad.
        #expect(ReglasDePerfil.validarAnio(2025, ahora: ahora) == .edadInsuficiente)
        // Y un año de hace siglo y medio es un dedo que se fue de tecla.
        #expect(ReglasDePerfil.validarAnio(1880, ahora: ahora) == .perfilNoValido(.anioNacimiento))
    }

    @Test("9 · RF-14: quien vive con tipo 1 o tipo 2 con insulina registra insulina")
    func elUsuarioPrincipalRegistraInsulina() {
        #expect(ReglasDePerfil.registraInsulinaPorOmision(para: .tipo1))
        #expect(ReglasDePerfil.registraInsulinaPorOmision(para: .tipo2Insulinodependiente))
    }

    @Test("10 · RF-14, C-3: con prediabetes o resistencia a la insulina, no")
    func elUsuarioSecundarioNo() {
        #expect(!ReglasDePerfil.registraInsulinaPorOmision(para: .prediabetes))
        #expect(!ReglasDePerfil.registraInsulinaPorOmision(para: .resistenciaInsulina))
    }
}
