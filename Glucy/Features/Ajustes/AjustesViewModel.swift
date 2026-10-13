import Foundation

/// El estado de la pantalla de Ajustes.
///
/// Cada cambio se guarda en el momento, pasando por `GuardarAjustes`, que es quien valida.
/// Si un cambio no vale, no se guarda nada y la pantalla se queda con lo que había.
@Observable
final class AjustesViewModel {

    /// `nil` hasta la primera lectura.
    private(set) var ajustes: AjustesEditables?
    /// `nil` si la cola no se pudo leer: no se enseña un cero que nadie contó.
    private(set) var pendientesEnCola: Int?
    private(set) var fallo: String?
    /// Se intentó encender el sensor y no se pudo pedir el permiso. No es un error.
    private(set) var seguimosSinSensor = false
    private(set) var ocupado = false

    // Lo que se teclea vive como texto hasta que se confirma.
    var textoNombre = ""
    var textoApellidos = ""
    var textoPeso = ""
    var textoAnio = ""
    var textoInsulina = ""

    private let guardar: GuardarAjustes
    private let pendientes: ConsultarColaPendiente
    private let completarAlta: CompletarAlta
    private let sincronizar: SincronizarLecturasDelSensor
    private let candado: any Candado

    init(
        guardar: GuardarAjustes,
        pendientes: ConsultarColaPendiente,
        completarAlta: CompletarAlta,
        sincronizar: SincronizarLecturasDelSensor,
        candado: any Candado
    ) {
        self.guardar = guardar
        self.pendientes = pendientes
        self.completarAlta = completarAlta
        self.sincronizar = sincronizar
        self.candado = candado
    }

    func cargar() async {
        pendientesEnCola = await pendientes.ejecutar()
        guard let actuales = try? await guardar.actuales() else { return }
        ajustes = actuales
        ponerTextos(de: actuales)
    }

    /// Aplica un cambio y lo guarda. Si se rechaza, la pantalla vuelve a lo guardado.
    @discardableResult
    func cambiar(ahora: Date = Date(), _ cambio: (inout AjustesEditables) -> Void) async -> Bool {
        guard var nuevos = ajustes else { return false }
        cambio(&nuevos)
        guard nuevos != ajustes else { return true }
        do {
            let guardado = try await guardar.ejecutar(nuevos, ahora: ahora)
            ajustes = AjustesEditables(perfil: guardado)
            fallo = nil
            return true
        } catch let rechazo as Rechazo {
            fallo = AltaViewModel.mensaje(de: rechazo)
        } catch {
            fallo = "No se pudo guardar el cambio. Inténtalo otra vez."
        }
        if let ajustes { ponerTextos(de: ajustes) }
        return false
    }

    /// Lo tecleado, cuando la persona sale del campo.
    func confirmarTextos(ahora: Date = Date()) async {
        guard ajustes != nil else { return }
        let pesoEscrito = textoPeso.trimmingCharacters(in: .whitespaces)
        let peso = RegistroGlucosaViewModel.numero(desde: textoPeso)
        // Un peso o un año que no es un número no se guarda como «sin peso»: se dice.
        if !pesoEscrito.isEmpty, peso == nil {
            fallo = AltaViewModel.mensaje(de: .perfilNoValido(.peso))
            return
        }
        guard let anio = Int(textoAnio.trimmingCharacters(in: .whitespaces)) else {
            fallo = AltaViewModel.mensaje(de: .perfilNoValido(.anioNacimiento))
            return
        }
        await cambiar(ahora: ahora) {
            $0.nombre = textoNombre
            $0.apellidos = textoApellidos
            $0.pesoKg = peso
            $0.anioNacimiento = anio
            $0.tipoInsulinaRapida = textoInsulina
        }
    }

    // MARK: - Sensor

    /// Encender pide el permiso de lectura de Salud, con su explicación ya a la vista en la
    /// pantalla. Apagar no pide nada y no borra nada (RF-07).
    func ponerSensor(_ encendido: Bool) async {
        guard encendido else {
            seguimosSinSensor = false
            await cambiar { $0.usaSensor = false }
            return
        }
        ocupado = true
        defer { ocupado = false }
        guard await completarAlta.pedirPermisoDeSalud() else {
            seguimosSinSensor = true
            return
        }
        seguimosSinSensor = false
        if await cambiar({ $0.usaSensor = true }) {
            await sincronizar.iniciar()
        }
    }

    // MARK: - Candado

    /// Antes de encenderlo se comprueba que la persona puede abrirlo: si cierra la hoja, el
    /// interruptor se queda apagado. Nadie se deja fuera a sí mismo.
    func ponerCandado(_ encendido: Bool) async {
        if encendido {
            ocupado = true
            defer { ocupado = false }
            guard await candado.pedirEntrada(motivo: "Encender el candado de Glucy") else { return }
        }
        await cambiar { $0.bloqueoBiometrico = encendido }
    }

    // MARK: - Pasos

    func moverUmbralHipo(_ pasos: Double) async {
        await cambiar {
            $0.umbralHipo = AltaViewModel.acotar(
                $0.umbralHipo + pasos * AltaViewModel.pasoDeUmbral,
                a: ConfiguracionDominio.umbralHipoConfigurable
            )
        }
    }

    func moverUmbralHiper(_ pasos: Double) async {
        await cambiar {
            $0.umbralHiper = AltaViewModel.acotar(
                $0.umbralHiper + pasos * AltaViewModel.pasoDeUmbral,
                a: ConfiguracionDominio.umbralHiperConfigurable
            )
        }
    }

    func moverDuracion(_ pasos: Double) async {
        await cambiar {
            $0.duracionAccionH = AltaViewModel.acotar(
                $0.duracionAccionH + pasos * AltaViewModel.pasoDeDuracion,
                a: ConfiguracionDominio.duracionAccionConfigurableH
            )
        }
    }

    // MARK: - Textos

    /// Las tres opciones de RF-12b. No hay una cuarta.
    let absorciones = [
        ConfiguracionDominio.absorcionRapidaMin,
        ConfiguracionDominio.absorcionPorOmisionMin,
        ConfiguracionDominio.absorcionLentaMin,
    ]

    func titulo(deAbsorcion minutos: Int) -> String {
        switch minutos {
        case ConfiguracionDominio.absorcionRapidaMin: "Rápida · \(minutos) min"
        case ConfiguracionDominio.absorcionLentaMin: "Lenta · \(minutos) min"
        default: "Normal · \(minutos) min"
        }
    }

    var textoPendientes: String {
        guard let pendientesEnCola else { return "No pude contar los registros en espera." }
        return pendientesEnCola == 1
            ? "1 registro espera en la cola."
            : "\(pendientesEnCola) registros esperan en la cola."
    }

    private func ponerTextos(de ajustes: AjustesEditables) {
        textoNombre = ajustes.nombre
        textoApellidos = ajustes.apellidos
        textoPeso = ajustes.pesoKg.map {
            $0 == $0.rounded() ? String(Int($0)) : String($0)
        } ?? ""
        textoAnio = String(ajustes.anioNacimiento)
        textoInsulina = ajustes.tipoInsulinaRapida
    }
}
