#if DEBUG
import Darwin
import Foundation

/// Cuánto tarda la app, desde que el sistema crea el proceso, en tener el valor de glucosa
/// listo para dibujar. Es lo que el plan pide por debajo de dos segundos.
///
/// Solo existe en la compilación de desarrollo y solo mide si la prueba del arranque lo pide
/// al lanzar: una prueba de interfaz no puede medirlo desde fuera, porque su propio arranque
/// de la automatización tarda varios segundos.
nonisolated enum MedicionDeArranque {
    static let activa = ProcessInfo.processInfo.arguments.contains("-GlucyMedirArranque")

    /// Segundos desde que el sistema creó el proceso. `nil` si el sistema no lo dice.
    static func segundosDesdeElLanzamiento() -> Double? {
        var proceso = kinfo_proc()
        var tamano = MemoryLayout<kinfo_proc>.stride
        var consulta: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        guard sysctl(&consulta, UInt32(consulta.count), &proceso, &tamano, nil, 0) == 0 else {
            return nil
        }
        let inicio = proceso.kp_proc.p_starttime
        let lanzado = Double(inicio.tv_sec) + Double(inicio.tv_usec) / 1_000_000
        return Date().timeIntervalSince1970 - lanzado
    }
}
#endif
