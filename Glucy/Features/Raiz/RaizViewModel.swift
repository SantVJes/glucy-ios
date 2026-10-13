import Foundation

/// Lo que la app enseña al abrirse: el splash, el alta o las pestañas, y encima el candado.
///
/// La puerta es el consentimiento, y quien lo dice es `ConsultarEntrada`. Aquí solo se lleva
/// la cuenta de en qué pantalla se está y de si el candado está echado.
@Observable
final class RaizViewModel {
    enum Pantalla: Equatable { case splash, alta, dentro }

    private(set) var pantalla = Pantalla.splash
    private(set) var bloqueada = false

    private var bloqueoActivo = false
    private var salioTs: Date?
    private var pidiendoEntrada = false

    private let consultar: ConsultarEntrada
    private let candado: any Candado
    private let sincronizar: SincronizarLecturasDelSensor

    init(
        consultar: ConsultarEntrada,
        candado: any Candado,
        sincronizar: SincronizarLecturasDelSensor
    ) {
        self.consultar = consultar
        self.candado = candado
        self.sincronizar = sincronizar
    }

    /// El splash dura lo que tarda en leerse el perfil, con un mínimo para que no parpadee.
    func arrancar() async {
        pantalla = .splash
        let inicio = ContinuousClock.now
        let estado = await consultar.ejecutar()
        let falta = Duration.seconds(ConfiguracionDominio.splashMinimoS) - (ContinuousClock.now - inicio)
        if falta > .zero { try? await Task.sleep(for: falta) }

        bloqueoActivo = estado.bloqueoBiometrico
        guard estado.consintio else {
            bloqueada = false
            pantalla = .alta
            return
        }
        // El candado se echa antes de enseñar las pestañas, no después.
        bloqueada = bloqueoActivo
        pantalla = .dentro
        await pedirEntrada()
    }

    /// El alta terminó. Si la persona dijo que tiene sensor, ahora sí hay permiso que usar:
    /// se registra el observador y se trae lo que haya.
    func altaCompletada() async {
        let estado = await consultar.ejecutar()
        guard estado.consintio else { return }
        bloqueoActivo = estado.bloqueoBiometrico
        pantalla = .dentro
        await sincronizar.iniciar()
    }

    /// Después de borrar la cuenta la app queda como recién instalada.
    func cuentaBorrada() async {
        bloqueada = false
        await arrancar()
    }

    func salioASegundoPlano(ahora: Date = Date()) {
        // Solo la primera vez: pasar de inactiva a segundo plano no reinicia la cuenta.
        if salioTs == nil { salioTs = ahora }
    }

    /// Al volver de segundo plano. El candado se pide otra vez solo si pasó un rato: no al
    /// cambiar de pestaña ni por contestar un mensaje.
    func volvio(ahora: Date = Date()) async {
        defer { salioTs = nil }
        guard pantalla == .dentro else { return }
        if bloqueada {
            await pedirEntrada()
            return
        }
        // Se vuelve a leer: el interruptor pudo cambiar en Ajustes.
        bloqueoActivo = await consultar.ejecutar().bloqueoBiometrico
        guard bloqueoActivo, let salioTs,
              ahora.timeIntervalSince(salioTs) > ConfiguracionDominio.graciaDelCandadoS else { return }
        bloqueada = true
        await pedirEntrada()
    }

    func pedirEntrada() async {
        guard bloqueada, !pidiendoEntrada else { return }
        pidiendoEntrada = true
        defer { pidiendoEntrada = false }
        if await candado.pedirEntrada(motivo: "Abrir Glucy") {
            bloqueada = false
        }
    }
}
