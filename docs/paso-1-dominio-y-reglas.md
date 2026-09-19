# Paso 1 — Dominio y reglas, con sus pruebas

Instrucciones concretas para el primer paso de la fase 1. Están escritas para pegárselas a
Claude Code corriendo en la MacBook, dentro de esta misma carpeta, pero se leen igual de bien
a mano.

Contexto general: `CLAUDE.md` en la raíz. Plan completo de la fase: `glucy-base/04-PLAN-FASE-1.md`
en los archivos del proyecto. Especificación ejecutable de las reglas:
`referencia/reglas_clinicas.py` del repositorio **glucy-backend**.

---

## 0. Antes de nada: crear el proyecto en Xcode

Esto **no** lo puede hacer Claude, hay que hacerlo a mano una sola vez.

1. Xcode → *File · New · Project* → **iOS · App**.
2. Product Name: `Glucy` · Interface: **SwiftUI** · Language: **Swift** · Storage: **None**
   (SwiftData se configura a mano, el asistente lo mete mal) · Testing System: **Swift Testing**
   con XCTest de respaldo · Include Tests: **sí**.
3. Guardarlo **en la raíz de este repositorio**, de modo que quede `Glucy.xcodeproj` al lado
   de `CLAUDE.md`. Desmarcar «Create Git repository»: ya existe.
4. En *Build Settings* del target:
   - `IPHONEOS_DEPLOYMENT_TARGET` = **17.0**
   - `SWIFT_VERSION` = **6.0**
   - `SWIFT_STRICT_CONCURRENCY` = **complete**
5. En *Signing & Capabilities* todavía **no** se agrega nada. HealthKit, cámara, Face ID y
   notificaciones entran en los pasos 4, 5 y 9, no ahora.
6. Renombrar los dos targets de prueba a `GlucyAppTests` y `GlucyAppUITests`.
7. `git add . && git commit && git push`. En cuanto `Glucy.xcodeproj` exista, la integración
   continua deja de saltarse la compilación y empieza a compilar de verdad.

**Cómo se sabe que esto está hecho:** `xcodebuild -scheme Glucy -destination 'platform=iOS
Simulator,name=iPhone 17' build` termina en `BUILD SUCCEEDED`.

---

## 1. Qué se construye en el paso 1, y por qué va primero

Los enums, los modelos de SwiftData y **`Domain/Rules`**: validación, carbohidratos activos,
insulina activa, indicadores, decisión de modo y decisión de sincronizar.

Van primero porque son las reglas donde un error tiene consecuencia clínica, viven sin
interfaz y se prueban en segundos. Si se escriben después de las pantallas terminan repartidas
dentro de las vistas y ya no se pueden probar. **En este paso no se dibuja ni una sola vista.**

---

## 2. Archivos que hay que crear

```
GlucyApp/
  Domain/
    Enums/
      Origen.swift
      ContextoComida.swift
      TipoUsuario.swift
      TipoInsulina.swift          // incluye MotivoDosis
      SyncEstado.swift
      ModoApp.swift
      ClaseEvento.swift
    Models/
      Perfil.swift
      LecturaGlucosa.swift
      Comida.swift
      DosisInsulina.swift
      EventoContexto.swift
      Alerta.swift
      PrediccionCache.swift
      ProductoCache.swift
      ColaSincronizacion.swift
      ColaXapi.swift
    Rules/
      ConfiguracionDominio.swift   // TODAS las constantes, en un solo lugar
      Validacion.swift
      Carbohidratos.swift          // COB
      Insulina.swift               // IOB
      Indicadores.swift            // TIR, TBR, TAR, promedio, CV, GMI
      DecisionModo.swift
      DecisionSincronizacion.swift
GlucyAppTests/
  ValidacionTests.swift
  CarbohidratosTests.swift
  InsulinaTests.swift
  IndicadoresTests.swift
  DecisionModoTests.swift
  DecisionSincronizacionTests.swift
```

Nada de `Features/`, nada de `Data/`, nada de `App/` todavía.

---

## 3. Los enums, tal cual

```swift
enum Origen: String, Codable, CaseIterable {
    case sensor, manual, fotoGlucometro, barcode, ocrEtiqueta, healthkit
}

enum ContextoComida: String, Codable, CaseIterable {
    case enAyunas, antesDeComer, dosHorasDespues, antesDeDormir, otro
}

enum TipoUsuario: String, Codable, CaseIterable {
    case tipo1, tipo2Insulinodependiente, prediabetes, resistenciaInsulina
}

enum TipoInsulina: String, Codable, CaseIterable { case bolo, basal }

enum MotivoDosis: String, Codable, CaseIterable { case comida, correccion, programada }

enum SyncEstado: String, Codable, CaseIterable {
    case local, pendiente, enviado, confirmado, error
}

enum ModoApp: String, Codable, CaseIterable { case sensor, sinSensor }

enum ClaseEvento: String, Codable, CaseIterable { case ejercicio, sueno, estres, enfermedad }
```

El `rawValue` que viaja al backend es el del Documento 3 en snake_case
(`foto_glucometro`, `ocr_etiqueta`, `antes_de_comer`, `tipo2_insulinodependiente`, `sin_sensor`).
Se resuelve con un `rawValue` explícito en cada caso, no cambiando el nombre del caso en Swift.

---

## 4. Las diez tablas

Los campos están campo por campo en `glucy-base/01-glucy-ios.md` §3 y salen del Documento 3.
Tres reglas que aplican a **todas**:

1. **`uuid: UUID` lo genera el teléfono**, nunca la base ni el servidor.
2. Toda marca de tiempo va como **`tsUtc: Date` más `zonaHoraria: String`** (identificador de
   `TimeZone`, por ejemplo `America/Mexico_City`). Las dos cosas, siempre.
3. Todo registro que viaja lleva **`syncEstado: SyncEstado`**, que nace en `.pendiente`.
   `ColaSincronizacion` se crea desde ya aunque no haya servidor hasta la fase 2: los cuatro
   acuerdos que permiten conectar un backend meses después hay que tomarlos desde el primer día.

Los campos marcados como «no sube» en la especificación (`nombre`, `apellidos`, `pesoKg`,
`nota`) se anotan con un comentario `/// No sube al backend (regla 3).` Es la única defensa
que va a quedar cuando en la fase 2 alguien escriba el serializador.

---

## 5. Las reglas, con su firma exacta

Los mismos números que `referencia/reglas_clinicas.py` de glucy-backend. Si el Swift y esa
referencia no coinciden, uno de los dos está mal.

### ConfiguracionDominio.swift

Todas las constantes juntas y **ninguna suelta en otro archivo**:

```swift
enum ConfiguracionDominio {
    // Glucosa
    static let glucosaMinima = 20.0          // mg/dL
    static let glucosaMaxima = 600.0
    static let umbralHipoPorOmision = 70.0   // rango configurable 50–90
    static let umbralHiperPorOmision = 180.0 // rango configurable 140–300
    static let rangoObjetivo = 70.0...180.0  // para el TIR

    // Carbohidratos
    static let absorcionPorOmisionMin = 180  // presets 30 y 300, rango 30–300
    static let carbsMaximos = 300.0          // g

    // Insulina
    static let duracionAccionPorOmisionH = 5.0   // rango 2–8
    static let picoInsulinaMin = 75.0
    static let insulinaMaxima = 50.0             // UI, resolución 0.5

    /// Pasados 15 minutos la lectura del sensor ya no sirve para predecir: se degrada a
    /// modo sin sensor en lugar de proyectar con datos viejos (RF-06c, D-13, caso P-03).
    static let frescuraSensorMin = 15.0

    /// Solo se interpolan huecos de hasta 15 min y solo en la serie continua (RF-23).
    /// Interpolar entre dos pinchazos separados por horas sería inventar datos.
    static let interpolacionMaximaMin = 15.0

    /// Una serie continua no puede cambiar más rápido que esto; por encima es artefacto
    /// del sensor, no fisiología.
    static let tasaCambioImposible = 4.0     // mg/dL por minuto

    // Perfil
    static let pesoMinimoKg = 25.0
    static let pesoMaximoKg = 300.0
    static let edadMinima = 15
}
```

### Validacion.swift

```swift
enum Rechazo: Equatable {
    case fueraDeRango(valor: Double)
    case marcaDeTiempoFutura
    case ocrSinConfirmar
    case duplicado(uuid: UUID)
}

enum Validacion {
    /// Devuelve nil si la lectura se puede guardar, o el motivo del rechazo.
    /// Un valor leído por OCR sin confirmar NO se guarda nunca, sin umbral de
    /// confianza (D-11, caso P-01).
    static func validarLectura(
        mgDl: Double,
        tsUtc: Date,
        ahora: Date,
        origen: Origen,
        confirmadaPorUsuario: Bool = true
    ) -> Rechazo?

    /// Solo tiene sentido sobre la serie continua del sensor: dos pinchazos separados por
    /// horas no forman una tasa de cambio.
    static func esAtipicaPorTasa(
        mgDlPrevio: Double, tsPrevio: Date,
        mgDl: Double, ts: Date,
        origen: Origen
    ) -> Bool

    static func sePuedeInterpolar(huecoMin: Double, origen: Origen) -> Bool
}
```

### Carbohidratos.swift

```swift
enum Carbohidratos {
    /// Absorción lineal, sin modelo fisiológico de digestión (D-8, RF-24b).
    /// COB(t) = carbs × (1 − t / absorción), y 0 cuando t ≥ absorción.
    /// Caso P-11: 60 g con 180 min, a los 90 min → 30 g exactos.
    static func cob(
        carbsG: Double,
        minutosDesdeComida: Double,
        tiempoAbsorcionMin: Int = ConfiguracionDominio.absorcionPorOmisionMin
    ) -> Double

    static func cobTotal(comidas: [(carbsG: Double, minutos: Double, absorcionMin: Int)]) -> Double
}
```

### Insulina.swift

```swift
enum Insulina {
    /// Fracción de la dosis que sigue activa. Curva exponencial, DIA 5 h y pico 75 min
    /// por omisión; el perfil puede cambiar la duración entre 2 y 8 h.
    static func fraccionActiva(
        minutos: Double,
        diaH: Double = ConfiguracionDominio.duracionAccionPorOmisionH,
        picoMin: Double = ConfiguracionDominio.picoInsulinaMin
    ) -> Double

    static func iob(
        dosis: [(unidades: Double, minutos: Double)],
        diaH: Double = ConfiguracionDominio.duracionAccionPorOmisionH,
        picoMin: Double = ConfiguracionDominio.picoInsulinaMin
    ) -> Double
}
```

La curva, idéntica a la referencia en Python:

```
diaMin = diaH * 60
tau    = picoMin * (1 - picoMin / diaMin) / (1 - 2 * picoMin / diaMin)
a      = 2 * tau / diaMin
s      = 1 / (1 - a + (1 + a) * exp(-diaMin / tau))
factor = minutos² / (tau * diaMin * (1 - a)) - minutos / tau - 1
restante = 1 - s * (1 - a) * (factor * exp(-minutos / tau) + 1)
```

Fuera del intervalo `0 ..< diaMin` la fracción es 1 antes de aplicar y 0 después de la DIA.

### Indicadores.swift

```swift
struct Indicadores: Equatable {
    let n: Int               // sobre cuántas lecturas se calculó; la pantalla lo dice
    let tir: Double          // % entre 70 y 180
    let tbr: Double          // % por debajo del umbral de hipoglucemia
    let tar: Double          // % por encima del umbral de hiperglucemia
    let promedio: Double
    let desviacion: Double
    let coeficienteVariacion: Double
    let gmi: Double          // 3.31 + 0.02392 × promedio
}

enum CalculoIndicadores {
    /// Devuelve nil con la lista vacía: la pantalla tiene que decir que faltan datos,
    /// no mostrar cero. Una cifra sobre cuatro lecturas engaña.
    static func calcular(
        valores: [Double],
        umbralHipo: Double = ConfiguracionDominio.umbralHipoPorOmision,
        umbralHiper: Double = ConfiguracionDominio.umbralHiperPorOmision
    ) -> Indicadores?
}
```

El TIR siempre se mide contra **70–180 fijos** aunque el perfil mueva sus umbrales: es la
definición del indicador y moverla haría incomparables los números con cualquier otra fuente.
Los umbrales del perfil solo mueven TBR y TAR.

La desviación es **poblacional** (se divide entre `n`, no entre `n − 1`), igual que en la
referencia, y el coeficiente de variación es `100 × desviación / promedio`.

### DecisionModo.swift

```swift
enum DecisionModo {
    /// sensor si HealthKit está activo y la última muestra de origen sensor tiene menos
    /// de 15 minutos; sinSensor en cualquier otro caso (RF-06c, caso P-03).
    static func modoActual(
        lecturaHealthKitActiva: Bool,
        tsUltimaSensor: Date?,
        ahora: Date,
        frescuraMin: Double = ConfiguracionDominio.frescuraSensorMin
    ) -> ModoApp

    /// En modo sin sensor la app NO puede anticipar hipoglucemias y tiene que decirlo
    /// (RF-10b, riesgo R-6, caso P-04).
    static func puedeAlertarHipoglucemia(modo: ModoApp) -> Bool
}
```

### DecisionSincronizacion.swift

```swift
enum DecisionSincronizacion {
    /// Solo con wifi, por lotes, lo más antiguo primero. Nunca con datos móviles salvo
    /// que la persona toque «sincronizar ahora» (caso P-08).
    static func debeSincronizar(
        hayWifi: Bool,
        pendientes: Int,
        forzadoPorUsuario: Bool = false
    ) -> Bool
}
```

---

## 6. Las pruebas que tienen que pasar

Nombradas por el caso del reporte, para que se vea la trazabilidad al correrlas.

| Prueba | Qué comprueba | Aserción concreta |
| --- | --- | --- |
| `P01_ocrSinConfirmarNoSeGuarda` | Un valor de OCR sin confirmar nunca se guarda, sin importar la confianza | `validarLectura(mgDl: 120, origen: .fotoGlucometro, confirmadaPorUsuario: false) == .ocrSinConfirmar` |
| `P02_valorFueraDeRangoNoSeGuarda` | 900 mg/dL se rechaza; 20 y 600 se aceptan | `validarLectura(mgDl: 900, …) == .fueraDeRango(valor: 900)` y `validarLectura(mgDl: 20, …) == nil` |
| `marcaDeTiempoFuturaSeRechaza` | No se acepta una lectura del futuro | `validarLectura(tsUtc: ahora + 60, ahora: ahora, …) == .marcaDeTiempoFutura` |
| `P03_lecturaViejaDegradaAModoSinSensor` | A los 16 minutos ya no es modo sensor | `modoActual(lecturaHealthKitActiva: true, tsUltimaSensor: ahora − 16 min, ahora: ahora) == .sinSensor`, y con 14 min `== .sensor` |
| `P04_sinSensorNoHayAlertaAnticipada` | La app no promete lo que no puede | `puedeAlertarHipoglucemia(modo: .sinSensor) == false` |
| `P08_noSincronizaConDatosMoviles` | Salvo botón manual | `debeSincronizar(hayWifi: false, pendientes: 12) == false` y `debeSincronizar(hayWifi: false, pendientes: 12, forzadoPorUsuario: true) == true` |
| `P11_cob60g180minALos90min` | El caso que más se cita del proyecto | `cob(carbsG: 60, minutosDesdeComida: 90, tiempoAbsorcionMin: 180) == 30` |
| `cobSeAgotaYNoSeVuelveNegativo` | Pasada la absorción es cero, nunca negativo | `cob(carbsG: 60, minutosDesdeComida: 200) == 0` |
| `iobDecreceYSeAgotaEnLaDIA` | Monótona decreciente y cero al final | `fraccionActiva(minutos: 0) == 1`, `fraccionActiva(minutos: 300) == 0`, y con DIA 8 h queda más insulina a los 120 min que con DIA 5 h |
| `tasaDeCambioSoloAplicaASerieContinua` | Dos pinchazos no forman una tasa | `esAtipicaPorTasa(…, origen: .manual) == false` aunque el salto sea enorme |
| `interpolacionSoloHasta15MinYSoloEnSensor` | RF-23 | `sePuedeInterpolar(huecoMin: 20, origen: .sensor) == false`, `sePuedeInterpolar(huecoMin: 10, origen: .manual) == false` |
| `indicadoresConUmbralesMovidos` | Los umbrales del perfil mueven TBR y TAR, no el TIR | con `[80, 100, 160]` y umbrales 90/150, el TIR sigue siendo 100 % |
| `gmiUsaLaFormulaDelConsenso` | `3.31 + 0.02392 × promedio` | con promedio 154 el GMI sale ≈ 7.0 |
| `sinLecturasNoHayIndicadores` | Con la lista vacía la pantalla dice que faltan datos, no cero | `calcular(valores: []) == nil` |

Se corren así, y son segundos:

```bash
xcodebuild -scheme Glucy -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:GlucyAppTests test
```

---

## 7. Cómo se corresponde esto con los diagramas C4

Los diagramas ya están dibujados y **el código tiene que parecerse a ellos**, no al revés. Los
enlaces están en `docs/architecture.md`. La regla de color, que también está en el reporte:
**azul es código que escribimos nosotros, gris es software de terceros aunque sea de código
abierto y aunque corra en nuestro servidor.**

| Nivel | Qué muestra | Qué toca el paso 1 |
| --- | --- | --- |
| **1 · Contexto** | La persona con diabetes, Glucy, el sensor comercial, Open Food Facts, el servidor | Nada. El paso 1 no habla con nadie de afuera. |
| **2 · Contenedores** | App iOS · API · base de datos · servicio de explicación (azules) · HealthKit, Vision, Ollama, Qwen3, PostgreSQL, Grafana (grises) | Solo el contenedor **App iOS**, y solo por dentro. |
| **3 · Componentes de la app** | Las capas de dentro del teléfono: vistas, view models, casos de uso, reglas, repositorios, servicios | **Aquí vive el paso 1 completo**: la caja de reglas de dominio y los modelos. |
| **Capas** | `View → ViewModel → UseCase → Repository` | El paso 1 construye el fondo de esa pila. Todo lo de arriba se apoya en él. |

Dicho de otra forma: el paso 1 es **la caja azul más profunda del nivel 3**, la que no depende
de ninguna caja gris. Por eso se puede probar sin simulador, sin cámara, sin HealthKit y sin
internet, y por eso va primero.

Lo que hay que respetar para que el código y el diagrama sigan contándose la misma historia:

- `Domain/Rules` y `Domain/Models` **no importan ningún framework de Apple** salvo
  `Foundation` y `SwiftData`. Nada de `HealthKit`, nada de `Vision`, nada de `SwiftUI`. Si
  aparece un `import HealthKit` en `Domain/`, el diagrama dejó de ser cierto.
- Las dependencias van **en un solo sentido**. Una regla nunca llama a un repositorio.
- Cuando en la fase 2 se agregue un contenedor nuevo, se actualiza el diagrama en el mismo
  pull request que el código. Dos versiones de la verdad es lo que hay que evitar.

Las versiones con el código de colores aplicado son las que llevan el prefijo «Glucy v2 -»
en el tablero de FigJam.

---

## 8. Cómo se sabe que el paso 1 está hecho

1. `xcodebuild … -only-testing:GlucyAppTests test` termina en verde, con las catorce pruebas
   de la tabla de arriba.
2. Los mismos números que da `referencia/reglas_clinicas.py` de glucy-backend, empezando por
   el caso P-11.
3. **No se abrió una sola pantalla.** Si hay un `.swift` dentro de `Features/`, el paso 1 se
   desbordó.
4. `grep -r "import HealthKit\|import SwiftUI\|import Vision" GlucyApp/Domain/` no devuelve
   nada.
5. No hay ningún número clínico escrito suelto fuera de `ConfiguracionDominio.swift`.

---

## 9. Lo que NO entra en el paso 1

Vistas, view models, el contenedor de SwiftData en marcha, HealthKit, cámara, Open Food Facts,
sincronización, predicción, SHAP y el tema visual. Cada cosa tiene su paso y está en
`glucy-base/04-PLAN-FASE-1.md`. El paso 2 es la persistencia; el paso 3, la primera pantalla.

---

## 10. Git

```bash
git checkout develop
git pull origin develop
git checkout -b feature/dominio-y-reglas-clinicas
# …trabajo…
git add .
git commit -m "feat: enums, modelos de dominio y reglas clínicas con sus pruebas"
git push -u origin feature/dominio-y-reglas-clinicas
```

Conventional Commits en español. Un pull request cuando el paso esté completo, con el «qué se
veía antes / qué se ve después» de la plantilla. No se fusiona con la integración continua en
rojo.

---

## 11. El texto para pegarle a Claude Code

> Lee `CLAUDE.md` y `docs/paso-1-dominio-y-reglas.md`. Haz el paso 1 completo: los enums, los
> diez modelos de SwiftData y `Domain/Rules` con sus pruebas, en una rama
> `feature/dominio-y-reglas-clinicas`. No crees ninguna vista. Los números tienen que coincidir
> con `referencia/reglas_clinicas.py` del repositorio glucy-backend; empieza por el caso P-11,
> que es 60 g con absorción de 180 minutos, a los 90 minutos, igual a 30 g. Corre las pruebas
> antes de decirme que terminaste.
