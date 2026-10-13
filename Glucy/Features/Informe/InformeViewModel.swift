import Foundation

/// El estado de la hoja desde la que se comparte el informe: el interruptor de identidad y el
/// archivo temporal.
@Observable
final class InformeViewModel {

    /// Nace **apagado**: sin que la persona lo decida, el informe solo lleva sus cifras.
    private(set) var conIdentidad = false
    /// El PDF listo para compartir. `nil` mientras se arma.
    private(set) var archivo: URL?
    private(set) var informe: Informe?
    private(set) var generando = false
    private(set) var fallo: String?

    let periodoDias: Int
    private let armar: ArmarInforme
    private let generador: GeneradorDePdf

    init(armar: ArmarInforme, periodoDias: Int, generador: GeneradorDePdf = GeneradorDePdf()) {
        self.armar = armar
        self.periodoDias = periodoDias
        self.generador = generador
    }

    /// Cambia el interruptor y vuelve a armar el archivo: el de antes se borra en el momento,
    /// para que no quede a la mano un PDF con una identidad que ya no se quiere compartir.
    func poner(conIdentidad nuevo: Bool, ahora: Date = Date()) async {
        guard nuevo != conIdentidad else { return }
        conIdentidad = nuevo
        await preparar(ahora: ahora)
    }

    /// Arma el informe del periodo y lo escribe en la carpeta temporal.
    func preparar(ahora: Date = Date()) async {
        guard !generando else { return }
        generando = true
        defer { generando = false }
        soltarArchivo()

        do {
            let nuevo = try await armar.ejecutar(
                dias: periodoDias, conIdentidad: conIdentidad, ahora: ahora
            )
            informe = nuevo
            archivo = try generador.generar(InformeView(informe: nuevo), nombre: Self.nombre(ahora))
            fallo = nil
        } catch {
            informe = nil
            fallo = "No se pudo armar el informe. Inténtalo otra vez."
        }
    }

    /// Al cerrarse la hoja. Un informe con el nombre de la persona dentro no se queda en el
    /// disco: lo que no hace falta guardar, no se guarda.
    func cerrar() {
        soltarArchivo()
        generador.borrarTodos()
    }

    private func soltarArchivo() {
        if let archivo { generador.borrar(archivo) }
        archivo = nil
    }

    /// El nombre del archivo lleva la fecha y nada de la persona.
    static func nombre(_ ahora: Date) -> String {
        "Informe de glucosa \(ahora.formatted(.iso8601.year().month().day()))"
    }
}
