import Foundation
import Testing
@testable import Glucy

/// La pantalla de insulina, sin dibujarla.
@MainActor
struct RegistroInsulinaViewModelTests {

    private let ahora = Date(timeIntervalSince1970: 1_758_240_000)

    private func montar() throws -> (RegistroInsulinaViewModel, ContenedorDependencias) {
        let dependencias = ContenedorDependencias(
            contenedor: try ContenedorGlucy.crear(enMemoria: true), salud: HealthKitFalso()
        )
        let modelo = RegistroInsulinaViewModel(
            registrar: dependencias.registrarDosis,
            calcular: dependencias.calcularInsulinaActiva,
            ajustes: dependencias.ajustesDeInsulina
        )
        return (modelo, dependencias)
    }

    @Test("RF-14: en la primera dosis no hay tipo preseleccionado; después, el del último registro")
    func elTipoNoSeAdivina() async throws {
        let (modelo, dependencias) = try montar()
        await modelo.ponerAlDia(ahora: ahora)
        #expect(modelo.tipo == nil)

        // Sin tipo no se guarda nada: no se supone ni rápida ni basal.
        modelo.textoUnidades = "4"
        await modelo.guardar(ahora: ahora)
        #expect(modelo.fallo == .tipoSinElegir)
        #expect(try await dependencias.dosis.contar() == 0)

        modelo.tipo = .basal
        #expect(modelo.fallo == nil)
        await modelo.guardar(ahora: ahora)
        #expect(try await dependencias.dosis.contar() == 1)

        // Otra vez en la pantalla, más tarde: propone la del último registro.
        let otra = RegistroInsulinaViewModel(
            registrar: dependencias.registrarDosis,
            calcular: dependencias.calcularInsulinaActiva,
            ajustes: dependencias.ajustesDeInsulina
        )
        await otra.ponerAlDia(ahora: ahora.addingTimeInterval(3600))
        #expect(otra.tipo == .basal)
    }

    @Test("Los botones mueven el campo de media en media unidad, sin salirse de lo registrable")
    func losBotonesVanDeMediaEnMedia() throws {
        let (modelo, _) = try montar()

        modelo.moverMediaUnidad(haciaArriba: true)
        #expect(modelo.textoUnidades == "0.5")
        modelo.moverMediaUnidad(haciaArriba: true)
        #expect(modelo.textoUnidades == "1")
        modelo.moverMediaUnidad(haciaArriba: false)
        modelo.moverMediaUnidad(haciaArriba: false)
        // En cero el campo queda vacío, que es lo que es: nada anotado.
        #expect(modelo.textoUnidades == "")
        modelo.moverMediaUnidad(haciaArriba: false)
        #expect(modelo.textoUnidades == "")

        // Desde algo que no cae en media unidad se va a la media siguiente.
        modelo.textoUnidades = "2,3"
        modelo.moverMediaUnidad(haciaArriba: true)
        #expect(modelo.textoUnidades == "2.5")
        modelo.textoUnidades = "2.3"
        modelo.moverMediaUnidad(haciaArriba: false)
        #expect(modelo.textoUnidades == "2")

        modelo.textoUnidades = "50"
        modelo.moverMediaUnidad(haciaArriba: true)
        #expect(modelo.textoUnidades == "50")
    }

    @Test("La insulina activa se dice como cifra con su unidad y su hora, y nada más")
    func elTextoDeLaInsulinaActiva() async throws {
        let (modelo, _) = try montar()
        #expect(modelo.textoInsulinaActiva == nil)

        await modelo.ponerAlDia(ahora: ahora)
        #expect(modelo.textoInsulinaActiva == "No te queda insulina trabajando")

        modelo.textoUnidades = "4"
        modelo.tipo = .bolo
        modelo.elegir(fecha: ahora.addingTimeInterval(-120 * 60))
        await modelo.guardar(ahora: ahora)

        // Referencia: iob([(4, 120)]) = 1.64…
        let hora = ahora.addingTimeInterval(-120 * 60).formatted(date: .omitted, time: .shortened)
        #expect(modelo.textoInsulinaActiva == "Te quedan 1.6 UI trabajando · última dosis a las \(hora)")
        #expect(modelo.textoInsulinaActivaHablado
            == "Te quedan 1.6 unidades de insulina trabajando, última dosis a las \(hora)")

        // Guardar deja la hora propuesta otra vez en «ahora», no en la que se eligió.
        #expect(modelo.fecha == ahora)
        #expect(modelo.textoUnidades == "")
        #expect(modelo.tipo == .bolo)
    }
}
