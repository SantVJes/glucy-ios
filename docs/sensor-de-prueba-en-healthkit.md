# Sensor de prueba en HealthKit — el plan B de la fase 5

Documento de trabajo para Claude Code. **No es un paso de la fase 1 ni de la fase 2**: es la
herramienta que permite validar el modo sensor sin tener un sensor comercial.

---

## 1. El problema

La fase 5 valida el modo sensor con **48 horas continuas**: la consulta en segundo plano
despertando a la app, los huecos medidos, los retrasos medidos, la alerta encendida y lo que
pasa cuando la persona revoca el permiso con Glucy abierta.

Eso pide un Dexcom o un Libre, y el proyecto no tiene uno. La fecha para decidir si se consigue
es el **1 de noviembre de 2026**. Mientras no haya sensor, hay **cuatro casillas del apartado 9
de `docs/paso-10-cierre.md`** que no se pueden marcar, y una de ellas, P-14, está escrita como
pendiente en las notas del release:

| Casilla | Por qué no se pudo |
| --- | --- |
| La gráfica de Inicio **con sensor**: la línea continua se distingue de la punteada | «hace falta un sensor escribiendo en Salud para que haya línea que mirar» |
| Revocar el permiso de Salud **con Glucy abierta** (P-09) | se negó antes de abrir la app; el otro camino quedó a mano |
| Una lectura de Glucy y una del sensor conviviendo: la serie **no se duplica** (P-14) | «no hay un sensor que escriba en Salud» |
| La franja que dice **desde qué hora** se calló el sensor | se vio la de «todavía no llegan datos», no la otra |

El plan B es escribir la serie en HealthKit **desde otra app**. Para Glucy es lo mismo: su
código distingue lo propio de lo ajeno por el `HKSource`, comparando el `bundleIdentifier`
(`HealthKitReal.swift:64`), y no tiene ninguna lista de fabricantes permitidos. Una app con otro
identificador le sale como sensor externo.

El CSV con la serie lo produce **glucy-ml**:

```bash
python -m src.datos.para_healthkit --dias 2 --salida serie-para-healthkit.csv
```

Son tres columnas, documentadas en `docs/paso-5-serie-para-healthkit.md` de ese repositorio:

```
ts_medicion,ts_escritura,mg_dl
2026-01-05T00:00:00-06:00,2026-01-05T00:00:00-06:00,103.4
```

`ts_medicion` es cuándo ocurrió la lectura, que es lo que va en el `HKQuantitySample`.
`ts_escritura` es cuándo hay que escribirla. **Cuando las dos difieren, la lectura llega tarde**,
y todas las de un mismo bloque comparten `ts_escritura`, porque un sensor que vuelve a alcance
escribe todas de golpe y no una por una (RF-06b).

## 2. Lo que este plan B valida, y lo que no

Valida **la plomería**, que es donde están las tres trampas documentadas de HealthKit: la
consulta de observación en segundo plano, no reescribir lo que se leyó (RF-15b) y no caerse
cuando se revoca el permiso. Y en una cosa valida mejor que un sensor real: los huecos y los
retrasos se piden a propósito en lugar de esperar a que ocurran.

**No valida el comportamiento de un sensor comercial**: su cadencia real, sus recuperaciones, lo
que escribe al calibrar, lo que hace al cambiar de sensor. **Eso tiene que decirlo el reporte
(riesgo R-8)**, no dejar creer que se validó con hardware. El exportador de glucy-ml imprime ese
aviso en cada corrida; aquí la pantalla de la herramienta tiene que decir lo mismo, para que
nadie tome una captura de la gráfica por una captura con sensor de verdad.

## 3. Lo que se puede hacer hoy mismo, sin compilar nada

**P-14 se puede cerrar esta tarde con la app Salud.** No hace falta esta herramienta: basta
agregar glucosa a mano en Salud —que la escribe con el origen «Salud», distinto del de Glucy— en
tres días distintos, abrir Glucy, dejarla leer, cerrarla del todo y volverla a abrir. Si la serie
no se duplica, la casilla se marca. Son cinco minutos y no dependen de nada de este documento.

Conviene hacerlo **antes** de construir la herramienta, por si la herramienta no se alcanza a
terminar: es la única de las cuatro casillas que está escrita como pendiente en las notas del
release.

## 4. Qué se construye

Una app aparte, `SensorDePrueba`, con su propio identificador (`Freelancer.SensorDePrueba`). No
es un target de pruebas: un paquete de XCTest corre dentro del proceso de su app anfitriona, así
que si la anfitriona fuera Glucy, las muestras saldrían **con el `HKSource` de Glucy** y la
prueba no probaría nada. Tiene que ser otra app.

```
SensorDePrueba/
  SensorDePruebaApp.swift      el punto de entrada
  Pantalla.swift               los controles y la bitácora en pantalla
  SerieCsv.swift               lee el CSV de tres columnas
  EscritorDeSalud.swift        HealthKit: permiso, escritura y borrado
  Recursos/serie-para-healthkit.csv
  Info.plist                   con NSHealthUpdateUsageDescription
```

### 4.1 El target lo creas tú en Xcode, no Claude Code

Modificar `Glucy.xcodeproj/project.pbxproj` a mano es justo lo que ya costó una tarde de
integración continua en rojo. El camino de clics, en Xcode:

1. File › New › Target… › iOS › **App**.
2. Product Name: `SensorDePrueba`. Interface: SwiftUI. Language: Swift. Storage: None. Sin
   pruebas.
3. En el target nuevo › General › Minimum Deployments: **iOS 17.0**, igual que los otros cuatro.
4. Signing & Capabilities › **+ Capability** › **HealthKit**. No marques Clinical Health Records
   ni Background Delivery: esta app escribe estando al frente.
5. Build Settings › Swift Compiler - Concurrency › Strict Concurrency Checking: **Complete**,
   igual que Glucy.
6. Comprueba que el esquema **Glucy** no incluya este target en Build: Product › Scheme › Edit
   Scheme › Build. Si aparece, quítalo. La integración continua compila el esquema `Glucy`.
7. Confirma que `PRODUCT_BUNDLE_IDENTIFIER` del target nuevo sea `Freelancer.SensorDePrueba` y
   **no** `Freelancer.Glucy`. Si fueran iguales, el `HKSource` sería el mismo y todo esto no
   serviría.

Cuando esos siete pasos estén hechos, Claude Code escribe los archivos.

### 4.2 `SerieCsv.swift`

Lee las tres columnas. Nada de adivinar el formato: `ts_medicion` y `ts_escritura` vienen en ISO
8601 **con desplazamiento** (`-06:00`), que es lo que lee `ISO8601DateFormatter` con
`.withInternetDateTime`. Si una fila no se puede leer, **que truene con el número de fila**; un
lector que se salta filas en silencio produce una serie con huecos que nadie pidió, y los huecos
son justo lo que esta prueba mide.

Devuelve `[PuntoDeLaSerie]` con `tsMedicion`, `tsEscritura` y `mgDl`, **ordenado por
`tsEscritura`**. El exportador ya garantiza que las escrituras no van hacia atrás, así que un
orden que no se sostiene es un archivo equivocado: compruébalo y dilo.

### 4.3 `EscritorDeSalud.swift`

Pide permiso de **escritura** de glucosa (`HKQuantityType(.bloodGlucose)` en `toShare`). Si al
borrar sale un error de autorización, pide también lectura y déjalo escrito aquí; no lo supongas
de antemano.

Cada muestra:

```swift
let mgDl = HKUnit.gramUnit(with: .milli).unitDivided(by: .literUnit(with: .deci))
HKQuantitySample(
    type: HKQuantityType(.bloodGlucose),
    quantity: HKQuantity(unit: mgDl, doubleValue: punto.mgDl),
    start: punto.tsMedicion,
    end: punto.tsMedicion,
    device: dispositivo,
    metadata: [HKMetadataKeyWasUserEntered: false]
)
```

`mg/dL` como unidad de la muestra aunque la persona vea mmol/L en Salud: HealthKit convierte, y
Glucy ya trabaja todo en mg/dL. El `HKDevice` con nombre `Sensor de prueba` y fabricante
`Glucy` es lo que hace que en Salud se vea como un aparato y no como una entrada a mano; y es lo
que te deja distinguir después, mirando Salud, qué escribió esta herramienta.

Tres operaciones:

- **`escribirHistorico(_:)`** — guarda las 48 horas de golpe, con las fechas que trae el
  archivo desplazadas para que la última caiga **justo antes de ahora**. Es lo que llena la
  gráfica, el historial y los indicadores en segundos. Se guarda en lotes con un solo `save`
  por lote; quinientas muestras en una llamada es un lote razonable.
- **`escribirEnVivo(_:)`** — recorre los puntos en orden de `tsEscritura`, duerme lo que falte
  para cada bloque y lo guarda entero en un `save`. El desplazamiento se calcula una vez, al
  empezar: `desplazamiento = ahora − primera.tsEscritura`. Así una lectura puntual se escribe
  con antigüedad cero y una de un bloque atrasado se escribe con **hasta 35 minutos** de
  antigüedad, que es exactamente el caso que tiene que degradar el modo (frescura 15 min,
  RF-06c, D-13).
- **`borrarLoMio()`** — `delete(objectsOf:predicate:)` con el predicado de su propio
  `HKSource`. Una app solo puede borrar lo que ella escribió, así que esto no puede tocar ni lo
  de Glucy ni lo que la persona tenga en Salud. Existe para poder repetir la prueba sin
  arrastrar la corrida anterior, y **sin esto la segunda corrida no vale**: dos series encimadas
  no son una serie.

**El tiempo no se comprime.** Sería tentador escribir una hora de serie por minuto para no
esperar dos días, pero la regla de frescura compara `ahora − tsMedicion` contra quince minutos:
con el tiempo comprimido, todas las lecturas saldrían viejas y la app se quedaría siempre en
modo sin sensor. La prueba mediría lo contrario de lo que quiere medir.

### 4.4 `Pantalla.swift`

Un dato y una acción, como el resto del proyecto. Arriba, qué archivo está cargado y cuántos
puntos trae. Abajo, cuatro botones: **Escribir el histórico**, **Empezar en vivo**, **Detener** y
**Borrar lo que escribí**. En medio, una bitácora de líneas con hora, para poder decir después
qué se escribió y cuándo.

Dos cosas que no son adorno:

- **Un aviso fijo** que diga que la serie es de prueba y que no sustituye a un sensor comercial
  (R-8). Es la misma razón por la que Glucy lleva su aviso de RF-10b: una captura sin contexto
  acaba en un documento.
- **`isIdleTimerDisabled = true` mientras escribe en vivo**, y la app al frente con el teléfono
  enchufado. No lleva modo de segundo plano: la que tiene que estar en segundo plano es Glucy,
  que es lo que se está probando.

El CSV va dentro del paquete como recurso, y además un `fileImporter` para poder cargar otro sin
recompilar.

## 5. Las cuatro casillas, y cómo se cierra cada una

| Casilla | Cómo |
| --- | --- |
| La gráfica con sensor | **Histórico.** Escribe las 48 horas, abre Glucy, mira Inicio: línea continua de lo medido. Captura en color y en gris. |
| Franja «desde qué hora» | **Histórico y esperar.** Escribe el histórico recortado a hace una hora, abre Glucy y deja pasar el umbral de frescura: la franja tiene que decir desde cuándo, no «todavía no llegan datos». |
| Revocar con Glucy abierta (P-09) | **En vivo.** Con Glucy al frente recibiendo lecturas, ve a Salud y quítale el permiso. La app no se cae, pasa a modo sin sensor y lo dice. |
| P-14 | Con la app Salud, apartado 3. Si ya está marcada, repítela con la herramienta: es el mismo caso con una serie de verdad. |

Y lo que ninguna casilla pedía todavía, porque no se podía: **la consulta en segundo plano**.
Con la herramienta al frente escribiendo en vivo y Glucy en segundo plano, Glucy tiene que
despertar sola. Déjalo corriendo dos o tres horas, abre Glucy y mira si el historial tiene las
lecturas de ese rato o solo las de ahora. Las 48 horas completas son de la fase 5; esto es la
comprobación de que el mecanismo funciona.

## 6. Lo que no hay que hacer

- **No toques el target `Glucy`, ni su esquema, ni el flujo de trabajo de la integración
  continua.** Esta herramienta se compila y se corre a mano, y no entra en la CI.
- **No la metas en `Glucy/`.** Carpeta aparte en la raíz, para que nadie la mande a la App Store
  por accidente.
- **No escribas carbohidratos ni insulina.** Solo glucosa. Escribir una dosis desde una
  herramienta de pruebas enturbia justo el dato que la regla 7 protege.
- **No reutilices `Freelancer.Glucy` como identificador**, ni compartas el grupo de la app: el
  `HKSource` tiene que ser otro.
- **No cambies nada de `Glucy/Data/HealthKit/`.** Si para que la prueba funcione hubiera que
  cambiar la app, eso es un hallazgo: dilo y no lo cambies. La herramienta se adapta a la app.
- **No borres muestras que no escribió la herramienta.** El predicado va siempre atado a su
  propio `HKSource`.

## 7. Cuerpo del pull request

```
feat: herramienta de sensor de prueba que escribe la serie en HealthKit

Plan B de la fase 5: validar el modo sensor sin un sensor comercial.

Antes: cuatro casillas del apartado 9 del paso 10 no se podían marcar porque no
hay un Dexcom ni un Libre escribiendo en Salud, y P-14 está escrito como
pendiente en las notas del release.

Después: `SensorDePrueba` es una app aparte, con su propio identificador, que lee
el CSV de tres columnas que produce glucy-ml y escribe la serie en HealthKit.
Para Glucy es un sensor externo, porque distingue lo propio por el HKSource. Dos
modos: el histórico, que deja 48 horas en segundos, y el de en vivo, que respeta
las pausas del archivo y escribe cada bloque atrasado de golpe, como lo hace un
sensor que vuelve a alcance (RF-06b). Y un borrado atado a su propio HKSource,
para poder repetir la prueba sin arrastrar la corrida anterior.

No valida el comportamiento de un sensor comercial, y lo dice en pantalla: eso va
en el reporte como riesgo R-8.

No toca el target Glucy, ni su esquema, ni la integración continua.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01U7KrWasYkZhWRhqUnQcJ86
```

---

## 8. El texto para pegarle a Claude Code

> Lee `CLAUDE.md`, `docs/sensor-de-prueba-en-healthkit.md` y
> `Glucy/Data/HealthKit/HealthKitReal.swift`. Trabaja en una rama
> `feature/sensor-de-prueba` que sale de `develop`
> (`git switch -c feature/sensor-de-prueba origin/develop`); **no trabajes en `main` ni en
> `develop`**.
>
> **Yo ya creé el target `SensorDePrueba` en Xcode** con los siete pasos del apartado 4.1.
> Antes de escribir nada, dime qué identificador de paquete tiene el target y confírmame que no
> es el de Glucy; si lo fuera, todo esto no sirve y hay que arreglarlo primero.
>
> Construye los cinco archivos del apartado 4: el lector del CSV, el escritor de HealthKit con
> sus tres operaciones y la pantalla. El CSV de ejemplo lo genero yo con glucy-ml y te lo dejo
> en `SensorDePrueba/Recursos/serie-para-healthkit.csv`.
>
> **No toques el target `Glucy`, ni su esquema, ni `.github/workflows`, ni nada dentro de
> `Glucy/`.** Si para que esto funcione hiciera falta cambiar la app, no lo cambies: dímelo. La
> herramienta se adapta a la app, no al revés.
>
> **El lector del CSV truena con el número de fila si una fila no se puede leer**, en vez de
> saltársela. Una fila saltada es un hueco que nadie pidió, y los huecos son lo que esta prueba
> mide.
>
> **El modo en vivo no comprime el tiempo**: la regla de frescura son quince minutos de
> verdad, y con el tiempo comprimido todas las lecturas saldrían viejas y la app se quedaría
> siempre en modo sin sensor.
>
> **El borrado va siempre atado al `HKSource` propio.** Una app solo puede borrar lo que
> escribió; si tu código puede llegar a borrar otra cosa, está mal escrito.
>
> Cuando compile, **córrelo en mi iPhone conmigo aquí**: primero el histórico, y me dices qué
> ver en Glucy. Después escribe en el apartado 9 de `docs/paso-10-cierre.md` cuál de las cuatro
> casillas quedó comprobada y **cómo**, y deja sin marcar las que no, con su motivo. Y
> actualiza `docs/release-v0.1.0.md` si P-14 queda cerrada.
>
> Sube la rama y **abre el pull request contra `develop`** con el cuerpo del apartado 7
> (`gh pr create --base develop --head feature/sensor-de-prueba`); sin pull request la
> integración continua no corre. **Espera a que el run termine y dime su resultado antes de que
> yo lo fusione**: «cancelado» no es verde. No lo fusiones tú.
