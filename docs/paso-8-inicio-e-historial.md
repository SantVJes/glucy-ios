# Paso 8 — Inicio e historial, con Swift Charts

Documento de trabajo para Claude Code. Es el **octavo de los diez pasos** de la fase 1
(`glucy-base/04-PLAN-FASE-1.md`) y el primero que dibuja una gráfica.

Lo que hay hasta ahora: se puede registrar glucosa de tres maneras, una comida y una dosis, y
todo eso se guarda en el teléfono. Pero las pestañas **Inicio** e **Historial** siguen
mostrando el `PendienteView` del paso 3. Este paso las llena.

Lo que **no** trae, y es la decisión que ordena todo el documento: **no hay línea punteada**.
La predicción es de la fase 3. En su lugar va el estado vacío honesto del punto 8 del
Documento 1: «Aún no puedo proyectar». Es preferible no predecir a predecir mal, y una línea
punteada dibujada con cualquier cosa sería exactamente predecir mal.

Mockups: https://www.figma.com/design/TFOHJ9wm2lhsiEk1e3595A — pantalla 3 (`5-2`), pantalla 6
(`8-61`) y pantalla 10 (`10-78`). Ábrelos tú para comparar; Claude Code no puede abrirlos y
lo que manda es lo escrito aquí.

---

## 0. Antes de abrir Claude Code

### 0.1 La rama, antes que nada

```bash
cd ~/Documents/glucy-ios
git fetch origin
git switch -c feature/inicio-e-historial origin/develop
git branch --show-current     # tiene que decir: feature/inicio-e-historial
```

`origin/develop` ya tiene que llevar el paso 7 dentro. Compruébalo:

```bash
ls Glucy/Features/RegistroInsulina/     # tienen que estar las dos
ls Glucy/Domain/UseCases/CalcularInsulinaActiva.swift
```

### 0.2 Xcode no te pide nada en este paso

No hay capacidad que marcar, ni permiso que agregar al proyecto, ni llave nueva en el
Info.plist. Swift Charts viene con el sistema desde iOS 16 y el objetivo mínimo es 17.0:

```swift
import Charts   // no hay nada que instalar ni que agregar a «Frameworks»
```

```bash
grep -c "INFOPLIST_KEY_NS" Glucy.xcodeproj/project.pbxproj   # el mismo número que ya había
```

### 0.3 El iPhone

El apartado 8 bis lleva cinco comprobaciones que van en el iPhone y no en el simulador: las
gráficas con la letra de accesibilidad más grande, VoiceOver leyendo la gráfica y Audio
Graphs. El simulador no reproduce bien ni el gesto de la gráfica ni el sonido.

---

## 1. Qué se construye en el paso 8, y por qué va ahora

Tres pantallas del Documento 1 que en realidad son **dos archivos**:

- **Pantalla 3 (inicio, modo sensor)** y **pantalla 10 (inicio, sin sensor)** son la misma
  pantalla en dos estados, no dos pantallas. Se escriben como un solo `InicioView` que
  cambia según `EstadoModo.modo`. Dos archivos separados obligarían a mantener dos veces el
  valor actual, los dos accesos rápidos y la antigüedad, y el día que uno cambie el otro se
  queda atrás.
- **Pantalla 6 (historial)** es un `HistorialView` aparte: las tres cifras del periodo arriba
  y el día típico abajo.

Va ahora porque es el primer paso en el que la app **devuelve** algo. Hasta aquí solo recibía:
seis pasos guardando datos que nadie podía ver. El resto de la fase 1 (perfil, ajustes,
accesibilidad) se revisa mejor cuando ya hay algo que mirar.

Y porque **no toca ningún `@Model`**: es el primer paso desde el 4 que no trae migración. Todo
lo que necesita ya está guardado.

---

## 1 bis. Los requisitos, pegados

### RF-10b (fase 1) — el único de los cinco que la fase 1 cumple por completo

> En modo sin sensor, la app declara de forma explícita y visible que no puede anticipar
> hipoglucemias, tanto en el onboarding como en la pantalla de inicio.

### RF-16 (fases 1 y 2) — la parte de la fase 1 es todo menos exportar

> La pantalla de historial muestra los indicadores del periodo (tiempo en rango, promedio,
> GMI), el perfil de un día típico y permite exportar el informe. En modo sin sensor los
> indicadores se calculan sobre las lecturas disponibles y la pantalla dice sobre cuántas.

### RF-08, RF-09 y RF-10 (fase 3) — se pegan porque **definen la forma** de lo que se dibuja hoy

> **RF-08.** En modo sensor, la pantalla de inicio muestra el valor actual, la curva de las
> últimas horas y la proyección punteada a 30 y 60 minutos.

> **RF-09.** En modo sin sensor, la pantalla de inicio muestra la última lectura con su
> antigüedad, los puntos de los últimos días y, tras registrar una comida, la estimación del
> pico posterior.

> **RF-10.** La app indica siempre en qué modo está y qué exactitud tiene esa predicción.
> Nunca presenta la estimación del modo sin sensor con la misma apariencia que la curva del
> modo sensor.

De los tres, en este paso se construye lo que no es predicción: el valor actual, la curva de
las últimas horas, los puntos de los últimos días y el letrero del modo. La proyección
punteada y la estimación del pico llegan en la fase 3 **sin rediseñar nada**, y el apartado
2.1 explica cómo se deja preparado.

### RF-06c (fase 3), que ya está resuelto en el dominio desde el paso 4

> La pantalla de inicio muestra siempre la antigüedad de la última lectura real. Si supera el
> umbral de frescura definido para el modo sensor, la app degrada de forma explícita al modo
> sin sensor en lugar de seguir prediciendo con datos viejos, y lo dice en pantalla.

`ConsultarModo` ya devuelve el modo y la antigüedad. Este paso solo los dibuja.

### Y el requisito no funcional que manda sobre la pantalla

> **Honestidad de la predicción.** La app nunca muestra una estimación del modo sin sensor con
> la apariencia de una predicción del modo sensor, y declara de forma visible que en ese modo
> no hay alerta anticipada de hipoglucemia.

---

## 2. Las siete decisiones del paso 8

### 2.1 La gráfica se escribe hoy con la forma que va a tener en la fase 3

Si hoy se dibuja «una línea de lecturas» y en la fase 3 se le agrega la proyección, hay que
rehacer la gráfica. Si hoy se dibuja «una serie de puntos, cada uno con su clase», en la fase
3 solo llegan puntos de otra clase.

Así que el tipo de la gráfica nace completo:

```swift
/// A qué serie pertenece un punto de la gráfica. De esto depende cómo se dibuja, y es
/// la regla que no se puede romper: lo medido y lo proyectado **nunca** se parecen
/// (RF-10, y el requisito no funcional de honestidad de la predicción).
nonisolated enum SerieGrafica: String, Sendable, CaseIterable {
    /// Línea continua. Es un dato que existió.
    case medida
    /// Línea punteada y más delgada. Es un cálculo. **En la fase 1 nunca se produce.**
    case proyectada
}

nonisolated struct PuntoGrafica: Sendable, Equatable, Identifiable {
    let id: UUID
    let ts: Date
    let mgDl: Double
    let serie: SerieGrafica
    /// Para poder desglosar por origen en la fase 6 (RF-32) sin tocar la gráfica.
    let origen: Origen
}
```

En la fase 1 **nada construye un punto `.proyectada`**, y hay una prueba que lo fija (la 19).
Cuando llegue la fase 3, el que lo construya hereda el dibujo punteado ya hecho y ya probado.

La línea punteada se dibuja con `StrokeStyle(dash: [5, 4])` y además **más delgada** que la
continua: quien no distingue el color tiene que distinguir el grosor, y quien ve borroso de
madrugada tiene que distinguir el trazo. El color nunca es el único portador.

### 2.2 En modo sin sensor se dibujan **puntos sueltos**, no una línea

Es la decisión más importante del paso y la que más fácil se rompe sin darse cuenta.

Swift Charts dibuja `LineMark` entre dos puntos cualesquiera que le des. Si en modo sin sensor
se usa `LineMark`, dos pinchazos separados por nueve horas quedan unidos por una recta, y esa
recta **dice algo que nadie midió**: dice que a las tres de la mañana la glucosa iba por 140.
Es el mismo error que RF-23 prohíbe en el pipeline, donde la interpolación se limita a huecos
de quince minutos y solo en la serie continua. Aquí la versión visual del mismo error es más
grave, porque el pipeline lo anota en una tabla y la pantalla lo pone delante de los ojos de
alguien que puede estar decidiendo si se mide.

Así que:

| Modo | Marca | Ventana |
| --- | --- | --- |
| **sensor** | `LineMark` continuo, con `PointMark` encima de cada muestra real | las últimas **3 horas** |
| **sin sensor** | **solo `PointMark`**, nunca `LineMark` | los últimos **7 días** |

En modo sensor también se permite unir con línea porque ahí la serie *es* continua, llega cada
cinco minutos y la recta entre dos muestras consecutivas sí describe lo que pasó. Pero ni
siquiera ahí se rellenan los huecos: RF-06b dice que la app no supone una serie regular y no
rellena lo que no llegó. Un hueco de más de **15 minutos** (`interpolacionMaximaMin`) **corta
la línea**, no la estira. En Swift Charts eso se consigue partiendo la serie en tramos y
dibujando un `LineMark` por tramo, con `series:` distinto en cada uno.

### 2.3 El aviso de «sin sensor no anticipo hipoglucemias»: debajo del valor, encima de la gráfica

Los documentos del proyecto lo dicen de tres maneras que hay que conciliar: el Documento 1
dice «en segundo lugar de la pantalla, debajo del valor», el `CLAUDE.md` dice «arriba de la
pantalla de inicio» y el plan de la fase 1 dice «arriba de la gráfica». No se contradicen si
el orden es:

```
1. el valor actual, con su unidad y su antigüedad
2. ►► el aviso fijo y no descartable ◄◄
3. la gráfica
4. los dos accesos rápidos (comida e insulina)
```

Debajo del valor y encima de la gráfica. Y las tres reglas que lo hacen cumplir RF-10b de
verdad:

- **Fijo y no descartable.** Ninguna «X», ningún `@State var avisoVisible`, ningún
  `UserDefaults` que lo recuerde. Si se puede cerrar, se cierra el primer día y RF-10b deja de
  cumplirse para siempre.
- **VoiceOver lo lee justo después del valor**, antes de la gráfica. Se consigue con
  `.accessibilitySortPriority`, como el aviso del paso 7.
- **Ámbar solo en el borde y en el icono**, el texto en `textoPrincipal`. Es la regla del modo
  oscuro: `alertaAmbar` da 3.49:1 en claro, que alcanza para un borde y no para letra.

El texto, palabra por palabra, en el apartado 7.

### 2.4 El GMI no se muestra con cuatro lecturas

RF-16 pide las tres cifras: tiempo en rango, promedio y GMI. Las tres salen de
`CalculoIndicadores.calcular`, que ya existe desde el paso 1 y da los mismos números que
`referencia/reglas_clinicas.py`. El problema no es calcularlas, es **cuándo enseñarlas**.

El GMI es un estimador de la hemoglobina glucosilada, y la fórmula del consenso
(`3.31 + 0.02392 × promedio`) se validó sobre series continuas de **al menos 14 días**.
Calculado sobre seis pinchazos de la semana, el número sale igual de bonito y no significa
nada: alguien que se mide solo cuando se siente mal tiene un promedio sesgado hacia arriba, y
el GMI le devolvería una estimación de A1c más alta que la real. Eso no es un redondeo, es un
dato clínico equivocado en una app que la persona puede llevar a consulta.

Entonces, tres escalones, y cada uno dice la verdad en lugar de un cero:

| Lo que hay en el periodo | Qué se muestra |
| --- | --- |
| lecturas en menos de **3 días** distintos | ninguna cifra. «Necesito al menos tres días de datos para calcular tu tiempo en rango» |
| lecturas en **3 o más días** | tiempo en rango y promedio, con «sobre N lecturas de D días» |
| lecturas en **14 o más días** | las tres, GMI incluido |

Mientras el GMI no se puede calcular, su tarjeta **no desaparece**: muestra su título y
«Me faltan D días», para que se entienda que existe y qué falta. Una tarjeta que aparece y
desaparece hace pensar que la app está rota.

Los tres números van a `ConfiguracionDominio`, no sueltos en la vista:

```swift
// MARK: - Historial

/// Por debajo de tres días distintos con lecturas, un porcentaje de tiempo en rango
/// describe un día suelto y se lee como si describiera la semana (Documento 1, punto 8).
static let diasMinimosIndicadores = 3

/// La fórmula del GMI se validó sobre series de al menos 14 días. Con menos, el número
/// sale igual y no significa nada, y es un dato que la persona puede llevar a consulta.
static let diasMinimosGmi = 14

/// Los tres periodos del historial (Documento 1, pantalla 6). No hay un cuarto.
static let periodosHistorialDias = [7, 14, 30]
```

### 2.5 El día típico: la mediana por hora, y el hueco se queda hueco

El día típico es la única regla clínica de este paso que **no tiene referencia ejecutable** en
`referencia/reglas_clinicas.py`. Así que el método se fija aquí, completo, y cuando la fase 2
lo implemente en Python tendrá que dar estos mismos números.

Cómo se calcula:

1. **Cada lectura se agrupa por la hora local de su propia zona horaria guardada**, no por la
   hora UTC ni por la zona de hoy. Una lectura tiene `tsUtc` y `zonaHoraria` precisamente para
   esto (regla 5 del proyecto). Si se agrupara por la zona de hoy, un viaje a otro país
   movería el historial entero hacia atrás, y el «día típico» de alguien que viajó dejaría de
   describir su día.
2. Para cada una de las 24 horas se calculan **mediana, P25 y P75** de los valores de esa hora.
3. Los percentiles se calculan con **interpolación lineal entre los dos valores vecinos**: se
   ordena la lista, se toma la posición `p × (n − 1)` y, si cae entre dos índices, se
   interpola. Es la definición por omisión de `numpy.percentile`, y se escribe aquí porque hay
   nueve definiciones de percentil en uso y dos de ellas dan números distintos con listas
   cortas.
4. **Una hora con menos de 3 lecturas se queda vacía.** No se interpola con la hora de al
   lado, no se arrastra la anterior, no se pinta un cero. Con una o dos lecturas un cuartil no
   existe, y una banda dibujada sobre dos puntos sugiere una variabilidad que nadie midió. En
   la gráfica el hueco se ve como un hueco, y debajo se dice cuántas horas faltan.

```swift
nonisolated struct HoraTipica: Sendable, Equatable, Identifiable {
    var id: Int { hora }
    /// 0 a 23, hora local de la zona guardada en cada lectura.
    let hora: Int
    let mediana: Double
    let p25: Double
    let p75: Double
    let n: Int
}

nonisolated enum DiaTipico {
    /// Las horas que tienen suficientes lecturas, ordenadas. Las que no, no aparecen: un
    /// hueco en el día típico es información, y rellenarlo sería inventar.
    static func calcular(
        lecturas: [LecturaGlucosaDato],
        minimoPorHora: Int = ConfiguracionDominio.lecturasMinimasPorHora
    ) -> [HoraTipica]

    /// Percentil con interpolación lineal, la definición por omisión de `numpy.percentile`.
    /// Expuesto porque es lo que las pruebas fijan contra valores calculados a mano.
    static func percentil(_ p: Double, de valores: [Double]) -> Double?
}
```

Y la constante que falta:

```swift
/// Con una o dos lecturas en una hora, un cuartil no existe. La hora se queda vacía y la
/// pantalla dice cuántas faltan, en lugar de dibujar una banda que nadie midió.
static let lecturasMinimasPorHora = 3
```

### 2.6 Dos casos de uso nuevos, y ninguna regla clínica en el ViewModel

La pantalla de inicio necesita cinco cosas a la vez: el modo, la antigüedad, el valor actual,
la serie y los carbohidratos y la insulina que siguen activos. Si el ViewModel las pide una
por una a cinco sitios, acaba decidiendo cosas: qué ventana pedir, qué hacer si una falla,
cuándo cortar la línea. Eso son reglas, y las reglas no van en un ViewModel.

Así que cada pantalla tiene **un** caso de uso que le devuelve **un** struct ya resuelto:

```swift
nonisolated struct EstadoInicio: Sendable, Equatable {
    let modo: ModoApp
    /// `nil` si nunca hubo lectura. No se inventa un cero: en pantalla se leería como
    /// «recién medido».
    let antiguedadMin: Double?
    let ultima: LecturaGlucosaDato?
    /// Ya partida en tramos: cada tramo es una línea continua y entre tramos hay un hueco
    /// de más de `interpolacionMaximaMin`. En modo sin sensor viene un tramo por punto.
    let tramos: [[PuntoGrafica]]
    let carbohidratosActivosG: Double
    let insulinaActivaUI: Double
    /// Si la app puede anticipar una hipoglucemia. En modo sin sensor es `false` y la
    /// pantalla lo declara (RF-10b).
    let puedeAlertarHipoglucemia: Bool
}

nonisolated struct ConsultarInicio: Sendable {
    let lecturas: any RepositorioLecturas
    let comidas: any RepositorioComidas
    let modo: ConsultarModo
    let carbohidratosActivos: CalcularCarbohidratosActivos
    let insulinaActiva: CalcularInsulinaActiva

    func ejecutar(lecturaHealthKitActiva: Bool, ahora: Date = Date()) async throws -> EstadoInicio
}

nonisolated struct EstadoHistorial: Sendable, Equatable {
    let periodoDias: Int
    /// `nil` cuando no llega al mínimo de días. La pantalla dice qué falta, no un cero.
    let indicadores: Indicadores?
    let diasConLecturas: Int
    /// `true` cuando hay 14 días o más y el GMI significa algo (apartado 2.4).
    let gmiEsFiable: Bool
    let diaTipico: [HoraTipica]
    /// Cuántas de las 24 horas no llegaron al mínimo. Se dice en el pie de la gráfica.
    let horasSinDatos: Int
}

nonisolated struct ConsultarHistorial: Sendable {
    let lecturas: any RepositorioLecturas
    let perfil: any RepositorioPerfil

    func ejecutar(periodoDias: Int, ahora: Date = Date()) async throws -> EstadoHistorial
}
```

`ahora` se pasa, no se toma de `Date()` dentro: es lo que hace que todo esto se pueda probar.

Los umbrales del TBR y del TAR salen del perfil, no de las constantes por omisión: por eso
`ConsultarHistorial` pide `RepositorioPerfil`. Si no hay perfil todavía, usa los de
`ConfiguracionDominio`.

### 2.7 Las gráficas son accesibles desde el primer día, no en el paso 10

El paso 10 revisa las diez pantallas en el tamaño de letra más grande y en escala de grises.
Pero una gráfica que nace inaccesible no se arregla revisándola: se reescribe. Así que en este
paso cada gráfica trae ya las cuatro cosas:

- **`.accessibilityChartDescriptor`**, que es lo que enciende Audio Graphs. Sin eso VoiceOver
  anuncia «gráfica» y nada más, y la curva no existe para quien no la ve.
- **Un resumen en una frase** como `accessibilityLabel` del contenedor: «Tu glucosa de las
  últimas tres horas, de 96 a 148 miligramos por decilitro, subiendo despacio.» Cada cifra con
  su unidad.
- **Escala del eje Y fija** entre dos valores de `ConfiguracionDominio`, no automática. Con
  escala automática la banda verde 70–180 cambia de tamaño en cada actualización y la pantalla
  «respira»: a la una de la mañana eso se lee como que la glucosa se movió.
- **`reduce motion` respetado**: con la preferencia activada la gráfica no se anima al cambiar
  de periodo, aparece.

Y la banda objetivo 70–180 va con `RectangleMark` **detrás** de la serie, en `enRango` con
mucha transparencia, más una etiqueta «70–180» en el eje: en escala de grises la banda se
vuelve un gris claro y sin la etiqueta nadie sabe qué es.

---

## 3. Archivos que hay que crear o tocar

```
Glucy/Domain/Rules/
  DiaTipico.swift                      NUEVO    mediana y cuartiles por hora
  ConfiguracionDominio.swift           se amplía con las cuatro constantes

Glucy/Domain/UseCases/
  ConsultarInicio.swift                NUEVO
  ConsultarHistorial.swift             NUEVO
  CalcularCarbohidratosActivos.swift   NUEVO    el gemelo de CalcularInsulinaActiva

Glucy/Features/Comun/
  GraficaGlucosa.swift                 NUEVO    la gráfica, con PuntoGrafica y SerieGrafica
  TarjetaCifra.swift                   NUEVO    una cifra con su título y su pie

Glucy/Features/Inicio/
  InicioView.swift                     NUEVO    pantallas 3 y 10
  InicioViewModel.swift                NUEVO

Glucy/Features/Historial/
  HistorialView.swift                  NUEVO    pantalla 6
  HistorialViewModel.swift             NUEVO

Glucy/Features/Pestanas/
  PestanasView.swift                   se tocan dos renglones: Inicio e Historial

Glucy/App/
  ContenedorDependencias.swift         se amplía con los dos casos de uso nuevos

GlucyTests/
  DiaTipicoTests.swift                 NUEVO
  ConsultarInicioTests.swift           NUEVO
  ConsultarHistorialTests.swift        NUEVO
  CalcularCarbohidratosActivosTests.swift  NUEVO
  GraficaGlucosaTests.swift            NUEVO
  Dobles/RepositorioLecturasFalso.swift    se amplía si le falta `entre(desde:hasta:)`

GlucyUITests/
  InicioUITests.swift                  NUEVO
```

**No aparece ningún archivo de `Data/SwiftData/`, y es a propósito.** Este paso no cambia
ningún `@Model`, así que **no hay migración V5**. Si te encuentras escribiendo una, algo se
entendió mal: para. Todo lo que la pantalla necesita ya está guardado desde los pasos 1 a 7.

Tampoco aparece `Theme.swift`: los once colores y `textoSobreColor` alcanzan. La banda verde es
`enRango` con transparencia, no un color nuevo.

---

## 4. Las firmas

`CalcularCarbohidratosActivos` es el gemelo exacto del de insulina del paso 7, y existe por el
mismo motivo: la curva ya está escrita y probada en `Carbohidratos.cobTotal(comidas:)` desde el
paso 1, con los mismos números que `cob_total` de la referencia en Python. Esto solo le da de
comer, con cada comida llevando su propio `tiempoAbsorcionMin`, igual que cada dosis lleva su
propia `duracionAccionH` en el paso 7.

```swift
nonisolated struct CalcularCarbohidratosActivos: Sendable {
    let comidas: any RepositorioComidas

    /// Pide la ventana más larga que el dominio admite (`absorcionConfigurableMin`, 300 min)
    /// y no la de 180 por omisión: cada comida lleva su propio tiempo de absorción, y con
    /// 180 se quedarían fuera los carbohidratos de una comida lenta que sigue absorbiéndose.
    func ejecutar(ahora: Date) async throws -> Double
}
```

El caso que las pruebas fijan es el de siempre, **P-11**: 60 g con absorción de 180 minutos, a
los 90 minutos, son **30 g**. Absorción lineal, sin modelar la digestión (D-8, RF-24b).

Y la que parte la serie en tramos, que vive en la gráfica y no en el caso de uso porque es una
decisión de dibujo:

```swift
nonisolated enum TramosDeSerie {
    /// Parte una serie ordenada allí donde el hueco entre dos puntos pasa de
    /// `interpolacionMaximaMin`. Cada tramo se dibuja con su propio `LineMark`, así que un
    /// hueco se ve como un hueco en lugar de como una recta que nadie midió (RF-06b).
    static func partir(
        _ puntos: [PuntoGrafica],
        huecoMaximoMin: Double = ConfiguracionDominio.interpolacionMaximaMin
    ) -> [[PuntoGrafica]]
}
```

---

## 5. La pantalla de inicio, de arriba abajo

En los dos modos el orden es el mismo; lo que cambia es el contenido. Una persona que active
el sensor después de un mes de pinchazos no tiene que volver a aprenderse la pantalla.

| # | Qué | Modo sensor | Modo sin sensor |
| --- | --- | --- | --- |
| 1 | **El valor**, `azulProfundo`, bold 56, con «mg/dL» en `textoSecundario` | el actual | la última, con «hace 3 h» debajo |
| 2 | **El letrero del modo** | «Con sensor · hace 2 min» | «Sin sensor» |
| 3 | **El aviso de RF-10b**, fijo, no descartable | no aparece | **aparece siempre** |
| 4 | **La gráfica** | línea continua de 3 h, banda 70–180 | puntos de 7 días, banda 70–180 |
| 5 | **El pie de la gráfica** | «Aún no puedo proyectar: eso llega cuando el modelo esté entrenado.» | «Cada punto es una medición tuya. Sin serie continua no hay curva.» |
| 6 | **Carbohidratos e insulina que siguen activos**, dos cifras chicas | iguales | iguales |
| 7 | **Dos accesos rápidos**: «Anotar comida» y «Anotar insulina» | iguales | iguales |

Los accesos rápidos llevan a las pantallas que ya existen de los pasos 6 y 7. Si el perfil
tiene `registraInsulina == false`, el de insulina **no se dibuja** (RF-14), igual que en el
selector del paso 7.

El estado de carga: el valor anterior se queda en `textoSecundario` con «actualizando» al lado,
y la gráfica mantiene su tamaño con un bloque gris. **Nunca se vacía la pantalla para volver a
llenarla** (Documento 1, punto 8).

El estado del primer día: «Todavía no tengo lecturas tuyas» y un botón que lleva a Registrar.
No una gráfica vacía: una gráfica vacía se lee como que la app está rota.

---

## 6. Lo que este paso NO construye, y no es por falta de tiempo

Esto es trabajo, no una advertencia. Si algo de esta lista aparece en el diff, el paso está mal
aunque compile y aunque se vea bonito.

1. **Ninguna línea punteada, ninguna banda de incertidumbre, ningún valor a 30 o 60 minutos.**
   No hay modelo. Lo que se dibujaría sería una extrapolación inventada con apariencia de
   predicción, que es justo lo que el requisito no funcional de honestidad prohíbe.
2. **Ninguna estimación del pico postprandial** (RF-09, RF-27). Es de la fase 3 y necesita el
   modelo M-3.
3. **Ninguna alerta ni notificación** (RF-17). Es de la fase 3 y solo en modo sensor.
4. **Ninguna pantalla de detalle de la predicción ni de explicación** (pantallas 7 y 8,
   RF-11 y RF-11b). Fase 3.
5. **Ninguna exportación del informe.** RF-16 la pide y el plan la pone en el paso 10, junto
   con el repaso de accesibilidad. Aquí no va ni el botón.
6. **Ningún `LineMark` en modo sin sensor.** Apartado 2.2. Es la prueba 20.
7. **Ninguna comida inferida de una subida de glucosa** (RF-37, D-9). Si la gráfica sube y no
   hay comida registrada, la gráfica sube y no hay comida registrada. La prueba 21 fija el caso
   **P-12**.
8. **Ninguna cifra que no diga sobre cuántas lecturas se calculó.** RF-16 lo pide explícitamente
   y es lo que separa un indicador de un adorno.
9. **Nada de Ajustes.** El interruptor de ocultar insulina se lee, no se edita: la pantalla de
   ajustes es del paso 9.
10. **Ninguna migración de esquema.** Apartado 3.

---

## 7. Textos, palabra por palabra

De tú y en presente, sin tecnicismos, y ninguna frase que dé una instrucción de tratamiento.

**El aviso de RF-10b**, el que va fijo debajo del valor:

> **Sin sensor no puedo anticipar hipoglucemias.**
> Te enseño lo que has medido, no lo que va a pasar. Si te sientes mal, mídete.

«Si te sientes mal, mídete» es el límite exacto de lo que la app puede decir: pide una
medición, no un tratamiento. No se escribe «toma algo», «corrige» ni nada que insinúe una
cantidad.

**El letrero del modo**, al lado del valor:

> Con sensor · hace 2 min
> Sin sensor · última medición hace 3 h

**El pie de la gráfica, modo sensor:**

> Aún no puedo proyectar: eso llega cuando el modelo esté entrenado.

**El pie de la gráfica, modo sin sensor:**

> Cada punto es una medición tuya. Sin serie continua no hay curva que dibujar.

**El historial, cuando no llega a tres días:**

> Necesito al menos tres días de datos para calcular tu tiempo en rango.
> Llevas 2 días con mediciones.

**El historial, cuando ya hay indicadores:**

> Tiempo en rango · 68 % · sobre 94 mediciones de 7 días
> Promedio · 142 mg/dL · sobre 94 mediciones
> GMI · 6.7 % · estimación de tu A1c

**La tarjeta del GMI cuando faltan días:**

> GMI · Me faltan 8 días
> Esta estimación necesita al menos 14 días de mediciones para significar algo.

**El pie del día típico, cuando hay horas vacías:**

> 6 de las 24 horas no tienen suficientes mediciones y se quedan en blanco.
> No las relleno: sería inventar.

**La banda, en el eje:**

> 70–180 · tu rango objetivo

---

## 8. Las pruebas que tienen que pasar

Veintidós, cada una apuntando a su requisito. Las nueve del día típico y de los
carbohidratos activos tienen que dar los mismos números que `referencia/reglas_clinicas.py`
donde la referencia los tiene.

| # | Qué prueba | Por qué |
| --- | --- | --- |
| 1 | `DiaTipico.percentil(50, de: [1,2,3,4])` da 2.5 | la mediana de una lista par interpola |
| 2 | `percentil(25, de: [10,20,30,40,50])` da 20 y `percentil(75, …)` da 40 | la definición de `numpy.percentile` por omisión |
| 3 | `percentil` de una lista vacía da `nil`, de un solo valor da ese valor | los dos extremos |
| 4 | una hora con 2 lecturas **no aparece** en el resultado | apartado 2.5: con dos lecturas no hay cuartil |
| 5 | una hora con 3 lecturas aparece, con su `n == 3` | el límite por el otro lado |
| 6 | dos lecturas con el **mismo `tsUtc`** y zonas horarias distintas caen en **horas distintas** | se agrupa por la hora local guardada, no por UTC (regla 5) |
| 7 | 24 horas con datos dan 24 `HoraTipica` ordenadas de 0 a 23 | el caso completo |
| 8 | `p25 ≤ mediana ≤ p75` en todas las horas de un conjunto aleatorio | invariante que una implementación equivocada rompe |
| 9 | **P-11**: 60 g, absorción 180 min, a los 90 min = **30 g** | RF-24b, D-8, y coincide con la referencia |
| 10 | una comida de absorción 300 min a las 4 h sigue contando; con ventana de 180 no contaría | apartado 4: se pide la ventana larga |
| 11 | `CalcularCarbohidratosActivos` con cero comidas da 0, no lanza | el primer día |
| 12 | indicadores con lecturas de 2 días dan `indicadores == nil` y `diasConLecturas == 2` | apartado 2.4, escalón 1 |
| 13 | con lecturas de 3 días dan indicadores y `gmiEsFiable == false` | escalón 2 |
| 14 | con lecturas de 14 días dan `gmiEsFiable == true` | escalón 3 |
| 15 | el TIR se mide contra 70–180 aunque el perfil tenga umbral hipo en 80 | el TIR es fijo; el perfil mueve TBR y TAR |
| 16 | `ConsultarHistorial` con el periodo de 7 días **no** incluye una lectura de hace 9 días | la ventana se respeta |
| 17 | sin perfil guardado, los umbrales son los de `ConfiguracionDominio` | no se cae el primer día |
| 18 | `TramosDeSerie.partir` con un hueco de 20 min devuelve **dos** tramos; con uno de 10 min, **uno** | RF-06b: el hueco corta la línea |
| 19 | **ningún punto que produzca la fase 1 tiene `serie == .proyectada`** | apartado 2.1; es la frontera con la fase 3 |
| 20 | en modo sin sensor `EstadoInicio.tramos` trae **un punto por tramo** | apartado 2.2: imposible dibujar un `LineMark` |
| 21 | **P-12**: la glucosa sube 60 mg/dL sin comida registrada y `EstadoInicio` no inventa ninguna | RF-37, D-9 |
| 22 | **P-04**: en modo sin sensor `puedeAlertarHipoglucemia == false` y el texto del aviso está en la vista | RF-10b, y que el aviso no se pueda apagar |

La 22 se comprueba en el `XCUITest`: se abre la app en modo sin sensor, se busca el
identificador `avisoSinSensor`, se intenta desplazar y tocar, y el aviso **sigue ahí**. Es la
única manera de probar «no descartable»: que no exista el gesto que lo descarta.

Las pruebas 1 a 8 conviene escribirlas con `@Test(arguments:)` sobre una lista de casos, para
que cuando una falle el nombre diga cuál fue.

### 8 bis. En el iPhone físico

El simulador no reproduce bien ni el gesto de la gráfica ni Audio Graphs.

- [ ] **Letra de accesibilidad más grande** (Ajustes → Accesibilidad → Pantalla y tamaño de
  texto → Texto más grande, al máximo): las tres cifras del historial se apilan en una columna
  y **ningún texto se corta** (caso P-15).
- [ ] **VoiceOver sobre la gráfica de inicio**: lee el resumen con las cifras y sus unidades, y
  al deslizar hacia la derecha lee el aviso de RF-10b **antes** de la gráfica.
- [ ] **Audio Graphs**: con VoiceOver activo, el gesto de tres dedos hacia arriba sobre la
  gráfica ofrece «Describir gráfica» y la reproduce con sonido.
- [ ] **Escala de grises** (Accesibilidad → Pantalla → Escala de grises): la banda 70–180
  sigue reconociéndose por su etiqueta en el eje, y el aviso ámbar por su icono y su texto.
- [ ] **Reducir movimiento** activado: cambiar de 7 a 30 días no anima la gráfica.
- [ ] **Modo oscuro**, con el brillo al mínimo: la banda verde no se come la línea y las cifras
  se leen.

---

## 9. Cómo se sabe que el paso 8 está hecho

- Las 22 pruebas pasan, más las 186 que ya pasaban.
- La integración continua está verde **antes** de fusionar.
- `./scripts/regla-7.sh` sigue saliendo en verde: este paso no toca insulina, pero el script
  corre en cada push y tiene que seguir pasando.
- `grep -rn "LineMark" Glucy/Features/` solo aparece dentro de la rama de modo sensor de
  `GraficaGlucosa.swift`, en ningún otro sitio.
- `grep -rn "proyectada" Glucy/ | grep -v "SerieGrafica\|GraficaGlucosa\|Tests"` no devuelve
  nada: en la fase 1 nadie construye un punto proyectado.
- `git diff --stat origin/develop -- Glucy/Data/SwiftData/ Glucy/App/Theme/` está **vacío**:
  ni migración ni colores nuevos.
- `grep -rn "0x[0-9A-Fa-f]\{6\}" Glucy/ | grep -v "Glucy/App/Theme/Theme.swift"` no devuelve
  nada.
- En el simulador, con lecturas de tres días metidas a mano, el historial enseña las dos cifras
  y la del GMI dice cuántos días faltan.
- La pestaña Inicio ya no muestra el `PendienteView`, y la de Ajustes **sí** lo sigue mostrando.

---

## 10. Lo que NO entra en el paso 8

- **La exportación del informe** (RF-16). Va en el paso 10 con el repaso de accesibilidad.
- **El desglose por origen del dato** (RF-32). `PuntoGrafica` ya guarda el origen para que la
  fase 6 no tenga que tocar la gráfica, pero aquí no se dibuja.
- **Elegir el rango de la gráfica de inicio.** Tres horas en modo sensor y siete días sin
  sensor, fijos. Un selector más es una decisión más a la una de la mañana.
- **Tocar un punto para ver su detalle.** La profundidad máxima es dos niveles y la pantalla de
  detalle de una lectura no está en el alcance de la fase 1.

---

## 11. Git

```bash
git switch -c feature/inicio-e-historial origin/develop
# …trabajo…
git add -A
git commit -m "feat: pantalla de inicio e historial con Swift Charts"
git push -u origin feature/inicio-e-historial
gh pr create --base develop --head feature/inicio-e-historial
```

El pull request va contra **`develop`**, no contra `main`. Y **no se fusiona con la
integración continua en rojo ni corriendo**: se espera a que el run termine y se lee su
resultado, porque «cancelado» no es verde.

---

## 11 bis. El cuerpo del pull request, ya escrito

```markdown
## Antes

Las pestañas **Inicio** e **Historial** mostraban el estado vacío del paso 3: un icono gris y
una frase. Seis pasos de la fase 1 guardaban glucosa, comidas y dosis en el teléfono y no
había ninguna pantalla donde verlas. Los indicadores clínicos existían en `Domain/Rules`
desde el paso 1, probados, y nadie los llamaba.

## Después

**Inicio** enseña el valor actual con su unidad y su antigüedad, el modo en el que está la
app, la gráfica de glucosa con la banda objetivo 70–180 detrás, los carbohidratos y la
insulina que siguen activos, y dos accesos rápidos a registrar comida e insulina.

En modo sensor la gráfica es la línea continua de las últimas tres horas, y un hueco de más
de quince minutos la **corta** en lugar de estirarla. En modo sin sensor son los puntos de
los últimos siete días, **sin línea**: unir dos pinchazos separados por nueve horas dibujaría
una glucosa que nadie midió.

En modo sin sensor aparece además, debajo del valor y encima de la gráfica, el aviso fijo y
no descartable de que la app no puede anticipar hipoglucemias. No tiene botón de cerrar, y
VoiceOver lo lee antes de la gráfica.

**Historial** enseña tiempo en rango, promedio y GMI del periodo (7, 14 o 30 días), cada cifra
con sobre cuántas mediciones se calculó, y debajo el día típico: la mediana hora por hora con
su banda P25–P75. Con menos de tres días de mediciones no enseña ninguna cifra, dice cuántos
días llevas. El GMI espera a los catorce días y mientras dice cuántos faltan.

Ninguna de las dos pantallas dibuja una proyección. No hay modelo todavía, y el pie de la
gráfica lo dice con todas sus letras: «Aún no puedo proyectar: eso llega cuando el modelo esté
entrenado.»

## Cómo

Dos casos de uso nuevos, `ConsultarInicio` y `ConsultarHistorial`, que devuelven un struct ya
resuelto para que ningún ViewModel decida nada. Una regla nueva, `DiaTipico`, con la mediana y
los cuartiles por hora; los percentiles se calculan con interpolación lineal, la definición por
omisión de `numpy.percentile`, para que la fase 2 pueda dar los mismos números en Python. Y
`CalcularCarbohidratosActivos`, el gemelo del cálculo de insulina activa del paso 7, que solo
le da de comer a la curva lineal que ya estaba escrita y probada desde el paso 1.

La gráfica es un solo `GraficaGlucosa` para las dos pantallas. Cada punto lleva su serie,
`medida` o `proyectada`, y la proyectada se dibuja punteada y más delgada. En la fase 1 nada
construye un punto proyectado, y hay una prueba que lo fija: cuando llegue la fase 3 el dibujo
ya está hecho y ya está probado.

Las horas del día típico se agrupan por la hora local de la zona horaria guardada en cada
lectura, no por UTC ni por la zona de hoy: si no, un viaje movería el historial entero. Y una
hora con menos de tres mediciones se queda en blanco, con el pie diciendo cuántas faltan. No se
interpola: sería inventar.

Sin migración de esquema. Este paso no toca ningún `@Model`.

## Requisitos que cubre

- **RF-10b** — el aviso fijo y no descartable del modo sin sensor, en la pantalla de inicio.
- **RF-16** (fase 1) — los indicadores del periodo, el día típico y sobre cuántas lecturas se
  calcularon. La exportación queda para el paso 10.
- **RF-06c** — la antigüedad de la última lectura, siempre visible.
- **RF-06b** — el hueco corta la línea; no se rellena lo que no llegó.
- **RF-08, RF-09, RF-10** (fase 3) — la parte que no es predicción: el valor, la curva, los
  puntos y el letrero del modo, con la forma que la fase 3 va a rellenar.
- **RF-37, D-9** — no se infiere ninguna comida de una subida de glucosa.
- **RF-24b, D-8** — carbohidratos activos con absorción lineal.

## Comprobado

- [x] Las 22 pruebas nuevas pasan, más las 186 anteriores
- [x] `./scripts/regla-7.sh` sigue en verde
- [x] Sin migración: el diff de `Data/SwiftData/` está vacío
- [x] Sin colores nuevos: el diff de `App/Theme/` está vacío
- [x] Ningún `LineMark` en la rama de modo sin sensor
- [x] Letra de accesibilidad más grande en el iPhone, sin texto cortado (P-15)
- [x] VoiceOver lee el aviso antes de la gráfica, y Audio Graphs describe la curva
- [x] El aviso del modo sin sensor no se puede cerrar (P-04)
```

---

## 12. El texto para pegarle a Claude Code

> Lee `CLAUDE.md` y `docs/paso-8-inicio-e-historial.md`. Trabaja en una rama
> `feature/inicio-e-historial` que sale de `develop`
> (`git switch -c feature/inicio-e-historial origin/develop`); **no trabajes en `main` ni en
> `develop`**. Construye el paso completo: `DiaTipico` en `Domain/Rules`, los casos de uso
> `ConsultarInicio`, `ConsultarHistorial` y `CalcularCarbohidratosActivos`, la gráfica
> compartida `GraficaGlucosa` con `PuntoGrafica` y `SerieGrafica`, las pantallas de Inicio e
> Historial con sus ViewModels, los dos renglones de `PestanasView` y las 22 pruebas del
> apartado 8.
>
> **No dibujes ninguna predicción.** No hay modelo todavía: ninguna línea punteada, ninguna
> banda de incertidumbre, ningún valor a 30 ni a 60 minutos, ninguna estimación de pico
> después de una comida. En su lugar va el pie que dice «Aún no puedo proyectar». El tipo
> `SerieGrafica.proyectada` se escribe y se dibuja punteado, pero en la fase 1 **nada lo
> construye**, y la prueba 19 lo fija. El apartado 6 tiene la lista completa de lo que no
> entra y es parte del trabajo, no una advertencia.
>
> **En modo sin sensor, solo `PointMark`, nunca `LineMark`.** Unir dos pinchazos separados por
> horas dibuja una glucosa que nadie midió, y es el mismo error que RF-23 prohíbe en el
> pipeline. En modo sensor sí hay línea, pero un hueco de más de quince minutos la corta en
> dos tramos en lugar de estirarla.
>
> El aviso de que sin sensor no se anticipan hipoglucemias va **debajo del valor y encima de
> la gráfica**, fijo, sin botón de cerrar y sin nada que lo recuerde apagado; VoiceOver lo lee
> antes de la gráfica. Los textos exactos están en el apartado 7 y no se parafrasean.
>
> El día típico agrupa por la **hora local de la zona horaria guardada en cada lectura**, no
> por UTC ni por la de hoy. Una hora con menos de tres mediciones se queda **vacía**: no se
> interpola, no se arrastra la anterior, no se pinta un cero. Los percentiles van con
> interpolación lineal, la definición por omisión de `numpy.percentile`.
>
> **No toques ningún `@Model` y no escribas ninguna migración**: este paso no la necesita y una
> migración de más borra la base al arrancar. **No toques `Theme.swift`**: los once colores y
> `textoSobreColor` alcanzan, y la banda verde es `enRango` con transparencia. Recuerda que
> `superficie` solo va en `.background`; la letra sobre un relleno de color lleva
> `textoSobreColor`.
>
> Las gráficas llevan `.accessibilityChartDescriptor`, un resumen en una frase con cada cifra y
> su unidad, escala del eje Y fija y respeto a «reducir movimiento». Es requisito, no capa
> final.
>
> Corre las pruebas y dime cuántas pasaron. Corre también `./scripts/regla-7.sh` y los cuatro
> `grep` del apartado 9, y confirma qué devolvieron. Después sube la rama y **abre el pull
> request contra `develop`** con el cuerpo del apartado 11 bis
> (`gh pr create --base develop --head feature/inicio-e-historial`); no basta con subir la
> rama, porque sin pull request la integración continua no corre. **Espera a que el run
> termine y dime su resultado antes de que yo lo fusione**: «cancelado» no es verde. No lo
> fusiones tú.
