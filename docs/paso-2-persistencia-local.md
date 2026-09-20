# Paso 2 — Persistencia local

Instrucciones concretas para el segundo paso de la fase 1. Están escritas para pegárselas a
Claude Code corriendo en la MacBook, dentro de esta misma carpeta, pero se leen igual de bien
a mano.

Contexto general: `CLAUDE.md` en la raíz. Plan completo de la fase:
`glucy-base/04-PLAN-FASE-1.md` en los archivos del proyecto. El paso anterior:
`docs/paso-1-dominio-y-reglas.md`, ya terminado y fusionado.

---

## 0. Antes de abrir Claude Code

```bash
cd ~/Documents/glucy-ios
git switch develop
git pull origin develop
git switch -c feature/persistencia-local
```

Sale de `develop`, no de `main`. En el paso 1 la rama se fusionó directo a `main` y `develop`
se quedó atrás; ya está al día, pero la convención del proyecto es `feature` → `develop` →
`main`.

---

## 1. Qué se construye en el paso 2, y por qué va ahora

El paso 1 dejó las diez tablas escritas y las reglas probadas, pero **nada se guarda
todavía**: no hay contenedor de SwiftData en marcha y la app sigue mostrando la pantalla de
«Hello, Glucy!» que puso el asistente de Xcode.

El paso 2 pone la base de datos local a funcionar y la tapa detrás de protocolos, para que
de aquí en adelante ninguna pantalla sepa que existe SwiftData.

Va ahora porque **los cuatro acuerdos que permiten conectar un backend meses después hay que
tomarlos desde el primer día**, y los cuatro viven en esta capa:

1. **El UUID lo genera el teléfono**, nunca la base ni el servidor.
2. **`syncEstado` en cada registro**, desde que nace.
3. **Envío idempotente**: guardar dos veces el mismo UUID no crea dos filas.
4. **Flujo en un solo sentido por tipo de dato**: el teléfono manda sobre lecturas, comidas,
   insulina y contexto; el backend sobre predicciones, versiones del modelo y agregados.

Si esto se deja para la fase 2, hay que migrar datos ya guardados sin UUID propio y sin
estado de sincronización, y eso cuesta mucho más que escribirlo ahora.

---

## 1 bis. Los tres requisitos, pegados

No basta con citar el identificador: quien escribe el código tiene que poder leer el
requisito sin abrir otro documento. Son estos tres, copiados literalmente del Documento 2
v6, con lo que en el paso 2 los cumple y la prueba que lo demuestra.

### RF-20 (fase 1)

> La app funciona completa sin conexión: cola de sincronización local que se vacía cuando
> hay wifi.

**Qué lo cumple aquí:** la base de datos local funcionando y `ColaSincronizacion`
llenándose sola en cada guardado. Registrar una lectura, una comida y una dosis no toca la
red en ningún momento.

**Ojo con la segunda mitad:** *«que se vacía cuando hay wifi»* **no** es del paso 2, porque
no hay servidor hasta la fase 2. Lo que se entrega hoy es la parte de arriba: funciona sin
conexión, y lo que se captura se queda en la cola esperando (caso P-07, modo avión).
`DecisionSincronizacion.debeSincronizar`, del paso 1, ya tiene la regla de cuándo vaciarla.

**Prueba que lo demuestra:** la 6 y la 9 de la tabla del apartado 8.

### RF-36b (fase 2, lado app desde ahora)

> Cada registro local lleva un estado de sincronización (local, pendiente, enviado,
> confirmado, error) y solo sale de la cola cuando el servidor confirma. Un fallo deja el
> motivo y se reintenta en la siguiente ventana de wifi.

**Qué lo cumple aquí:** los cinco estados ya existen en `SyncEstado`, del paso 1. El paso 2
los pone a funcionar: todo nace en `pendiente` salvo lo del grupo que nunca sale, que nace
en `local`, y `marcarError` guarda el motivo y sube el contador de intentos **sin borrar la
fila**.

Este requisito está etiquetado como fase 2 en el Documento 2 porque la mitad que habla del
servidor es de allá. La mitad del teléfono se construye hoy, igual que pasa con RF-36c.

**Prueba que lo demuestra:** la 2, la 7, la 8 y sobre todo la 13.

### RF-36c (fase 1 en la app, fase 2 en el servidor)

> El identificador de cada registro es un UUID generado en el teléfono, y el envío es
> idempotente: el servidor acepta el mismo UUID dos veces sin duplicar.

**Qué lo cumple aquí:** el UUID ya lo genera cada modelo en su `init`, del paso 1. El paso 2
agrega la idempotencia **del lado del teléfono**: `guardar` comprueba el UUID antes de
insertar y devuelve `false` en lugar de crear una segunda fila. Importa antes de que exista
el servidor, porque HealthKit reentrega las mismas muestras y la persona puede tocar
«guardar» dos veces.

**Prueba que lo demuestra:** la 5.

---

## 2. La decisión del paso 2, y hay que entenderla antes de escribir código

El target compila con **Swift 6 y concurrencia estricta**, y con
`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`. Eso obliga a decidir una cosa:

> **Los objetos `@Model` de SwiftData no son `Sendable` y no pueden cruzar de un actor a
> otro.** Si un repositorio es un actor y devuelve un `LecturaGlucosa`, no compila.

Hay dos salidas, y aquí se toma la segunda:

| Salida | Qué implica |
| --- | --- |
| Repositorios en `@MainActor` | Compila hoy sin trabajo extra, pero **toda** escritura ocurre en el hilo principal. En el paso 4 la entrega en segundo plano de HealthKit no podría escribir, y habría que rehacer esta capa entera. |
| **Repositorios como `@ModelActor`, que intercambian structs `Sendable`** ← la que se usa | Un poco más de código hoy: cinco structs de valor y sus conversiones. A cambio, HealthKit en segundo plano y la cola de sincronización pueden escribir sin tocar el hilo principal, y nada se rehace después. |

Es el mismo criterio del punto anterior: los acuerdos se toman el primer día.

**Cómo queda, en concreto:**

- Las clases `@Model` del paso 1 **no se tocan**. Siguen siendo las filas de la base.
- Por cada tipo que el paso 2 maneja se escribe un **struct `Sendable`** con el sufijo
  `Dato`: `LecturaGlucosaDato`, `ComidaDato`, `DosisInsulinaDato`, `PerfilDato`,
  `PendienteDato`. Son planos, sin métodos, solo los campos.
- Cada `@Model` gana dos cosas: un `init(dato:)` y una propiedad `var dato: XDato` que lo
  convierte. Nada más.
- **Los protocolos de repositorio solo hablan de los structs.** Un `@Model` nunca sale de
  `Data/`.

---

## 3. Archivos que hay que crear

```
Glucy/
  Data/
    Repositories/                      ← los protocolos, nada de SwiftData aquí
      RepositorioPerfil.swift
      RepositorioLecturas.swift
      RepositorioComidas.swift
      RepositorioDosis.swift
      RepositorioCola.swift
      ErrorPersistencia.swift
    SwiftData/
      EsquemaGlucy.swift               ← esquema versionado + plan de migración
      ContenedorGlucy.swift            ← crea el ModelContainer
      PerfilSwiftData.swift
      LecturasSwiftData.swift
      ComidasSwiftData.swift
      DosisSwiftData.swift
      ColaSwiftData.swift
  Domain/
    Models/
      Datos/                           ← los cinco structs Sendable
        LecturaGlucosaDato.swift
        ComidaDato.swift
        DosisInsulinaDato.swift
        PerfilDato.swift
        PendienteDato.swift
    (lo del paso 1 se queda como está)
  App/
    ContenedorDependencias.swift       ← quién le da los repositorios a quién

GlucyTests/
  ContenedorTests.swift
  LecturasSwiftDataTests.swift
  ComidasSwiftDataTests.swift
  DosisSwiftDataTests.swift
  ColaSwiftDataTests.swift
  IdempotenciaTests.swift
```

El proyecto usa **carpetas sincronizadas**: basta crear los archivos en el disco, entran
solos al proyecto de Xcode. No hay que registrarlos uno por uno.

---

## 4. El contenedor y el esquema

```swift
// Data/SwiftData/EsquemaGlucy.swift

nonisolated enum EsquemaGlucyV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    /// Las diez tablas del paso 1. Si falta una, SwiftData no la crea y la app se cae al
    /// primer acceso, no al arrancar: el error aparece lejos de su causa.
    static var models: [any PersistentModel.Type] {
        [Perfil.self, LecturaGlucosa.self, Comida.self, DosisInsulina.self,
         EventoContexto.self, Alerta.self, PrediccionCache.self, ProductoCache.self,
         ColaSincronizacion.self, ColaXapi.self]
    }
}

/// Hay una sola versión, pero el plan existe desde hoy: cuando llegue la segunda, el
/// camino de migración ya tiene dónde escribirse y los datos de las pruebas de campo no
/// se pierden.
nonisolated enum PlanMigracionGlucy: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [EsquemaGlucyV1.self] }
    static var stages: [MigrationStage] { [] }
}
```

```swift
// Data/SwiftData/ContenedorGlucy.swift

nonisolated enum ContenedorGlucy {
    /// - Parameter enMemoria: `true` en las pruebas. Cada prueba levanta su propio
    ///   contenedor y no comparte estado con la siguiente ni deja archivos en el disco.
    static func crear(enMemoria: Bool = false) throws -> ModelContainer
}
```

Dos notas que importan y que no se deducen del código:

- **No se toca la protección de archivos.** La base queda con la protección por omisión de
  iOS, que permite leer y escribir después del primer desbloqueo. Subirla a «completa»
  cifraría el archivo con el teléfono bloqueado y **la entrega en segundo plano de HealthKit
  del paso 4 dejaría de poder escribir**, que es justo cuando más falta hace.
- **Nada de CloudKit.** El teléfono es el dueño del dato y el backend es la copia; meter un
  tercer sincronizador que además exige que todo campo tenga valor por omisión no está en el
  alcance.

---

## 5. Los protocolos, con su firma exacta

Todos son `async throws` porque del otro lado hay un actor. Todos hablan de structs.

```swift
// Data/Repositories/ErrorPersistencia.swift

nonisolated enum ErrorPersistencia: Error, Equatable {
    case noEncontrado(uuid: UUID)
    case contenedorNoDisponible
    case escrituraFallida(motivo: String)
}
```

```swift
// Data/Repositories/RepositorioLecturas.swift

nonisolated protocol RepositorioLecturas: Sendable {
    /// Guarda la lectura y la encola. Devuelve `false` si ya existía una con ese UUID.
    ///
    /// No lanza error al duplicado: HealthKit reentrega las mismas muestras y el usuario
    /// puede tocar «guardar» dos veces. Un duplicado es normal, no una falla (RF-36c).
    @discardableResult
    func guardar(_ dato: LecturaGlucosaDato) async throws -> Bool

    func porUuid(_ uuid: UUID) async throws -> LecturaGlucosaDato?

    /// La más reciente por `tsUtc`, no por orden de inserción: HealthKit entrega en bloques
    /// y con retraso, así que lo último que llega no es lo último que ocurrió (RF-06b).
    func ultima() async throws -> LecturaGlucosaDato?

    /// Rango cerrado, ordenado de la más vieja a la más nueva.
    func entre(desde: Date, hasta: Date) async throws -> [LecturaGlucosaDato]

    func contar() async throws -> Int
}
```

```swift
// Data/Repositories/RepositorioComidas.swift

nonisolated protocol RepositorioComidas: Sendable {
    @discardableResult
    func guardar(_ dato: ComidaDato) async throws -> Bool
    func porUuid(_ uuid: UUID) async throws -> ComidaDato?
    /// Las de las últimas `horas`, que es lo que el COB necesita. Nunca infiere ninguna
    /// que no esté registrada (D-9, RF-37).
    func recientes(horas: Double, hasta: Date) async throws -> [ComidaDato]
    func contar() async throws -> Int
}
```

```swift
// Data/Repositories/RepositorioDosis.swift

nonisolated protocol RepositorioDosis: Sendable {
    @discardableResult
    func guardar(_ dato: DosisInsulinaDato) async throws -> Bool
    func porUuid(_ uuid: UUID) async throws -> DosisInsulinaDato?
    /// Las de las últimas `horas`, que es lo que el IOB necesita.
    func recientes(horas: Double, hasta: Date) async throws -> [DosisInsulinaDato]
    func contar() async throws -> Int
}
```

```swift
// Data/Repositories/RepositorioPerfil.swift

nonisolated protocol RepositorioPerfil: Sendable {
    /// Hay uno solo. `nil` mientras la persona no haya pasado por el alta.
    func actual() async throws -> PerfilDato?
    func guardar(_ dato: PerfilDato) async throws
    func existe() async throws -> Bool
}
```

```swift
// Data/Repositories/RepositorioCola.swift

nonisolated protocol RepositorioCola: Sendable {
    /// Encola un registro. Si ese UUID ya estaba en la cola no lo mete dos veces.
    @discardableResult
    func encolar(tipo: String, uuidRegistro: UUID) async throws -> Bool

    /// Lo más antiguo primero, hasta `limite`. La cola se vacía en el orden en que se
    /// llenó, o el backend reconstruiría la serie desordenada.
    func pendientes(limite: Int) async throws -> [PendienteDato]

    func marcarEnviado(uuid: UUID) async throws
    /// Un fallo no se descarta en silencio: se guarda el motivo y sube el contador de
    /// intentos, para poder mostrarlo y reintentar (RF-22).
    func marcarError(uuid: UUID, motivo: String) async throws
    func contarPendientes() async throws -> Int
}
```

---

## 6. Las implementaciones

Una por protocolo, en `Data/SwiftData/`, todas con la misma forma:

```swift
@ModelActor
actor LecturasSwiftData: RepositorioLecturas {
    // El macro @ModelActor genera el init(modelContainer:) y el modelContext aislado.
}
```

Tres reglas que valen para las cinco:

1. **La idempotencia se comprueba antes de insertar**, con un `FetchDescriptor` filtrado por
   `uuid` y `fetchLimit = 1`. El `@Attribute(.unique)` de SwiftData también lo evitaría, pero
   lanzando; aquí se quiere un `false` tranquilo, no un error.
2. **Guardar y encolar ocurren en la misma llamada**, antes del `save()`. Si se separan, un
   cierre de la app entre las dos deja un registro que nunca va a subir y nadie se entera.
3. **Lo que nace `local` no se encola nunca.** Son `Perfil` y `ProductoCache`: lo que
   identifica a la persona no sube (regla 3), y el caché de Open Food Facts es dato de un
   tercero, no de ella.

> **Decisión que se toma aquí y hay que confirmar en la fase 2:** el `Perfil` completo nace
> en `local` y no se encola. Los parámetros que el backend sí necesita para el modelo (los
> umbrales, el tiempo de absorción, la duración de acción) viajarán en la fase 2 como una
> carga aparte y reducida, no como la fila del perfil. Así `nombre`, `apellidos` y `pesoKg`
> no tienen por dónde escaparse.

---

## 7. Quién le da los repositorios a quién

```swift
// App/ContenedorDependencias.swift

@Observable
final class ContenedorDependencias {
    let lecturas: any RepositorioLecturas
    let comidas: any RepositorioComidas
    let dosis: any RepositorioDosis
    let perfil: any RepositorioPerfil
    let cola: any RepositorioCola

    init(contenedor: ModelContainer)
}
```

Se crea una vez en `GlucyApp.swift` y se inyecta con `.environment(...)`. Las pantallas
piden el protocolo, nunca la implementación: por eso en las pruebas se puede meter una falsa
sin levantar SwiftData.

**`ContentView.swift` y su «Hello, Glucy!» se quedan como están.** La primera pantalla de
verdad es el paso 3.

---

## 8. Las pruebas que tienen que pasar

Todas con el contenedor **en memoria**. Ninguna toca el disco ni depende del orden en que
corran.

| # | Qué comprueba | Por qué |
| --- | --- | --- |
| 1 | El contenedor se crea en memoria con las diez tablas | Una tabla que falta no falla al arrancar, falla lejos |
| 2 | Se guarda y se vuelve a leer una lectura, con su UUID y en `pendiente` | Es el criterio de «hecho» del plan |
| 3 | Lo mismo con una comida | — |
| 4 | Lo mismo con una dosis | — |
| 5 | Guardar dos veces el mismo UUID devuelve `false` y deja una sola fila | Idempotencia, RF-36c |
| 6 | Guardar una lectura la deja encolada, una sola vez | El acuerdo 2, y el caso P-07 |
| 7 | El perfil nace `local` y **no** aparece en la cola | Regla 3 |
| 8 | `ProductoCache` nace `local` y **no** aparece en la cola | Grupo C |
| 9 | `pendientes(limite:)` entrega lo más antiguo primero | O el backend recibe la serie desordenada |
| 10 | `ultima()` devuelve la de `tsUtc` mayor aunque se haya insertado antes | HealthKit entrega en bloques y con retraso (RF-06b) |
| 11 | `entre(desde:hasta:)` respeta los extremos y devuelve en orden | — |
| 12 | `recientes(horas:)` de comidas y dosis devuelve solo la ventana pedida | Es lo que van a consumir el COB y el IOB |
| 13 | `marcarError` guarda el motivo, sube `intentos` y **no** borra la fila | Un dato rechazado sin rastro es una falla invisible (RF-22) |
| 14 | Todo lo guardado conserva `zonaHoraria` además de `tsUtc` | Regla 5: UTC **y** zona, siempre las dos |
| 15 | Un `LecturaGlucosaDato` convertido a `@Model` y de vuelta da lo mismo | Si la conversión pierde un campo, se pierde en silencio |

---

## 9. Cómo se sabe que el paso 2 está hecho

1. `xcodebuild … -only-testing:GlucyTests test` en verde, con las del paso 1 **y** estas
   quince.
2. Se guarda y se lee una lectura, una comida y una dosis, cada una con su UUID y en estado
   `pendiente`, y una prueba lo verifica.
3. `grep -rn "import SwiftData" Glucy/Features/ Glucy/Domain/UseCases/` no devuelve nada:
   SwiftData no se asoma fuera de `Data/`.
4. Ningún protocolo de `Data/Repositories/` menciona un tipo `@Model`.
5. La app sigue compilando y abriendo en el simulador, aunque siga enseñando «Hello, Glucy!».

---

## 10. Lo que NO entra en el paso 2

Ninguna pantalla, ningún ViewModel, HealthKit, cámara, Open Food Facts, red, el
`ContentView` de verdad y el tema visual. La cola se crea y se llena; **no se vacía**,
porque no hay servidor hasta la fase 2. El paso 3 es la captura manual de glucosa, que es la
primera pantalla real.

---

## 11. Git

```bash
git switch develop
git pull origin develop
git switch -c feature/persistencia-local
# …trabajo…
git add .
git commit -m "feat: contenedor de SwiftData, repositorios y cola de sincronización"
git push -u origin feature/persistencia-local
```

Pull request **contra `develop`**, no contra `main`, y con los apartados de la plantilla
llenos: «Antes», «Después», «Cómo» y «Requisitos que cubre». No se fusiona con la
integración continua en rojo.

---

## 12. El texto para pegarle a Claude Code

> Lee `CLAUDE.md` y `docs/paso-2-persistencia-local.md`. Haz el paso 2 completo en una rama
> `feature/persistencia-local`: el esquema versionado y el contenedor de SwiftData, los cinco
> structs `Dato`, los cinco protocolos de repositorio con su implementación `@ModelActor`, el
> contenedor de dependencias y las quince pruebas. Lee antes el apartado 2 del documento: los
> repositorios intercambian structs `Sendable`, nunca objetos `@Model`, porque el target
> compila con concurrencia estricta y en el paso 4 HealthKit va a escribir en segundo plano.
> No crees ninguna pantalla ni toques `ContentView`. Corre las pruebas antes de decirme que
> terminaste. Los requisitos que cubre este paso son RF-20, RF-36b y RF-36c del lado de la
> app, y están pegados completos en el apartado 1 bis del documento: cada prueba tiene que
> poder rastrearse a uno de los tres.
