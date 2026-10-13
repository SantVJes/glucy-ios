# Paso 10 — Accesibilidad, los nueve estados, el informe y el cierre de la fase 1

Documento de trabajo para Claude Code. Es el **décimo y último paso** de la fase 1
(`glucy-base/04-PLAN-FASE-1.md`): el que convierte nueve pasos de funcionalidad en una
versión que se puede instalar, usar y entregar, y que sale con su etiqueta `v0.1.0`.

Lo que hay hasta ahora: las cuatro pestañas completas, el alta con consentimiento expreso,
glucosa por tres vías, comida por código de barras, insulina, inicio e historial con sus
gráficas, modo oscuro medido y 235 pruebas pasando en 44 suites. Lo que falta no es una
funcionalidad más: es **comprobar que todo eso se puede usar de verdad**, en el tamaño de
letra más grande, en escala de grises, con VoiceOver, sin conexión y a las tres de la mañana.

Y falta una cosa que sí es nueva y es la última del alcance de la fase 1: **el informe para
el médico** (RF-16). Es el apartado 2.1.

El criterio de «hecho» del plan, palabra por palabra:

> Los quince casos de prueba que aplican a la fase 1 pasan, el recorrido completo funciona en
> modo avión, y sale el release **`v0.1.0`** con sus notas.

Este paso es distinto de los nueve anteriores en una cosa importante: **la mitad del trabajo
no se puede automatizar**, y por eso el apartado 9 es una lista de comprobación en el iPhone
físico con casillas, no una suite de pruebas. Una lista con casillas sin marcar es un trabajo
sin terminar, no un adorno.

Mockups: https://www.figma.com/design/TFOHJ9wm2lhsiEk1e3595A — las diez pantallas, que es
justo lo que se repasa. El informe para el médico está en el lienzo de las otras trece:
https://claude.ai/artifact/JjwUJfsZunXFGvQZyrG8pX

---

## 0. Antes de abrir Claude Code

1. **Deja el PR #8** (`develop` → `main`) donde está, abierto. Es el que se va a convertir en
   el release al final de este paso (apartado 10); si lo fusionas ahora tendrás que abrir otro.
   Lo que sí conviene es comprobar que su CI está verde.
2. Ponte en `develop` y actualiza: `git switch develop && git pull origin develop`.
3. Comprueba que arrancas de 235 pruebas en verde:
   `xcodebuild -scheme Glucy -destination 'platform=iOS Simulator,name=iPhone 17' test`.
4. **Ten el iPhone a mano y conectado.** Seis de las comprobaciones de este paso no existen
   en el simulador: Dynamic Type real con el pulgar en Ajustes, la escala de grises del
   sistema, VoiceOver, Audio Graphs, el arranque en frío y el modo avión de verdad.

---

## 1. Qué se construye en el paso 10, y qué solo se comprueba

| | Qué | Es |
| --- | --- | --- |
| 1 | **El informe para el médico**: un PDF que la persona comparte desde Historial (RF-16) | código nuevo |
| 2 | **Los tres huecos de los nueve estados** del punto 8 de `01-glucy-ios.md` | código nuevo |
| 3 | **P-15 automatizado**: las diez pantallas recorridas en el tamaño de letra más grande | pruebas nuevas |
| 4 | **La medición del arranque en frío** (< 2 s hasta ver el valor actual) | prueba nueva, se corre en el iPhone |
| 5 | El repaso en **escala de grises**, con **VoiceOver** y con **«reducir movimiento»** | lista de comprobación |
| 6 | El recorrido completo **en modo avión** (P-07) | lista de comprobación |
| 7 | El aviso de que Glucy no es un dispositivo médico, en el README y en la app | código nuevo, dos líneas |
| 8 | La etiqueta **`v0.1.0`** con sus notas | git |

---

## 2. Las ocho decisiones del paso 10

### 2.1 El informe es un PDF, y la identidad es un interruptor apagado

RF-16 pide «exportación del informe». No dice en qué formato, así que se decide aquí.

**Es un PDF y nada más.** No un CSV, no un JSON, no las dos cosas. Quien va a leerlo es una
persona en una consulta de quince minutos: lee una página. Un CSV sería un segundo formato con
sus propias pruebas, su propio recorrido de privacidad y su propia forma de salir mal, para
una necesidad que nadie ha expresado. Cuando alguien la exprese, se agrega.

**Se genera con `ImageRenderer` sobre una vista SwiftUI y se comparte con `ShareLink`.** No
hay que dibujar un PDF a mano: la vista del informe es una vista normal, con los mismos
tokens de `Theme.swift`, y `ImageRenderer` tiene `render(rasterize:)` que entrega un contexto
de PDF. La gráfica del día típico entra como parte de la vista, así que no hay dos maneras de
dibujarla.

**Y aquí está la decisión que hay que dejar escrita, porque si no alguien la va a leer mañana
como una violación de la regla 3.** La regla 3 dice que lo que identifica a la persona **no
sube**: no sale del teléfono hacia el servidor de Glucy. Compartir un archivo desde la hoja
del sistema no es una subida: es la persona entregando sus propios datos a quien ella decide,
igual que si los copiara a mano en una hoja. La regla se respeta. Lo que hay que hacer es que
esa decisión sea **suya, explícita y revertible**:

- **Un solo interruptor**, «Incluir mis datos personales», **apagado por omisión**, que
  gobierna el bloque entero: nombre, apellidos, año de nacimiento y peso. Un interruptor por
  campo son cuatro decisiones a las siete de la mañana en una sala de espera; uno solo es una.
- Debajo, en texto fijo: «Apagado, el informe solo lleva tus cifras. Encendido, lleva también
  tu nombre y tu peso, para que tu médico sepa de quién es.»
- El PDF **se escribe en la carpeta temporal y se borra** cuando se cierra la hoja. Es el
  mismo criterio de la regla 6 con las fotos: lo que no hace falta guardar, no se guarda. Un
  informe con el nombre dentro que se queda para siempre en la carpeta de la app es
  exactamente el archivo que no queremos que exista.
- **Nunca entran**: las notas, ninguna fotografía (no hay, la regla 6 lo impide), y el UUID
  del perfil. El UUID no le dice nada a un médico y es lo único que ataría ese PDF a lo que
  algún día haya en el servidor.

Lo que lleva el informe, en este orden:

1. **Encabezado**: «Informe de glucosa», el periodo con sus dos fechas, la fecha de
   generación con su hora, y la zona horaria del dispositivo (regla 5). Si el interruptor está
   encendido, debajo el bloque de identidad.
2. **Las tres cifras** que ya calcula `ConsultarHistorial`: tiempo en rango, promedio y GMI,
   cada una **con sobre cuántas mediciones se calculó**. Si el GMI no es fiable todavía, se
   dice por qué, con la frase que ya está en Historial. Un informe que presenta un GMI de tres
   días como si fuera un GMI es peor que uno que no lo trae.
3. **El día típico**, la misma gráfica de Historial con su banda P25–P75 y su leyenda.
4. **Qué registró la persona en el periodo**: cuántas lecturas, cuántas comidas, cuántas
   dosis, y **las lecturas desglosadas por origen** (sensor, manual, foto del glucómetro,
   HealthKit). Ese desglose es el que le dice al médico cuánto de esto es un sensor y cuánto
   son pinchazos, que cambia por completo cómo se lee el resto de la hoja.
5. **El aviso, en todas sus letras y no en letra chica**: «Glucy no es un dispositivo médico
   certificado. Estas cifras las registró la persona y no sustituyen una medición de
   laboratorio ni una indicación médica.»

Lo que **no** lleva, y conviene que se note que es a propósito: **ninguna predicción y ningún
factor**. En la fase 1 no hay modelo. Un informe que dejara un hueco con «predicción» vacío
invita a creer que la app predice y no supo.

### 2.2 El informe se comparte desde Historial, no desde Ajustes

El botón va **al final de la pantalla de Historial**, debajo del día típico. La persona acaba
de ver las tres cifras y la gráfica: ese es el momento en que piensa «esto se lo quiero
enseñar a mi doctora». En Ajustes sería un trámite perdido entre interruptores, y además
Ajustes ya tiene la única acción irreversible de la app y no necesita competencia.

El periodo del informe es **el que esté elegido en Historial** (7, 14 o 30 días). No se vuelve
a preguntar: ya lo contestó con el selector que tiene delante.

### 2.3 Los nueve estados: tres huecos, y dos que se aplazan con razón

El punto 8 de `01-glucy-ios.md` pide nueve estados definidos. Ocho ya existen de los pasos
anteriores; esta tabla es el inventario, y hay que comprobarla pantalla por pantalla antes de
dar el paso por hecho.

| Estado | Dónde | Cómo está |
| --- | --- | --- |
| Vacío, primer día | Inicio, Historial | **hecho** — «Todavía no tengo lecturas tuyas» y «Necesito al menos tres días de datos» |
| Carga | Inicio | **hecho** — el valor anterior en gris con «actualizando» y el bloque gris de la gráfica |
| Error del OCR | Registro de glucosa | **hecho** (paso 5) |
| Producto no encontrado | Registro de comida | **hecho** (paso 6) |
| Confirmación al guardar, con «Deshacer» | las tres capturas | **hecho** (pasos 3, 6 y 7) |
| Antes de borrar la cuenta | Ajustes | **hecho** (paso 9) |
| Sin conexión | Ajustes, con la cola contada | **hecho** (paso 9) |
| **Error del sensor** | Inicio | **falta** — apartado 2.4 |
| Vacío, sin datos para predecir | Inicio | **se aplaza**, apartado 2.5 |

Y dos cosas más que el repaso encuentra y que no son estados, pero son cabos sueltos visibles:

- **La tarjeta «Del sensor» de la pantalla de Registro de glucosa dice «Todavía no está
  lista» y está desactivada.** Era verdad en el paso 3 y dejó de serlo en el paso 4. Hay que
  arreglarla, y la manera correcta no es activarla: **del sensor no se captura nada a mano**,
  las lecturas entran solas por HealthKit. La tarjeta deja de ser un botón apagado y pasa a
  ser informativa, con dos textos según el modo: con sensor, «Tus lecturas entran solas desde
  Salud»; sin sensor, «Puedes conectar tu sensor en Ajustes». Una tercera vía que parece rota
  hace dudar de las otras dos.
- **`PendienteView` ya no lo usa ninguna pestaña.** Se borra, con su previsualización. Código
  muerto en una entrega es una pregunta que alguien va a hacer en la revisión.

### 2.4 El error del sensor es un estado propio, distinto del modo sin sensor

Hoy, si el sensor deja de escribir, pasan dos cosas correctas: `DecisionModo` degrada a modo
sin sensor pasados quince minutos (RF-06c) y el aviso de RF-10b aparece. Lo que **no** pasa es
que se distinga **«no tienes sensor»** de **«tienes sensor y hace cuarenta minutos que no
escribe»**. Son dos situaciones muy distintas y la segunda tiene algo que hacer.

El estado nuevo se dibuja **solo si el perfil dice `usaSensor == true`** y la última lectura
de origen sensor o HealthKit es más vieja que el umbral de frescura. Es una franja ámbar
—ámbar **solo en el borde y en el icono**, el texto en `textoPrincipal`, como el aviso de
RF-10b—, va **debajo del aviso de RF-10b** cuando los dos salen, y dice la hora de la última
lectura, no los minutos: «Sin datos de tu sensor desde las 8:05. Revisa que la app de tu
sensor esté abierta.» Con su botón «Reintentar», que vuelve a correr
`SincronizarLecturasDelSensor`.

La hora y no «hace 40 minutos» porque la hora es un dato que la persona puede cruzar con lo
que estaba haciendo. Y **nunca «error de conexión»**: no hay ninguna conexión en juego, la
app del fabricante dejó de escribir en Salud, y decirle a alguien que revise su internet
cuando el problema es su sensor lo manda a buscar donde no está.

El umbral es `ConfiguracionDominio.frescuraSensorMin`, el mismo que ya decide el modo. No se
inventa un segundo umbral: dos números para la misma idea terminan divergiendo.

### 2.5 El estado «sin datos para predecir» se aplaza a la fase 3, y se dice por qué

El punto 8 pide un estado para «se dibuja la curva pero sin línea punteada: *aún no puedo
proyectar, me faltan lecturas de las últimas dos horas*». Ese estado supone que en otras
ocasiones **sí** proyecta. En la fase 1 no proyecta nunca: no hay modelo hasta la fase 3.

Lo que hay hoy es lo correcto y ya se escribió en el paso 8: el pie de la gráfica dice «Aún no
puedo proyectar: eso llega cuando el modelo esté entrenado». Es la verdad, es permanente
mientras lo sea, y no promete nada. Cuando llegue el modelo, ese pie se convierte en el estado
del punto 8, con su condición de «me faltan lecturas de las últimas dos horas».

Lo mismo con **la vibración de advertencia en la alerta de hipoglucemia**: la accesibilidad de
la fase 1 la pide, pero las alertas son RF-17 y RF-18, fase 3. No hay alerta que vibrar. Se
deja dicho aquí para que en la fase 3 no se olvide, y no se simula una vibración sin alerta
para poder marcar una casilla.

### 2.6 P-15 se automatiza, porque «se ve bien» no es una comprobación

P-15 dice «letra de accesibilidad más grande sin cortar texto». Es el único de los quince
casos de la fase 1 que no tiene prueba, y es también el más fácil de dar por bueno mirando de
reojo.

Se automatiza en `XCUITest` arrancando la app con el tamaño de letra forzado:

```swift
app.launchArguments += [
    "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
]
```

Y para cada una de las diez pantallas se comprueba tres cosas, que son las tres formas en que
esto se rompe de verdad:

1. **Los elementos clave siguen existiendo y se pueden tocar** (`exists && isHittable`). Con la
   letra grande, un botón empujado fuera de la pantalla sigue existiendo en el árbol de
   accesibilidad pero ya no se puede pulsar. Es el fallo más común y el más invisible.
2. **Nada se sale de ancho**: el `frame` de cada elemento consultado cabe dentro del
   `frame` de la ventana. Un texto que se sale a la derecha no se ve cortado en el simulador
   de un Mac grande; en un teléfono sí.
3. **El recorrido crítico se completa**: registrar una glucosa manual de punta a punta con esa
   letra. Si el botón de guardar no se alcanza, la app no es usable para quien necesita esa
   letra, y eso no es un detalle estético: es el usuario de sesenta años con retinopatía
   diabética, que es población objetivo de este proyecto.

Lo que **no** comprueba esta prueba, y hay que decirlo para no creerla más de lo que es: no
detecta un texto truncado con puntos suspensivos dentro de su propio marco. Eso es la vista en
el iPhone, apartado 9.

### 2.7 El arranque en frío se mide, y el presupuesto se reparte

El plan pide **menos de 2 segundos hasta ver el valor actual**, medido en el iPhone físico. Se
mide con una prueba de rendimiento:

```swift
measure(metrics: [XCTApplicationLaunchMetric()]) { app.launch() }
```

Eso mide hasta que la app responde, no hasta que el valor está en pantalla. Para el valor hay
un segundo número, que es el que de verdad pide el plan: el tiempo desde el lanzamiento hasta
que el elemento `valorActual` existe. Se mide con un reloj alrededor de
`waitForExistence(timeout:)` y se afirma contra los dos segundos.

El presupuesto, para saber dónde mirar si no alcanza:

| Tramo | Cuánto | Dónde está |
| --- | --- | --- |
| Lanzamiento de iOS y SwiftUI | lo que sea, no se toca | — |
| Abrir el contenedor de SwiftData y migrar si hace falta | debería ser milisegundos | `ContenedorGlucy` |
| El mínimo del splash | **0.4 s**, es nuestro | `splashMinimoS` |
| Leer el perfil y la última lectura | una consulta cada una | `ConsultarEntrada`, `ConsultarInicio` |

Si no cabe en dos segundos, **lo primero que se baja es `splashMinimoS`**, que es un adorno
contra el parpadeo y no un requisito. Lo que **no** se hace es quitar la migración del arranque
ni leer menos datos: eso cambia el comportamiento para ganar una décima.

Importante: esta medición **no corre en la integración continua**. Un simulador en un runner
compartido da números que no significan nada, y una prueba de rendimiento que falla al azar
se acaba desactivando y con ella se van las que sí servían. Va marcada para correrse a mano en
el dispositivo, y su resultado se anota en las notas del release.

### 2.8 La escala de grises no se automatiza, se inventaría

No hay forma honesta de automatizar «el color no es el único portador de información». Lo que
sí se puede hacer es **enumerar cada sitio donde el color significa algo** y comprobar uno por
uno que lleva además icono, palabra o forma. Ese inventario es el trabajo; la vista en grises
en el teléfono solo lo confirma.

| Dónde el color significa algo | Qué lo acompaña | Estado |
| --- | --- | --- |
| Letrero del modo en Inicio | icono propio por modo (`dot.radiowaves…` / `drop`) y la palabra | hecho, paso 8 |
| Aviso de RF-10b | triángulo de advertencia y la frase completa | hecho, paso 8 |
| Franja de error del sensor | triángulo, la hora y el botón | **nuevo, 2.4** |
| Línea medida contra proyectada | continua gruesa contra punteada delgada | hecho, paso 8 |
| Lectura fuera de la escala de la gráfica | **triángulo** en lugar de círculo | hecho, paso 8 |
| Banda de rango objetivo | su etiqueta «70–180» dibujada | hecho, paso 8 |
| Botón de borrar la cuenta | la palabra «Borrar» y el texto que hay que teclear | hecho, paso 9 |
| Franja de «guardado» con Deshacer | la palabra y el botón | hecho, pasos 3, 6 y 7 |

El modo oscuro ya trae sus 44 razones de contraste medidas (`docs/modo-oscuro.md`) y
`ContrasteTests` las fija. En este paso **no se vuelven a medir** y no se toca `Theme.swift`:
si una pantalla nueva necesita un color, usa uno de los doce.

---

## 3. Archivos que hay que crear o tocar

**Nuevos**

```
Glucy/Domain/UseCases/ArmarInforme.swift          qué lleva el informe, sin nada de PDF
Glucy/Features/Informe/InformeView.swift          la vista que se rasteriza
Glucy/Features/Informe/InformeViewModel.swift     el interruptor de identidad y el archivo temporal
Glucy/Data/Informe/GeneradorDePdf.swift           ImageRenderer → URL temporal, y el borrado
GlucyTests/ArmarInformeTests.swift
GlucyTests/EstadoDelSensorTests.swift
GlucyUITests/AccesibilidadUITests.swift           P-15, las diez pantallas
GlucyUITests/ArranqueUITests.swift                el arranque en frío, marcado para el dispositivo
```

**Se tocan**

```
Glucy/Features/Historial/HistorialView.swift      el botón de compartir, al final
Glucy/Features/Historial/HistorialViewModel.swift
Glucy/Features/Inicio/InicioView.swift            la franja de error del sensor
Glucy/Features/Inicio/InicioViewModel.swift       cuándo sale esa franja
Glucy/Domain/UseCases/ConsultarInicio.swift       el dato que la franja necesita
Glucy/Features/RegistroGlucosa/RegistroGlucosaView.swift   la tarjeta «Del sensor»
Glucy/App/ContenedorDependencias.swift
README.md                                          el aviso
```

**Se borra**

```
Glucy/Features/Pestanas/PendienteView.swift
```

**No se toca**: `Glucy/App/Theme/`, ningún `@Model`, ninguna etapa de migración. Este paso
**no lleva migración de esquema**: no agrega ni cambia un solo campo. Si aparece una etapa V6
en el diff, algo se hizo de más.

---

## 4. Las firmas

```swift
/// Lo que lleva el informe del médico. Se arma en el dominio y no sabe que existe un PDF:
/// así se puede probar sin rasterizar nada (RF-16).
nonisolated struct ArmarInforme: Sendable {
    let historial: ConsultarHistorial
    let lecturas: any RepositorioLecturas
    let comidas: any RepositorioComidas
    let dosis: any RepositorioDosis
    let perfil: any RepositorioPerfil

    /// - Parameter conIdentidad: si `false`, el informe no trae nombre, apellidos, año de
    ///   nacimiento ni peso. Nace en `false` (apartado 2.1).
    func ejecutar(dias: Int, conIdentidad: Bool, ahora: Date) async throws -> Informe
}

nonisolated struct Informe: Sendable, Equatable {
    let desde: Date
    let hasta: Date
    let generadoTsUtc: Date
    let zonaHoraria: String
    /// `nil` cuando la persona no quiso incluir sus datos. No es un campo vacío: es que no va.
    let identidad: IdentidadDelInforme?
    let indicadores: IndicadoresDelPeriodo
    let diaTipico: [HoraTipica]
    let conteos: ConteosDelPeriodo
}

nonisolated struct ConteosDelPeriodo: Sendable, Equatable {
    let lecturas: Int
    let comidas: Int
    let dosis: Int
    /// Cuántas lecturas por origen. Es lo que le dice al médico cuánto de esto es sensor.
    let lecturasPorOrigen: [OrigenDato: Int]
}

/// El estado del sensor que Inicio dibuja. Distinto del modo: «no tengo sensor» y «mi sensor
/// no escribe desde las 8:05» no son lo mismo (apartado 2.4).
nonisolated enum EstadoDelSensor: Sendable, Equatable {
    /// El perfil no usa sensor. No hay nada que avisar.
    case noConfigurado
    case alDia
    /// Con sensor configurado y la última lectura más vieja que la frescura.
    case sinDatos(desde: Date)
}
```

```swift
/// Rasteriza la vista del informe a un PDF temporal. Lo único de la app que sabe qué es un
/// PDF, igual que `HealthKitReal` es lo único que sabe qué es `HKSample`.
@MainActor
struct GeneradorDePdf {
    /// Escribe el PDF en la carpeta temporal y devuelve su URL.
    func generar(_ vista: some View, nombre: String) throws -> URL

    /// Lo borra. Se llama al cerrarse la hoja de compartir, y también si algo falla a medias:
    /// un informe con el nombre de la persona dentro no se queda en el disco (apartado 2.1).
    func borrar(_ url: URL)
}
```

---

## 5. Lo que este paso NO construye

- **Ningún CSV, ningún JSON, ninguna exportación «de los datos crudos».** Apartado 2.1.
- **Ninguna predicción, ninguna banda de incertidumbre, ningún factor SHAP** en el informe ni
  en ninguna pantalla. Las pantallas 7 y 8 de los mockups son de la fase 3 y en la fase 1 no
  existen; el repaso de accesibilidad de este paso cubre **las ocho que sí existen** más el
  splash y el alta.
- **Ninguna notificación ni ninguna alerta.** RF-17 y RF-18, fase 3.
- **Ningún cambio de `Theme.swift`** ni ninguna razón de contraste nueva.
- **El cambio de unidad aplicado a toda la app.** Quedó dicho en el paso 9: la unidad se
  guarda y se usa en el alta y en Ajustes. Recorrer las diez pantallas convirtiendo cada cifra
  es un paso en sí mismo, y hacerlo a medias dejaría unas pantallas en mg/dL y otras en
  mmol/L, que es peor que tenerlo todo en mg/dL. **El informe sale en mg/dL**, que es la
  unidad interna y la del documento del proyecto.
- **Ninguna migración de esquema.**

---

## 6. Textos, palabra por palabra

Estos no se parafrasean.

**La franja de error del sensor** (apartado 2.4), con la hora en formato corto local:

> Sin datos de tu sensor desde las 8:05. Revisa que la app de tu sensor esté abierta.

Botón: `Reintentar`.

**La tarjeta «Del sensor»** en Registro de glucosa, informativa, según el modo:

> Con sensor: «Tus lecturas entran solas desde Salud.»
> Sin sensor: «Puedes conectar tu sensor en Ajustes.»

**El interruptor del informe**:

> Incluir mis datos personales
>
> Apagado, el informe solo lleva tus cifras. Encendido, lleva también tu nombre y tu peso,
> para que tu médico sepa de quién es.

**El aviso del informe**, al final de la hoja y no en letra chica:

> Glucy no es un dispositivo médico certificado. Estas cifras las registró la persona y no
> sustituyen una medición de laboratorio ni una indicación médica.

**El aviso del README y de Ajustes** (en Ajustes ya está la sección de privacidad; esto va al
pie, una vez):

> Glucy no es un dispositivo médico certificado y no debe usarse como única fuente para una
> decisión terapéutica. Informa; no prescribe ni administra, y nunca calcula ni sugiere una
> dosis de insulina.

---

## 7. Las pruebas que tienen que pasar

Dieciocho nuevas, sobre las 235 que ya pasan.

### El informe (RF-16)

| # | Qué prueba | Por qué |
| --- | --- | --- |
| 1 | `ArmarInforme` con `conIdentidad: false` devuelve `identidad == nil` | apartado 2.1: no es un campo vacío, es que no va |
| 2 | con `true`, trae nombre, apellidos, año y peso | que el interruptor sirva para algo |
| 3 | el informe **nunca** trae el UUID del perfil ni notas, con el interruptor en cualquier posición | lo que no le dice nada a un médico no sale del teléfono |
| 4 | las tres cifras del informe son **idénticas** a las que devuelve `ConsultarHistorial` para el mismo periodo | dos caminos al mismo número terminan divergiendo |
| 5 | con menos de 14 días, el informe trae el GMI marcado como no fiable, no un número | presentar un GMI de tres días como GMI es desinformar |
| 6 | con menos de 3 días, el informe no trae cifras y lo dice | el estado de vacío también existe en papel |
| 7 | `lecturasPorOrigen` suma exactamente `conteos.lecturas` | un desglose que no suma es un desglose mal hecho |
| 8 | el periodo del informe es el que se le pasó, y `desde`/`hasta` lo delimitan | que no se cuele una lectura de fuera |
| 9 | `GeneradorDePdf.generar` escribe un archivo que existe y pesa más de cero | que el PDF no salga vacío |
| 10 | `borrar` lo deja sin existir | apartado 2.1: no se queda en el disco |

### El estado del sensor (apartado 2.4)

| # | Qué prueba | Por qué |
| --- | --- | --- |
| 11 | con `usaSensor: false` el estado es `.noConfigurado`, aunque no haya ninguna lectura | quien no tiene sensor no tiene un sensor roto |
| 12 | con `usaSensor: true` y la última lectura del sensor hace 40 min, es `.sinDatos` con esa fecha | el estado nuevo |
| 13 | con `usaSensor: true` y la última hace 5 min, es `.alDia` | que no salga la franja cuando todo va bien |
| 14 | con `usaSensor: true` y la última lectura **manual** hace 2 min, pero la del sensor hace 40, es `.sinDatos` | un pinchazo no prueba que el sensor escriba |
| 15 | el umbral es `frescuraSensorMin`, no un número escrito aparte | un segundo umbral para la misma idea acaba divergiendo |

### Accesibilidad y arranque

| # | Qué prueba | Por qué |
| --- | --- | --- |
| 16 | **P-15**: con `AccessibilityXXXL`, en las diez pantallas los elementos clave existen y son tocables, y ninguno se sale del ancho de la ventana | apartado 2.6 |
| 17 | **P-15**, recorrido: con esa letra, registrar una glucosa manual de punta a punta | el botón de guardar hay que poder alcanzarlo |
| 18 | el arranque en frío deja ver `valorActual` en menos de 2 s (**marcada para el dispositivo**, fuera de la CI) | apartado 2.7 |

---

## 8. Cómo se sabe que el paso 10 está hecho

- Las 18 pruebas nuevas pasan, más las 235 que ya pasaban.
- La integración continua está verde **antes** de fusionar.
- `./scripts/regla-7.sh` en verde.
- `grep -rn "PendienteView" Glucy/` no devuelve **nada**.
- `grep -rn "Todavía no está lista" Glucy/` no devuelve nada.
- `git diff --stat origin/develop -- Glucy/App/Theme/` está **vacío**.
- `git diff --stat origin/develop -- Glucy/Data/SwiftData/` está **vacío**: este paso no lleva
  migración.
- `grep -rn "UserDefaults" Glucy/` no devuelve nada.
- `grep -rn "uuid" Glucy/Features/Informe/ Glucy/Domain/UseCases/ArmarInforme.swift` no
  devuelve nada: el UUID del perfil no llega al informe.
- Las doce casillas del apartado 9 están marcadas.

---

## 9. La lista de comprobación en el iPhone físico

Esto es la mitad del paso. Sin esto, el paso no está hecho, por muchas pruebas que pasen.

**Letra de accesibilidad (P-15)** — Ajustes del sistema › Pantalla y brillo › Tamaño del
texto, al máximo, y además Accesibilidad › Pantalla y tamaño del texto › Texto más grande.

- [ ] Las **diez pantallas**, una por una: nada truncado con puntos suspensivos, ningún texto
  que se salga, ningún botón al que no se llegue. Las dos tarjetas de sensor del alta siguen
  siendo del mismo tamaño cuando se apilan.
- [ ] La cifra de glucosa de Inicio y su unidad: cuando no caben en un renglón, la unidad baja
  y no se encima.

**Escala de grises** — Accesibilidad › Pantalla y tamaño del texto › Filtros de color ›
Escala de grises.

- [ ] Las ocho filas de la tabla del apartado 2.8, comprobadas en pantalla: en cada una se
  entiende qué pasa **sin** el color.
- [ ] La gráfica de Inicio con sensor: se distingue la línea continua de cualquier punteada.
- [ ] La gráfica de Inicio sin sensor: los puntos fuera de escala se ven como triángulos.

**VoiceOver** — Accesibilidad › VoiceOver.

- [ ] Inicio: el primer elemento que lee es **el valor con su unidad y su antigüedad**, y
  después el aviso de RF-10b si está. Nunca la gráfica primero.
- [ ] Historial: las tres cifras se leen con su unidad y con sobre cuántas mediciones se
  calcularon.
- [ ] Las dos gráficas tienen descripción, y **Audio Graphs** suena en las dos.
- [ ] El alta se puede completar entera con VoiceOver.

**Reducir movimiento** — Accesibilidad › Movimiento › Reducir movimiento.

- [ ] El splash desaparece en lugar de desvanecerse, y nada se desliza.

**Modo avión (P-07)**

- [ ] Con el avión encendido: registrar una glucosa manual, una comida **por captura manual**
  y una dosis. Las tres se guardan, se ven en Inicio y en Historial, y Ajustes dice cuántos
  registros esperan turno.
- [ ] Un código de barras con el avión encendido lleva a la foto de la etiqueta y, si eso
  falla, a la captura manual (P-10), y **no** a una pantalla de error.

**El informe**

- [ ] Compartirlo con el interruptor apagado: el PDF **no** trae nombre ni peso. Abrirlo y
  comprobarlo, no suponerlo.
- [ ] Compartirlo con el interruptor encendido: los trae.
- [ ] El PDF se ve bien en la app de Archivos y en Correo, y la gráfica del día típico sale
  dibujada y no en blanco.

**Arranque en frío**

- [ ] Cerrar la app del todo, esperar, abrirla: el valor actual está en pantalla en menos de
  dos segundos. Anotar el número medido en las notas del release.

**HealthKit, lo que solo pasa en un teléfono**

- [ ] Revocar el permiso desde la app Salud con Glucy abierta: la app no se cae, vuelve a modo
  sin sensor y lo dice (P-09).
- [ ] Una lectura escrita por Glucy y una del sensor conviviendo en Salud: tras reiniciar la
  app, la serie **no se duplica** (P-14).
- [ ] Con el perfil en «con sensor» y la app del sensor cerrada un rato: aparece la franja del
  apartado 2.4 con una hora creíble, y «Reintentar» hace algo.

---

## 10. Git y el release

```bash
git switch -c feature/cierre-fase-1 origin/develop
# …trabajo…
git add -A
git commit -m "feat: informe para el médico, estado del sensor y repaso de accesibilidad"
git push -u origin feature/cierre-fase-1
gh pr create --base develop --head feature/cierre-fase-1
```

Cuando ese PR esté fusionado en `develop` **y la CI verde**, y las doce casillas del apartado
9 estén marcadas, se cierra la fase:

El PR que lleva `develop` a `main` **ya existe**: es el **#8**, abierto desde el 3 de octubre.
No se abre otro —GitHub no admite dos con la misma rama de origen y de destino—, se le cambia
el título y se fusiona:

```bash
gh pr edit 8 --title "release: v0.1.0, la app autónoma de la fase 1"
gh pr merge 8 --merge
# una vez fusionado:
git switch main && git pull origin main
git tag -a v0.1.0 -m "v0.1.0 — app autónoma: captura por tres vías, gráficas, indicadores y alta"
git push origin v0.1.0
```

Las **notas del release** llevan cinco cosas y ninguna más: qué hace la app sin servidor y sin
sensor; los diez pasos con su número de pruebas; el número medido de arranque en frío; lo que
**no** hace todavía (predicción, sincronización, explicación, notificaciones); y el aviso de
que no es un dispositivo médico certificado.

---

## 11. El cuerpo del pull request, ya escrito

```markdown
## Antes

La app estaba completa de funciones y sin terminar de comprobar. Las lecturas, las comidas, las
dosis, las gráficas y los indicadores funcionaban, pero no había forma de llevarle nada de eso
a un médico: lo único que la persona podía hacer era enseñarle el teléfono. En Inicio, un
sensor que dejaba de escribir se veía igual que no tener sensor. La pantalla de registro de
glucosa seguía diciendo que la vía del sensor «todavía no está lista», algo que dejó de ser
verdad en el paso 4. Y el tamaño de letra de accesibilidad más grande no lo comprobaba ninguna
prueba, en una app cuyos usuarios incluyen a gente con retinopatía diabética.

## Después

Al final de Historial hay un botón que arma un informe en PDF y lo comparte: el periodo
elegido, las tres cifras con sobre cuántas mediciones se calcularon, el día típico dibujado,
cuántos registros hubo de cada tipo y las lecturas desglosadas por origen. Los datos
personales van detrás de un interruptor apagado por omisión, y el archivo se borra del
teléfono al cerrar la hoja de compartir.

En Inicio, quien tiene sensor y lleva un rato sin recibir datos ve una franja que dice desde
qué hora, con un botón para reintentar; quien no tiene sensor no la ve nunca. La tarjeta «Del
sensor» ahora explica que esas lecturas entran solas, en lugar de parecer un botón roto.

Y las diez pantallas se recorren en una prueba con el tamaño de letra de accesibilidad más
grande, comprobando que todo se alcanza y nada se sale de la pantalla.

## Cómo

`ArmarInforme` es un caso de uso que no sabe que existe un PDF: devuelve un `Informe` y se
prueba sin rasterizar nada. Las cifras no se recalculan, las pide a `ConsultarHistorial`, para
que el informe y la pantalla no puedan dar números distintos. `GeneradorDePdf` es el único
sitio de la app que conoce `ImageRenderer`, y es también el que borra el archivo.

El estado del sensor es un enum de tres casos en el dominio, y distingue `noConfigurado` de
`sinDatos` con el mismo `frescuraSensorMin` que ya decide el modo, sin un segundo umbral.

Sin migración de esquema, sin cambios en `Theme.swift` y sin un solo color nuevo.

## Comprobado

- 253 pruebas en verde (235 anteriores + 18 nuevas).
- `./scripts/regla-7.sh` en verde.
- Las doce casillas de la lista del iPhone, marcadas, incluido el arranque en frío medido.
- El informe abierto en Archivos con el interruptor en las dos posiciones.

## Requisitos que cubre

RF-16 (exportación del informe), el punto 8 de `01-glucy-ios.md` (los nueve estados), P-07,
P-09, P-10, P-14 y P-15.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

https://claude.ai/code/session_01U7KrWasYkZhWRhqUnQcJ86
```

---

## 12. El texto para pegarle a Claude Code

> Lee `CLAUDE.md` y `docs/paso-10-cierre.md`. Trabaja en una rama `feature/cierre-fase-1` que
> sale de `develop` (`git switch -c feature/cierre-fase-1 origin/develop`); **no trabajes en
> `main` ni en `develop`**. Construye el paso completo: el caso de uso `ArmarInforme`, la
> vista del informe y su `GeneradorDePdf`, el botón de compartir al final de Historial, el
> estado nuevo del sensor en Inicio, el arreglo de la tarjeta «Del sensor» de Registro de
> glucosa, el borrado de `PendienteView`, el aviso del README, y las 18 pruebas del
> apartado 7.
>
> **El informe es un PDF y nada más**: no agregues CSV, ni JSON, ni «exportar los datos
> crudos». Y no lleva ninguna predicción ni ningún factor: en la fase 1 no hay modelo, y un
> hueco de «predicción» vacío hace creer que la app predice y no supo.
>
> **Los datos personales del informe van detrás de un solo interruptor, apagado por
> omisión**, que gobierna nombre, apellidos, año de nacimiento y peso juntos. El UUID del
> perfil y las notas **nunca** entran, en ninguna posición del interruptor. El PDF se escribe
> en la carpeta temporal y **se borra al cerrarse la hoja de compartir**: un informe con el
> nombre de la persona dentro no se queda en el disco.
>
> **Las tres cifras del informe se le piden a `ConsultarHistorial`, no se recalculan.** Si el
> informe y la pantalla pueden dar números distintos, algún día los van a dar.
>
> **El estado del sensor distingue tres casos**: quien no tiene sensor configurado no tiene un
> sensor roto y no ve ninguna franja. El umbral es `ConfiguracionDominio.frescuraSensorMin`,
> **no un número nuevo**. La franja dice la hora de la última lectura, no los minutos, y nunca
> dice «error de conexión»: no hay ninguna conexión en juego.
>
> **La tarjeta «Del sensor» no se activa, se convierte en informativa.** Del sensor no se
> captura nada a mano; las lecturas entran solas por HealthKit desde el paso 4.
>
> **Este paso no lleva migración de esquema.** No agregues ni cambies un solo campo de un
> `@Model`, y no escribas una etapa V6. Si aparece una, algo se hizo de más. Tampoco toques
> `Glucy/App/Theme/`: si una pantalla necesita un color, usa uno de los doce. `superficie`
> solo va en `.background`, y la letra encima de un relleno de color lleva `textoSobreColor`.
> Nada en `UserDefaults`.
>
> **La prueba del arranque en frío va marcada para correrse en el dispositivo, fuera de la
> integración continua.** Un simulador en un runner compartido da números que no significan
> nada, y una prueba de rendimiento que falla al azar se acaba desactivando.
>
> Los textos del apartado 6 van tal cual, no se parafrasean.
>
> Corre las pruebas y dime cuántas pasaron. Corre también `./scripts/regla-7.sh` y los nueve
> `grep` del apartado 8, y confirma qué devolvieron. Después sube la rama y **abre el pull
> request contra `develop`** con el cuerpo del apartado 11
> (`gh pr create --base develop --head feature/cierre-fase-1`); no basta con subir la rama,
> porque sin pull request la integración continua no corre. **Espera a que el run termine y
> dime su resultado antes de que yo lo fusione**: «cancelado» no es verde. No lo fusiones tú.
>
> Cuando termines, dime también qué casillas del apartado 9 me quedan por hacer en el iPhone:
> son la mitad del paso y no las puedes marcar tú.
