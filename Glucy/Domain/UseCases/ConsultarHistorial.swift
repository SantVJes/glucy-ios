import Foundation

/// Todo lo que la pantalla de historial dibuja, ya resuelto.
nonisolated struct EstadoHistorial: Sendable, Equatable {
    let periodoDias: Int
    /// `nil` cuando no llega al mínimo de días. La pantalla dice qué falta, no un cero.
    let indicadores: Indicadores?
    /// En cuántos días distintos del periodo hay al menos una lectura.
    let diasConLecturas: Int
    /// `true` cuando hay 14 días o más y el GMI significa algo.
    let gmiEsFiable: Bool
    let diaTipico: [HoraTipica]
    /// Cuántas de las 24 horas no llegaron al mínimo. Se dice en el pie de la gráfica.
    let horasSinDatos: Int
}

/// Los indicadores del periodo y el día típico (RF-16).
///
/// Lo que decide es **cuándo se enseña cada cifra**, que es donde un indicador bien
/// calculado puede engañar: con dos días de lecturas un tiempo en rango describe un día
/// suelto, y un GMI sobre seis pinchazos sale igual de bonito y no significa nada.
nonisolated struct ConsultarHistorial: Sendable {
    let lecturas: any RepositorioLecturas
    let perfil: any RepositorioPerfil

    /// - Parameter periodoDias: uno de `ConfiguracionDominio.periodosHistorialDias`.
    /// - Parameter ahora: se pasa, no se toma de `Date()` dentro, para poder probarlo.
    func ejecutar(periodoDias: Int, ahora: Date = Date()) async throws -> EstadoHistorial {
        let delPeriodo = try await lecturas.entre(
            desde: ahora.addingTimeInterval(-Double(periodoDias) * 86_400), hasta: ahora
        )
        // Días distintos en la zona guardada con cada lectura, igual que el día típico.
        let dias = Set(delPeriodo.map(DiaTipico.diaLocal)).count

        guard dias >= ConfiguracionDominio.diasMinimosIndicadores else {
            return EstadoHistorial(
                periodoDias: periodoDias,
                indicadores: nil,
                diasConLecturas: dias,
                gmiEsFiable: false,
                diaTipico: [],
                horasSinDatos: 24
            )
        }

        // Los umbrales del perfil mueven el TBR y el TAR; el TIR es fijo. Sin perfil, o si
        // no se puede leer, valen los de omisión: el historial no se cae el primer día.
        let actual = try? await perfil.actual()
        let diaTipico = DiaTipico.calcular(lecturas: delPeriodo)

        return EstadoHistorial(
            periodoDias: periodoDias,
            indicadores: CalculoIndicadores.calcular(
                valores: delPeriodo.map(\.mgDl),
                umbralHipo: actual?.umbralHipo ?? ConfiguracionDominio.umbralHipoPorOmision,
                umbralHiper: actual?.umbralHiper ?? ConfiguracionDominio.umbralHiperPorOmision
            ),
            diasConLecturas: dias,
            gmiEsFiable: dias >= ConfiguracionDominio.diasMinimosGmi,
            diaTipico: diaTipico,
            horasSinDatos: 24 - diaTipico.count
        )
    }
}
