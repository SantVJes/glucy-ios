import Foundation
import Testing
@testable import Glucy

/// El estado del sensor que Inicio dibuja. «No tengo sensor» y «mi sensor no escribe desde
/// las 8:05» no son lo mismo, y solo la segunda merece una franja.
struct EstadoDelSensorTests {

    private let ahora = InicioDePrueba.ahora

    private func hace(_ minutos: Double) -> Date {
        ahora.addingTimeInterval(-minutos * 60)
    }

    /// El estado que llega a la pantalla, pasando por `ConsultarInicio`.
    private func estado(
        usaSensor: Bool, lecturas: [(mgDl: Double, haceMin: Double, origen: Origen)]
    ) async throws -> EstadoDelSensor {
        let repositorio = RepositorioLecturasFalso()
        for l in lecturas {
            try await InicioDePrueba.guardar(l.mgDl, haceMin: l.haceMin, origen: l.origen, en: repositorio)
        }
        let perfil = RepositorioPerfilFalso(PerfilDato(
            fechaNacimiento: ReglasDePerfil.fechaDeAnio(1990), tipoUsuario: .tipo1,
            usaSensor: usaSensor, consentimientoTsUtc: ahora
        ))
        return try await ConsultarInicio(
            lecturas: repositorio,
            modo: ConsultarModo(lecturas: repositorio),
            carbohidratosActivos: CalcularCarbohidratosActivos(comidas: RepositorioComidasFalso()),
            insulinaActiva: CalcularInsulinaActiva(dosis: RepositorioDosisFalso()),
            perfil: perfil
        ).ejecutar(lecturaHealthKitActiva: usaSensor, ahora: ahora).estadoDelSensor
    }

    @Test("11 · quien no tiene sensor no tiene un sensor roto: no configurado, haya o no lecturas")
    func sinSensorNoHayNadaQueAvisar() async throws {
        #expect(try await estado(usaSensor: false, lecturas: []) == .noConfigurado)
        #expect(try await estado(usaSensor: false, lecturas: [(120, 3, .manual)]) == .noConfigurado)
        // Ni aunque queden lecturas viejas de cuando sí lo tenía.
        #expect(try await estado(usaSensor: false, lecturas: [(120, 400, .sensor)]) == .noConfigurado)
    }

    @Test("12 · con sensor y la última lectura hace 40 min, sin datos desde esa hora")
    func cuarentaMinutosSinDatos() async throws {
        let resultado = try await estado(usaSensor: true, lecturas: [(130, 40, .sensor), (125, 45, .sensor)])
        #expect(resultado == .sinDatos(desde: hace(40)))

        // Lo que entró por Salud con origen HealthKit cuenta igual.
        #expect(try await estado(usaSensor: true, lecturas: [(130, 40, .healthkit)]) == .sinDatos(desde: hace(40)))
        // Y con sensor configurado pero sin una sola lectura todavía, no hay hora que decir.
        #expect(try await estado(usaSensor: true, lecturas: []) == .sinDatos(desde: nil))
    }

    @Test("13 · con sensor y la última lectura hace 5 min, al día")
    func cincoMinutosEsAlDia() async throws {
        #expect(try await estado(usaSensor: true, lecturas: [(130, 5, .sensor)]) == .alDia)
        #expect(try await estado(usaSensor: true, lecturas: [(130, 5, .healthkit), (120, 90, .sensor)]) == .alDia)
    }

    @Test("14 · un pinchazo reciente no prueba que el sensor escriba")
    func elPinchazoNoCuenta() async throws {
        let resultado = try await estado(
            usaSensor: true, lecturas: [(118, 2, .manual), (122, 1, .fotoGlucometro), (130, 40, .sensor)]
        )
        #expect(resultado == .sinDatos(desde: hace(40)))
    }

    @Test("15 · el umbral es frescuraSensorMin, el mismo que decide el modo")
    func unSoloUmbral() async throws {
        let frescura = ConfiguracionDominio.frescuraSensorMin

        // Justo en el umbral todavía está al día; un minuto después, ya no.
        #expect(DecisionModo.estadoDelSensor(usaSensor: true, tsUltimaDelSensor: hace(frescura), ahora: ahora) == .alDia)
        #expect(DecisionModo.estadoDelSensor(usaSensor: true, tsUltimaDelSensor: hace(frescura + 1), ahora: ahora)
            == .sinDatos(desde: hace(frescura + 1)))

        // Y cambia exactamente donde cambia el modo: nunca «al día» en modo sin sensor por
        // frescura, ni «sin datos» en modo sensor.
        for minutos in [0, 5, frescura - 1, frescura, frescura + 1, 40, 600] {
            let modo = DecisionModo.modoActual(
                lecturaHealthKitActiva: true, tsUltimaSensor: hace(minutos), ahora: ahora
            )
            let sensor = DecisionModo.estadoDelSensor(
                usaSensor: true, tsUltimaDelSensor: hace(minutos), ahora: ahora
            )
            #expect((modo == .sensor) == (sensor == .alDia), "a los \(minutos) min")
        }
    }
}
