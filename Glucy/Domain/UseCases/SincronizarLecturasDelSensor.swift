import Foundation

/// Lo que dejó una pasada de sincronización con Salud.
nonisolated struct ResultadoSincronizacion: Sendable, Equatable {
    /// Filas nuevas en el teléfono. Una muestra reentregada no cuenta.
    let guardadas: Int
    /// Muestras que no pasaron la validación del paso 1 (fuera de 20–600, hora futura).
    let descartadas: Int
    let estado: EstadoModo
}

/// Trae de Salud la glucosa que escribió la app del sensor y la guarda en el teléfono.
///
/// Se guarda lo que llegó y nada más (RF-06b): no se supone una muestra cada cinco minutos
/// ni se rellena un hueco. Si entre dos muestras hay dos horas, en el teléfono también.
nonisolated struct SincronizarLecturasDelSensor: Sendable {
    let servicio: any ServicioHealthKit
    let lecturas: any RepositorioLecturas
    let ancla: AnclaHealthKit

    /// Tope de lotes por pasada, para que un ancla que HealthKit nunca diera por terminada
    /// no deje la pasada corriendo para siempre. Con lotes de 500 son años de sensor.
    private static let lotesMaximosPorPasada = 1_000

    /// Pide los permisos, registra el observador y hace la primera pasada. Se llama al
    /// arrancar, también cuando iOS despierta la app en segundo plano: el observador tiene
    /// que estar registrado antes de que termine el arranque o la entrega se pierde.
    ///
    /// Nada de esto lanza. Sin permiso o sin Salud la app sigue, en modo sin sensor.
    func iniciar() async {
        try? await servicio.pedirPermisos()
        let caso = self
        try? await servicio.observarGlucosa {
            _ = await caso.ejecutar()
        }
        _ = await ejecutar()
    }

    /// Una pasada: todo lo nuevo desde el ancla guardada, lote por lote.
    ///
    /// **No lanza.** Un fallo de HealthKit no es una excepción que la pantalla deba mostrar:
    /// es la condición normal «no hay sensor». Revocar el permiso desde Salud llega por aquí
    /// (RF-07, caso P-09), igual que un sensor apagado o un teléfono sin Salud.
    func ejecutar(ahora: Date = Date()) async -> ResultadoSincronizacion {
        var guardadas = 0
        var descartadas = 0
        var respondio = servicio.disponible

        if respondio {
            do {
                var anclaActual = ancla.leer()
                for _ in 0..<Self.lotesMaximosPorPasada {
                    let lote = try await servicio.muestrasNuevas(desde: anclaActual)
                    let conteo = try await guardar(lote.muestras, ahora: ahora)
                    guardadas += conteo.guardadas
                    descartadas += conteo.descartadas

                    // El ancla avanza solo después de guardar. Si el guardado falla, la
                    // siguiente pasada vuelve a pedir el mismo lote en lugar de perderlo.
                    ancla.guardar(lote.ancla)
                    anclaActual = lote.ancla
                    if !lote.hayMas { break }
                }
            } catch {
                respondio = false
            }
        }

        let estado = (try? await ConsultarModo(lecturas: lecturas)
            .ejecutar(lecturaHealthKitActiva: respondio, ahora: ahora))
            // Sin poder leer la base tampoco se puede afirmar que el sensor esté fresco.
            ?? EstadoModo(modo: .sinSensor, antiguedadMin: nil)

        return ResultadoSincronizacion(
            guardadas: guardadas,
            descartadas: descartadas,
            estado: estado
        )
    }

    private func guardar(
        _ muestras: [MuestraGlucosa],
        ahora: Date
    ) async throws -> (guardadas: Int, descartadas: Int) {
        var guardadas = 0
        var descartadas = 0

        for muestra in muestras {
            // Lo que escribió Glucy ya está en el teléfono con su origen verdadero. Volver
            // a guardarlo como sensor lo duplicaría y lo haría pasar por lo que no es
            // (RF-15b, caso P-14).
            guard !muestra.esPropia else { continue }

            if Validacion.validarLectura(
                mgDl: muestra.mgDl, tsUtc: muestra.ts, ahora: ahora, origen: .sensor
            ) != nil {
                descartadas += 1
                continue
            }

            let dato = LecturaGlucosaDato(
                uuid: muestra.uuid,
                mgDl: muestra.mgDl,
                tsUtc: muestra.ts,
                zonaHoraria: muestra.zonaHoraria ?? TimeZone.current.identifier,
                origen: .sensor,
                contexto: muestra.contexto,
                // Ya está en Salud: es de donde vino.
                escritaEnHealthKit: true
            )
            if try await lecturas.guardar(dato) { guardadas += 1 }
        }
        return (guardadas, descartadas)
    }
}
