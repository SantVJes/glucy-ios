# Paso 4 — HealthKit, lectura y escritura

Instrucciones concretas para el cuarto paso de la fase 1. Están escritas para pegárselas a
Claude Code corriendo en la MacBook, dentro de esta misma carpeta, pero se leen igual de bien
a mano.

Contexto general: `CLAUDE.md` en la raíz. Plan completo de la fase:
`glucy-base/04-PLAN-FASE-1.md`. Los pasos anteriores: `docs/paso-1-dominio-y-reglas.md`,
`docs/paso-2-persistencia-local.md` y `docs/paso-3-captura-manual.md`, los tres terminados y
fusionados.

> **Este es el paso más delicado de la fase 1.** No porque el código sea difícil, sino porque
> tres de sus errores no se ven al escribirlo: se ven días después, con la serie duplicada, la
> app callada o la predicción hecha con datos de hace dos horas. Los tres están escritos abajo
> con nombre y apellido.

---

## 0. Antes de abrir Claude Code

### 0.1 La rama, antes que nada

Primero la rama, y después todo lo demás. Si se hace al revés, el commit de la capacidad de
HealthKit cae en la rama en la que estabas, que normalmente es `main`, y hay que moverlo
después.

```bash
cd ~/Documents/glucy-ios
git fetch origin
git switch -c feature/healthkit origin/develop
git branch --show-current     # tiene que decir: feature/healthkit
```

La rama sale de `develop`, nunca de `main`, y el pull request también va contra `develop`.

---

### 0.2 Lo que solo puedes hacer tú, en Xcode

Como cuando creaste el proyecto: esto **no lo puede hacer Claude Code**, porque son casillas
de la interfaz de Xcode y archivos de firma. Son cinco minutos.

1. Abre `Glucy.xcodeproj`. Selecciona el **proyecto** (el renglón de hasta arriba), luego el
   **target `Glucy`**, pestaña **Signing & Capabilities**.
2. Toca **+ Capability** y agrega **HealthKit**.
3. Debajo de HealthKit aparecen dos casillas. Marca **Background Delivery**. La otra,
   *Clinical Health Records*, se queda sin marcar: no se usa.
4. En la pestaña **Info** del mismo target, agrega estas dos claves con este texto exacto:

   | Clave | Valor |
   | --- | --- |
   | `NSHealthShareUsageDescription` | Glucy lee tu glucosa de Salud para mostrarte tu curva y anticipar bajadas. Nada de esto sale de tu teléfono. |
   | `NSHealthUpdateUsageDescription` | Glucy guarda en Salud lo que tú registras: glucosa, carbohidratos e insulina. |

   **Si falta cualquiera de las dos, la app se cierra sola** en el instante en que pide el
   permiso, sin mensaje de error útil. Es la causa número uno de «no entiendo por qué se
   cierra».
5. **Comprueba que la capacidad quedó en las dos configuraciones, no solo en Debug.** Xcode
   a veces crea el archivo de permisos como `GlucyDebug.entitlements` y lo engancha solo a
   Debug; entonces la app firmada para Release se queda sin HealthKit. Es el mismo error que
   con el iOS mínimo en el paso 0: un ajuste puesto con un solo renglón seleccionado.

   ```bash
   grep -c "CODE_SIGN_ENTITLEMENTS" Glucy.xcodeproj/project.pbxproj   # tiene que dar 2
   ```

   Si da 1, en Xcode: target `Glucy` → **Build Settings** → busca *Code Signing Entitlements*
   → pon el mismo archivo en **Debug** y en **Release**.

6. Sube el cambio a la rama que ya creaste en 0.1:

   ```bash
   git add .
   git commit -m "chore: capacidad de HealthKit con entrega en segundo plano"
   git push -u origin feature/healthkit
   ```

**Si Xcode se queja de la firma** al agregar la capacidad, es tu cuenta de desarrollador
gratuita. HealthKit y la entrega en segundo plano sí funcionan con ella para desarrollo; si
aparece un error de *provisioning profile*, avísame y lo vemos.

### 0.3 El iPhone físico, que esta vez sí hace falta

**El simulador no sirve para este paso.** Ni la entrega en segundo plano, ni el observador,
ni la app de Salud con datos de verdad. Hay que probar en tu iPhone 17, conectado, y con
algún dato de glucosa escrito a mano en la app **Salud** para tener qué leer.

Cómo meter datos de prueba sin sensor: abre **Salud** → Explorar → Nutrición → Glucosa en
sangre → **Agregar datos**, y mete tres o cuatro valores con horas distintas. Esos los va a
ver Glucy como si fueran de un fabricante, porque el `HKSource` es la app Salud y no Glucy.

---

## 1. Qué se construye en el paso 4, y por qué va ahora

Hasta hoy Glucy solo sabe lo que la persona teclea. Al terminar este paso:

- lee la glucosa que la app del sensor comercial (Dexcom, FreeStyle Libre) ya escribió en
  Salud, **también con la app cerrada**;
- escribe en Salud lo que Glucy capturó, y **solo eso**;
- sabe en qué modo tiene derecho a estar, y degrada a **modo sin sensor** cuando la última
  lectura pasa de quince minutos.

Va ahora porque es lo que convierte la app en el producto de la promesa. Y va **después** de
los tres pasos anteriores a propósito: la regla de frescura ya está escrita y probada desde el
paso 1 (`DecisionModo`), y la base donde guardar ya existe desde el paso 2. Aquí solo se
conecta la tubería.

Requisitos que cubre: **RF-06**, **RF-06b**, **RF-06c**, **RF-07**, **RF-15** y **RF-15b**.

---

## 1 bis. Los seis requisitos, pegados

Copiados literalmente del Documento 2 v6.

### RF-06 (fase 1)

> La app solicita permiso de lectura de HealthKit sobre `HKQuantityTypeIdentifier.bloodGlucose`
> y toma de ahí las lecturas que escribió la app del sensor comercial (Dexcom, FreeStyle
> Libre). Usa `HKObserverQuery` con `enableBackgroundDelivery` para recibir las muestras nuevas
> sin que la app esté abierta. El onboarding permite saltarse este paso: tener sensor es
> opcional. **Ya no hay emparejamiento Bluetooth: los protocolos BLE de esos sensores son
> cerrados y no están documentados.**

**Qué lo cumple aquí:** `ServicioHealthKit` con su observador y su consulta ancorada. Lo de
«el onboarding permite saltárselo» es del paso 9; lo que se garantiza hoy es que **nada se
cae ni se bloquea si el permiso no está**.

### RF-06b (fase 1)

> La app tolera huecos en la serie por diseño. HealthKit entrega lo que la app del fabricante
> haya escrito, cuando lo haya escrito: pueden llegar bloques de muestras juntas y con
> retraso. La app no supone una serie regular de 5 minutos y no rellena por su cuenta lo que
> no llegó.

**Qué lo cumple aquí:** la consulta trae lo que haya y se guarda tal cual. **Ni un bucle que
recorra cada cinco minutos, ni una interpolación.** La única interpolación permitida en todo
el proyecto es la del backend, sobre huecos de hasta 15 min, y esa es de la fase 2.

### RF-06c (fase 1, la regla; la pantalla es del paso 8)

> La pantalla de inicio muestra siempre la antigüedad de la última lectura real. Si supera el
> umbral de frescura definido para el modo sensor, la app degrada de forma explícita al modo
> sin sensor en lugar de seguir prediciendo con datos viejos, y lo dice en pantalla.

**Qué lo cumple aquí:** `DecisionModo.modoActual`, del paso 1, ya decide. Este paso le da los
dos datos que necesita y expone el modo y la antigüedad para que el paso 8 los dibuje.

### RF-07 (fase 1)

> El usuario puede cambiar de modo en cualquier momento: si activa la lectura de HealthKit
> después de meses de captura manual, el histórico previo se conserva y se integra. También
> puede revocar el permiso desde Salud sin que la app deje de funcionar; simplemente vuelve al
> modo sin sensor.

**Qué lo cumple aquí:** nada se borra al conectar el sensor, y revocar el permiso no lanza
ninguna excepción hacia arriba: se traduce a modo sin sensor. Es el caso **P-09**.

### RF-15 (fase 1)

> La glucosa se escribe en HealthKit como `HKQuantityTypeIdentifier.bloodGlucose`, no en una
> tabla propia paralela.

**Qué lo cumple aquí:** la escritura. Y ojo con la palabra «paralela»: SwiftData **sí** guarda
la lectura, porque guarda lo que HealthKit no puede guardar (el origen, la confirmación del
OCR, el estado de sincronización). Lo que no se hace es tener la glucosa **solo** en SwiftData.

### RF-15b (fase 1)

> La app escribe en HealthKit solo las lecturas que ella misma capturó (manual y foto). Las
> que leyó del sensor comercial no se vuelven a escribir, para no duplicarlas. Al leer, la app
> distingue por `HKSource` cuáles escribió ella y cuáles vinieron del fabricante.

**Qué lo cumple aquí:** la trampa número uno de abajo. Es el caso **P-14**.

---

## 2. Las cuatro decisiones del paso 4

### 2.1 Todo detrás de un protocolo, o la integración continua se cae

HealthKit **no se puede probar en GitHub**: no hay dispositivo, no hay app Salud y no hay
permisos. Si el código de HealthKit se llama directo desde un caso de uso, las pruebas de
`GlucyTests` dejan de poder correr en el runner y se pierde la red de seguridad de los tres
pasos anteriores.

Por eso:

```
ServicioHealthKit (protocolo, en Data/HealthKit/)
   ├── HealthKitReal        ← la implementación, la única que importa HealthKit
   └── HealthKitFalso       ← en GlucyTests, sin importar HealthKit
```

**Ningún archivo fuera de `Data/HealthKit/` importa HealthKit.** Ni los casos de uso, ni las
vistas, ni las pruebas. Se comprueba con un `grep` en el apartado 12.

### 2.2 iOS no te dice si tienes permiso de lectura, y eso cambia el diseño

Esta es la que sorprende. `authorizationStatus(for:)` sirve para la **escritura**. Para la
**lectura**, iOS devuelve siempre `.notDetermined` aunque el permiso esté concedido, **a
propósito**: si te dijera «el usuario no te deja leer glucosa», eso ya sería un dato de salud.

Consecuencia directa: **no se puede preguntar «¿tengo permiso de leer?».** Hay que intentar
leer y ver qué pasa. Así que el `lecturaHealthKitActiva` que pide `DecisionModo` **no** se
calcula con un estado de autorización, sino con la realidad:

> `lecturaHealthKitActiva` es verdadero cuando la última consulta trajo al menos una muestra
> de origen sensor. Si la consulta no devuelve nada, da igual por qué: el modo es sin sensor.

Esto resuelve gratis el caso **P-09**: cuando la persona revoca el permiso desde Salud, la
consulta deja de traer muestras, y la app degrada por el mismo camino por el que degradaría si
el sensor se cayera. No hay que detectar la revocación; no hay nada que detectar.

### 2.3 El observador avisa, la consulta ancorada trae

`HKObserverQuery` **no entrega muestras**. Solo dice «algo cambió en glucosa». Quien trae los
datos es `HKAnchoredObjectQuery`, con un **ancla** que se guarda entre arranques para pedir
solo lo nuevo.

```
HKObserverQuery  →  «cambió algo»  →  HKAnchoredObjectQuery(ancla guardada)  →  muestras nuevas
                                                    ↓
                                         se guarda la ancla nueva
```

El ancla se guarda en **`UserDefaults`**, serializada, y esto **sí** está permitido: la regla
del proyecto dice que ninguna llave ni token va a `UserDefaults`, y un ancla de sincronización
no es ni una cosa ni la otra. Si se pierde, la siguiente consulta trae todo otra vez, y la
idempotencia del paso 2 evita los duplicados.

### 2.4 Hay que llamar al `completionHandler` del observador

Cuando iOS despierta la app en segundo plano por una muestra nueva, el bloque del observador
recibe un `completionHandler`. **Si no se llama, iOS deja de despertar la app.** No avisa, no
lanza error: simplemente la entrega en segundo plano se apaga y días después nadie entiende por
qué la app ya no se actualiza sola.

Se llama **siempre**, incluso cuando la consulta falló. Es un `defer` o un `Task` que termina
en llamarlo pase lo que pase.

---

## 3. Archivos que hay que crear

```
Glucy/
  Data/
    HealthKit/
      ServicioHealthKit.swift        ← el protocolo y sus tipos
      HealthKitReal.swift            ← la única implementación que importa HealthKit
      AnclaHealthKit.swift           ← guardar y leer el ancla
      ErrorHealthKit.swift
  Domain/
    UseCases/
      SincronizarLecturasDelSensor.swift   ← trae de HealthKit y guarda en el repositorio
      EscribirEnHealthKit.swift            ← sube lo que Glucy capturó
      ConsultarModo.swift                  ← junta frescura + actividad y devuelve el modo

GlucyTests/
  Dobles/
    HealthKitFalso.swift
  SincronizarLecturasDelSensorTests.swift
  EscribirEnHealthKitTests.swift
  ConsultarModoTests.swift
```

Y dos que se tocan: `GlucyApp.swift`, para registrar el observador al arrancar, y
`ContenedorDependencias.swift`, para inyectar el servicio.

---

## 4. El protocolo, con su firma exacta

```swift
// Data/HealthKit/ServicioHealthKit.swift

/// Una muestra de glucosa como la entrega HealthKit, ya convertida a mg/dL.
nonisolated struct MuestraGlucosa: Sendable, Equatable {
    let uuid: UUID              // el de HealthKit, que es estable entre consultas
    let mgDl: Double
    let ts: Date
    let contexto: ContextoComida?
    /// `true` si la escribió Glucy. Las propias **no** se vuelven a guardar ni a escribir.
    let esPropia: Bool
}

nonisolated protocol ServicioHealthKit: Sendable {
    /// `false` en el simulador y en cualquier dispositivo sin Salud. No es un error.
    var disponible: Bool { get }

    /// Pide los permisos por tipo y por separado. No devuelve si los dieron: para lectura
    /// iOS no lo dice (ver 2.2).
    func pedirPermisos() async throws

    /// Trae lo nuevo desde la última vez. Devuelve también el ancla para guardarla.
    func muestrasNuevas() async throws -> [MuestraGlucosa]

    /// Registra el observador y enciende la entrega en segundo plano.
    func observarGlucosa(alLlegarMuestras: @escaping @Sendable () async -> Void) async throws

    /// Escribe una lectura que **Glucy** capturó. Nunca una de origen sensor (RF-15b).
    func escribirGlucosa(_ dato: LecturaGlucosaDato) async throws
    func escribirCarbohidratos(gramos: Double, ts: Date) async throws
    func escribirInsulina(unidades: Double, ts: Date, motivo: MotivoDosis) async throws

    /// La unidad que la persona eligió en Salud. Solo para avisarle si no es mg/dL.
    func unidadPreferida() async throws -> String
}
```

Las firmas del SDK de HealthKit **cambian entre versiones y algunas siguen siendo de
callback, no `async`**. Si el compilador contradice algo de aquí, manda el compilador; lo que
no se negocia es que el protocolo se vea así desde fuera.

---

## 5. Las tres trampas, con nombre y apellido

Están en `CLAUDE.md` y en el plan. Aquí van con el código que las evita.

### Trampa 1 — Reescribir en HealthKit lo que se leyó del sensor (RF-15b, P-14)

**Qué pasa si se comete:** Glucy lee las muestras del Dexcom y las guarda. Luego, al
sincronizar, escribe «sus» lecturas en Salud, y entre ellas van las del Dexcom. Al siguiente
arranque las lee otra vez, ahora también las suyas, y las vuelve a escribir. **La serie se
duplica cada arranque**, y en una semana el histórico de la persona es basura.

**Cómo se evita:** al leer, se marca cada muestra con `esPropia` comparando su fuente contra
la de la app:

```swift
let propia = muestra.sourceRevision.source == HKSource.default()
```

Y al escribir, **una sola condición, en un solo lugar**:

```swift
// Solo se escribe lo que Glucy capturó. Una lectura de origen sensor ya está en Salud:
// volver a escribirla duplica la serie en cada arranque (RF-15b, caso P-14).
guard dato.origen != .sensor, dato.origen != .healthkit else { return }
```

### Trampa 2 — Suponer una serie regular de cinco minutos (RF-06b)

**Qué pasa si se comete:** el código asume una muestra cada cinco minutos y rellena los
huecos. Esos valores inventados entran al histórico, al cálculo del tiempo en rango y, en la
fase 2, al entrenamiento del modelo. Nadie los distingue de los reales.

**Cómo se evita:** se guarda lo que llegó y nada más. Sin bucle de cinco minutos, sin
`while ts < ahora`, sin promedio entre dos muestras. Si hay un hueco de dos horas, hay un
hueco de dos horas, y la pantalla lo dice cuando llegue el paso 8.

### Trampa 3 — Caerse cuando la persona revoca el permiso (RF-07, P-09)

**Qué pasa si se comete:** alguien quita el permiso desde Salud, la consulta lanza, nadie la
atrapa y la app se cierra. En una app de salud eso es peor que no tener la función.

**Cómo se evita:** el caso de uso **nunca deja salir un error de HealthKit hacia la
interfaz**. Todo fallo de lectura se traduce a lo mismo: cero muestras nuevas, y por lo tanto
modo sin sensor.

```swift
// Un fallo de HealthKit no es una excepción que la pantalla deba mostrar: es la
// condición normal «no hay sensor». Revocar el permiso desde Salud llega por aquí
// (RF-07, caso P-09), igual que un sensor apagado o un teléfono sin Salud.
let muestras = (try? await servicio.muestrasNuevas()) ?? []
```

---

## 6. Unidades y metadatos

- **Internamente todo es mg/dL**, sin excepción. Lo dice `CLAUDE.md` y lo asumen las reglas
  del paso 1.
- Al leer se pide la unidad con `preferredUnits(for:)`. Si la persona eligió **mmol/L** en
  Salud, la conversión se hace **al entrar** y se le avisa una vez en la pantalla; no se
  guarda nada en mmol/L. El factor es `mg/dL = mmol/L × 18.0182`.
- La unidad de mg/dL en HealthKit se arma así:
  `HKUnit.gramUnit(with: .milli).unitDivided(by: .literUnit(with: .deci))`.
- Carbohidratos en `HKUnit.gram()`; insulina en `HKUnit.internationalUnit()`.
- Metadatos al escribir: `HKMetadataKeyBloodGlucoseMealTime` con el contexto **cuando lo
  hay** (recuerda que es opcional), y `HKMetadataKeyInsulinDeliveryReason` con
  `HKInsulinDeliveryReason.bolus` o `.basal` según `MotivoDosis`.
- **No se guardan lecturas de solución de control.** HealthKit las marca; se descartan al
  leer.

---

## 7. Cómo queda la decisión de modo

`DecisionModo.modoActual` ya existe y ya está probado. Este paso solo lo alimenta:

```swift
// Domain/UseCases/ConsultarModo.swift

nonisolated struct ConsultarModo: Sendable {
    let lecturas: any RepositorioLecturas

    /// `lecturaHealthKitActiva` no es un estado de autorización: es «la última muestra de
    /// origen sensor existe». iOS no dice si hay permiso de lectura (ver 2.2), así que la
    /// única señal honesta es si hay datos.
    func ejecutar(ahora: Date = Date()) async throws -> (modo: ModoApp, antiguedadMin: Double?)
}
```

Y la regla que no se toca: en modo sin sensor, `DecisionModo.puedeAlertarHipoglucemia`
devuelve `false`, y la app **lo declara en pantalla** (RF-10b). El aviso visible es del paso 8;
la regla ya está.

---

## 8. Las pruebas que tienen que pasar

### En `GlucyTests`, con el doble, sin dispositivo ni HealthKit

| # | Qué comprueba | Por qué |
| --- | --- | --- |
| 1 | Una muestra de origen sensor se guarda con `origen: .sensor` | RF-06 |
| 2 | Una muestra marcada `esPropia` **no** se guarda otra vez | RF-15b, evita duplicar |
| 3 | La misma muestra dos veces deja una sola fila | Idempotencia del paso 2 |
| 4 | Con muestras espaciadas 40 min, se guardan **dos** filas, no nueve | **RF-06b**: no se rellena |
| 5 | Si el servicio lanza, el caso de uso devuelve cero muestras y **no** propaga el error | **P-09** |
| 6 | Si el servicio lanza, el modo resultante es `sinSensor` | RF-07 |
| 7 | Una lectura `origen: .manual` sí se escribe en HealthKit | RF-15 |
| 8 | Una lectura `origen: .sensor` **no** se escribe en HealthKit | **RF-15b**, caso **P-14** |
| 9 | Una lectura `origen: .fotoGlucometro` sí se escribe | RF-15 |
| 10 | Con la última muestra de hace 5 min el modo es `sensor` | RF-06c |
| 11 | Con la última muestra de hace 20 min el modo es `sinSensor` | **P-03**, D-13 a 15 min |
| 12 | Sin ninguna muestra, el modo es `sinSensor` y la antigüedad es `nil` | No se inventa un cero |
| 13 | En modo sin sensor, `puedeAlertarHipoglucemia` es `false` | **P-04**, RF-10b |
| 14 | Una muestra en mmol/L entra convertida a mg/dL | Todo en mg/dL |
| 15 | El ancla se guarda y la siguiente consulta la reutiliza | No se retrae todo cada vez |

### En el iPhone físico, a mano y anotando el resultado

Esto no lo puede correr la integración continua. Son cuatro comprobaciones y hay que dejar
escrito que se hicieron, porque son entregable del reporte:

1. **Llega una muestra con la app cerrada.** Mete un valor en Salud con Glucy cerrada del
   todo, ábrela y comprueba que ya estaba guardada.
2. **Se distingue lo propio de lo del fabricante.** Registra una lectura a mano en Glucy y
   otra en Salud. Las dos aparecen; solo la de Glucy figura en Salud con Glucy como fuente.
3. **No se duplica.** Cierra y abre la app tres veces. El número de lecturas no cambia.
4. **Revocar no tumba la app.** Salud → Compartir → Apps → Glucy → apaga la glucosa. Vuelve a
   Glucy: sigue abriendo, y el modo es sin sensor.

---

## 9. Cómo se sabe que el paso 4 está hecho

1. `xcodebuild … -only-testing:GlucyTests test` en verde con las 62 de los pasos anteriores
   **y** estas quince.
2. `grep -rn "import HealthKit" Glucy/ | grep -v "Glucy/Data/HealthKit/"` no devuelve nada.
3. `grep -rn "import HealthKit" GlucyTests/` no devuelve nada.
4. Las cuatro comprobaciones del iPhone hechas y anotadas en el pull request.
5. No hay ningún `while` ni bucle que recorra el tiempo de cinco en cinco minutos.
6. La palabra `interpolar` no aparece en `Glucy/`.

---

## 10. Lo que NO entra en el paso 4

La pantalla de inicio y la antigüedad dibujada (paso 8), el aviso fijo de modo sin sensor
(paso 8), la foto del glucómetro (paso 5), las comidas (paso 6), la insulina (paso 7), el
onboarding que permite saltarse el sensor (paso 9), las notificaciones y la alerta de
hipoglucemia (fase 3), y cualquier predicción.

Tampoco entra leer pasos, sueño ni frecuencia cardiaca: son contexto opcional y se verán en la
fase 2.

---

## 11. Git

```bash
git switch develop
git pull origin develop
git switch -c feature/healthkit
# …trabajo…
git add .
git commit -m "feat: lectura y escritura de glucosa en HealthKit con entrega en segundo plano"
git push -u origin feature/healthkit

gh pr create --base develop --head feature/healthkit --web
```

**Los mensajes de commit van en español**, con Conventional Commits. En el paso 3 se colaron
un «fix: the saved teclade numeric»; no pasa nada grave, pero el idioma es regla del proyecto
y el historial es entregable.

No se fusiona con la integración continua en rojo, y hay que **esperar a que termine**.

---

## 11 bis. El cuerpo del pull request, ya escrito

```markdown
## Antes

Glucy solo sabía lo que la persona teclea. Si alguien traía un Dexcom o un FreeStyle Libre
puesto, la app lo ignoraba: había que volver a escribir a mano un número que el sensor ya
había medido. Y lo que Glucy registraba se quedaba solo en la app, sin aparecer en Salud.

## Después

Glucy lee la glucosa que la app del sensor escribió en Salud, también con Glucy cerrada, y
guarda cada muestra con `origen: sensor`. Escribe en Salud las lecturas que ella misma
capturó —las de a mano y, cuando llegue el paso 5, las de la foto— y **no** vuelve a escribir
las del sensor, así que la serie no se duplica.

La app sabe además en qué modo tiene derecho a estar: si la última muestra del sensor tiene
más de quince minutos, o si no hay ninguna, el modo es «sin sensor». Quitar el permiso desde
Salud no cierra la app ni muestra un error: simplemente se queda sin sensor, que es una
condición normal y no una falla.

## Cómo

Todo HealthKit vive detrás del protocolo `ServicioHealthKit`, en `Data/HealthKit/`, con una
implementación real y un doble para las pruebas. Así las pruebas de dominio siguen corriendo
en la integración continua, que no tiene dispositivo ni app Salud.

Dos detalles que decidieron el diseño. iOS no dice si hay permiso de **lectura** —devuelve
`notDetermined` aunque esté concedido, porque decirlo ya sería un dato de salud—, así que el
modo no se calcula con un estado de autorización sino con la realidad: si la consulta no trae
muestras, el modo es sin sensor, y eso cubre la revocación sin tener que detectarla. Y el
observador solo avisa de que algo cambió; quien trae los datos es una consulta ancorada cuyo
ancla se guarda entre arranques, con la llamada al `completionHandler` garantizada, porque si
no se llama iOS apaga la entrega en segundo plano sin avisar.

## Requisitos que cubre

- **RF-06** — lectura de `bloodGlucose` desde Salud con observador y entrega en segundo plano.
- **RF-06b** — se guarda lo que llegó; no se supone serie de cinco minutos ni se rellena.
- **RF-06c** — la regla de frescura a quince minutos degrada a modo sin sensor.
- **RF-07** — revocar el permiso no tumba la app; el histórico previo se conserva.
- **RF-15** — la glucosa se escribe en Salud, no solo en una tabla propia.
- **RF-15b** — solo se escribe lo que Glucy capturó; se distingue por `HKSource`.
- **P-03** — una lectura vieja degrada y lo dice.
- **P-09** — revocar HealthKit no tumba la app.
- **P-14** — no se reescribe en HealthKit lo del sensor.

## Comprobado

- [x] Las pruebas pasan en local (<número> en total)
- [x] La integración continua está en verde
- [x] No se agregó ninguna llave, token ni dato personal al repositorio

Comprobado además en el iPhone físico, que es lo que la integración continua no puede correr:

- [x] Llega una muestra nueva con la app cerrada
- [x] Se distingue por `HKSource` lo que escribió Glucy de lo que escribió la app Salud
- [x] Abrir y cerrar la app tres veces no duplica ninguna lectura
- [x] Revocar el permiso desde Salud no cierra la app y deja el modo en «sin sensor»
```

---

## 12. El texto para pegarle a Claude Code

> Lee `CLAUDE.md` y `docs/paso-4-healthkit.md`. Haz el paso 4 completo en una rama
> `feature/healthkit`: el protocolo `ServicioHealthKit` con su implementación real y su doble,
> el ancla, los tres casos de uso y las quince pruebas. La capacidad de HealthKit y las dos
> claves del Info.plist ya están puestas en el proyecto; si no las encuentras, dímelo y no las
> agregues tú.
>
> Lee con cuidado los apartados 2 y 5 antes de escribir código. Tres cosas no se negocian:
> **ningún archivo fuera de `Data/HealthKit/` importa HealthKit**, ni las pruebas, porque la
> integración continua no tiene dispositivo; **una lectura de origen sensor nunca se vuelve a
> escribir en HealthKit**, que es el caso P-14 y duplicaría la serie en cada arranque; y **un
> fallo de HealthKit nunca sube a la interfaz**, se traduce a cero muestras y modo sin sensor,
> que es el caso P-09.
>
> No supongas una serie de cinco minutos ni rellenes huecos: se guarda lo que llegó. No crees
> ninguna pantalla; la antigüedad y el aviso de modo sin sensor son del paso 8. La rama sale de
> `develop` y el pull request va contra `develop`, con el cuerpo del apartado 11 bis. Corre las
> pruebas antes de decirme que terminaste y dime cuántas pasaron.
