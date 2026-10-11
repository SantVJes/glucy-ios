import Foundation

/// El estado de la pantalla de registro de insulina.
///
/// **No tiene ninguna regla clínica**, igual que el de glucosa: qué dosis se puede anotar lo
/// decide `Validacion.validarDosis` a través de `RegistrarDosis`. Y no hay aquí ninguna
/// cuenta que termine en unidades: lo único que se le suma al campo es la media unidad de
/// los botones, porque la persona la tocó (regla 7).
@Observable
final class RegistroInsulinaViewModel {

    /// Es `String` y no `Double` por lo mismo que en glucosa: con `Double` no se distingue
    /// «vacío» de «cero».
    var textoUnidades: String = "" {
        didSet { if textoUnidades != oldValue, fallo?.campo == .valor { fallo = nil } }
    }

    /// `nil` hasta que la persona elige o hasta que se conoce el de su último registro. No
    /// se preselecciona ninguno en la primera dosis.
    var tipo: TipoInsulina? {
        didSet { if fallo == .tipoSinElegir { fallo = nil } }
    }

    /// `nil` es una respuesta válida: el motivo se puede dejar en blanco y no se adivina.
    var motivo: MotivoDosis?

    private(set) var fecha: Date = Date()
    /// Mientras la persona no toque la hora, la dosis se guarda con la del momento de
    /// guardar. La pantalla queda montada aunque no se vea, y la hora de cuando se abrió la
    /// app puede ser de hace horas: con ella la insulina activa saldría mal.
    private var fechaElegida = false

    private(set) var fallo: FalloRegistro?
    private(set) var guardando = false
    private(set) var ultimaGuardada: DosisInsulinaDato?

    /// `nil` mientras no se haya podido calcular. No se enseña un cero que nadie midió.
    private(set) var insulinaActiva: Double?
    private(set) var ultimaDosis: DosisInsulinaDato?

    private let registrar: RegistrarDosis
    private let calcular: CalcularInsulinaActiva
    private let ajustes: ConsultarAjustesDeInsulina

    init(
        registrar: RegistrarDosis,
        calcular: CalcularInsulinaActiva,
        ajustes: ConsultarAjustesDeInsulina
    ) {
        self.registrar = registrar
        self.calcular = calcular
        self.ajustes = ajustes
    }

    var sePuedeGuardar: Bool {
        !textoUnidades.trimmingCharacters(in: .whitespaces).isEmpty && !guardando
    }

    func elegir(fecha nueva: Date) {
        fecha = nueva
        fechaElegida = true
        if fallo?.campo == .fecha { fallo = nil }
    }

    /// Los botones de más y menos. Una pluma va de media en media unidad y los valores de
    /// todos los días son 2, 2.5, 4: tocar dos veces es menos trabajo que teclear.
    func moverMediaUnidad(haciaArriba: Bool) {
        let paso = ConfiguracionDominio.insulinaResolucionUI
        let escrito = Self.numero(desde: textoUnidades) ?? 0
        let enPasos = (escrito.isFinite ? escrito : 0) / paso
        // Desde un valor que no cae en media unidad se va a la siguiente media, no a
        // «lo escrito más 0.5».
        let nuevo = (haciaArriba ? enPasos.rounded(.down) + 1 : enPasos.rounded(.up) - 1) * paso
        let acotado = min(
            max(nuevo, ConfiguracionDominio.insulinaMinima), ConfiguracionDominio.insulinaMaxima
        )
        textoUnidades = acotado > ConfiguracionDominio.insulinaMinima ? Self.texto(de: acotado) : ""
    }

    func guardar(ahora: Date = Date()) async {
        // La guarda contra el doble toque: el botón se deshabilita, pero un toque doble
        // rápido llega antes de que la vista se redibuje.
        guard !guardando else { return }

        guard let unidades = Self.numero(desde: textoUnidades) else {
            fallo = .unidadesVacias
            return
        }
        guard let tipo else {
            fallo = .tipoSinElegir
            return
        }

        guardando = true
        defer { guardando = false }

        do {
            ultimaGuardada = try await registrar.ejecutar(
                unidades: unidades,
                tsUtc: fechaElegida ? fecha : ahora,
                tipo: tipo,
                motivo: motivo,
                // La del perfil de hoy; queda guardada con la dosis.
                duracionAccionH: await ajustes.duracionAccionH(),
                ahora: ahora
            )
            fallo = nil
            textoUnidades = ""
            motivo = nil
            fechaElegida = false
            // El tipo se queda: la siguiente dosis casi siempre es del mismo.
            await ponerAlDia(ahora: ahora)
        } catch let falloDeRegistro as FalloRegistro {
            fallo = falloDeRegistro
        } catch {
            fallo = .dosisNoSePudoGuardar
        }
    }

    /// Deshace el último guardado. Mejor que preguntar «¿estás seguro?».
    func deshacer(ahora: Date = Date()) async {
        guard let guardada = ultimaGuardada else { return }
        do {
            try await registrar.deshacer(guardada)
            ultimaGuardada = nil
            await ponerAlDia(ahora: ahora)
        } catch {
            fallo = .dosisNoSePudoGuardar
        }
    }

    /// Quita la franja de confirmación sin deshacer nada.
    func olvidarConfirmacion() {
        ultimaGuardada = nil
    }

    /// Lo que cambia solo con el paso del tiempo: la hora propuesta y la insulina que queda.
    func ponerAlDia(ahora: Date = Date()) async {
        if !fechaElegida { fecha = ahora }

        ultimaDosis = await registrar.ultima()
        // El tipo del último registro, y solo si la persona no ha elegido ya otro.
        if tipo == nil { tipo = ultimaDosis?.tipo }

        insulinaActiva = try? await calcular.ejecutar(ahora: ahora)
    }

    // MARK: - Textos

    /// «Te quedan 2.4 UI trabajando · última dosis a las 14:30». Es una cifra, no un
    /// consejo: no va seguida de ninguna recomendación (regla 7).
    var textoInsulinaActiva: String? {
        frase(unidad: "UI", separador: " · ")
    }

    /// Lo mismo para VoiceOver, que lee «UI» como dos letras sueltas.
    var textoInsulinaActivaHablado: String? {
        frase(unidad: "unidades de insulina", separador: ", ")
    }

    private func frase(unidad: String, separador: String) -> String? {
        guard let insulinaActiva else { return nil }
        // Lo que redondeado a una décima ya es cero se dice como cero: «0.0 UI» no informa.
        let decimas = (insulinaActiva * 10).rounded() / 10
        guard decimas > 0 else { return "No te queda insulina trabajando" }

        var texto = "Te quedan \(String(format: "%.1f", decimas)) \(unidad) trabajando"
        if let ultimaDosis {
            let hora = ultimaDosis.tsUtc.formatted(date: .omitted, time: .shortened)
            texto += "\(separador)última dosis a las \(hora)"
        }
        return texto
    }

    // MARK: - Números

    /// Acepta la coma decimal del teclado mexicano.
    static func numero(desde texto: String) -> Double? {
        RegistroGlucosaViewModel.numero(desde: texto)
    }

    /// Sin decimales cuando el número es entero: «4», no «4.0».
    static func texto(de unidades: Double) -> String {
        unidades == unidades.rounded() ? String(Int(unidades)) : String(unidades)
    }
}
