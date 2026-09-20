import Foundation
import SwiftData

/// El perfil sobre SwiftData. Hay uno solo.
///
/// **No encola nunca.** El perfil nace `local` y se queda ahí: lo que identifica a la
/// persona no sale del teléfono (regla 3). Los parámetros que el backend necesita para el
/// modelo viajarán en la fase 2 como una carga aparte y reducida, no como esta fila.
@ModelActor
actor PerfilSwiftData: RepositorioPerfil {

    func actual() throws -> PerfilDato? {
        var descriptor = FetchDescriptor<Perfil>(
            sortBy: [SortDescriptor(\.creadoTsUtc, order: .forward)]
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first?.dato
    }

    func guardar(_ dato: PerfilDato) throws {
        let uuid = dato.uuid
        var descriptor = FetchDescriptor<Perfil>(predicate: #Predicate { $0.uuid == uuid })
        descriptor.fetchLimit = 1

        if let existente = try modelContext.fetch(descriptor).first {
            existente.nombre = dato.nombre
            existente.apellidos = dato.apellidos
            existente.pesoKg = dato.pesoKg
            existente.fechaNacimiento = dato.fechaNacimiento
            existente.tipoUsuario = dato.tipoUsuario
            existente.umbralHipo = dato.umbralHipo
            existente.umbralHiper = dato.umbralHiper
            existente.tiempoAbsorcionPorOmisionMin = dato.tiempoAbsorcionPorOmisionMin
            existente.duracionAccionInsulinaH = dato.duracionAccionInsulinaH
            existente.usaSensor = dato.usaSensor
            existente.actualizadoTsUtc = dato.actualizadoTsUtc
            existente.zonaHoraria = dato.zonaHoraria
            existente.syncEstado = .local
        } else {
            let fila = Perfil(dato: dato)
            // Se fuerza aquí y no se confía en quien llama: da igual con qué estado venga
            // el struct, el perfil no viaja.
            fila.syncEstado = .local
            modelContext.insert(fila)
        }
        try modelContext.save()
    }

    func existe() throws -> Bool {
        try modelContext.fetchCount(FetchDescriptor<Perfil>()) > 0
    }
}
