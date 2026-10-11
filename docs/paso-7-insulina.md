# Paso 7 — Insulina

Documento de trabajo para Claude Code. Séptimo de los diez pasos de la fase 1
(`glucy-base/04-PLAN-FASE-1.md`).

**Este paso va después del modo oscuro, no antes.** La pantalla de comidas del paso 6 copió el
parche de forzar el modo claro dentro de la vista, así que el modo oscuro se construye primero
y en su propia rama. Si empiezas el paso 7 antes, la pantalla de insulina nace con el mismo
parche y hay que rehacerla.

**Este paso no toca `Theme.swift` ni la pantalla de comidas.** Son del trabajo del modo oscuro.
La pantalla de insulina no necesita ningún color nuevo: le bastan `azulPrimario`, `azulClaro`,
`alertaAmbar` (solo borde), `textoPrincipal` y `textoSecundario`, que ya existen.

Diseño: la pantalla de insulina no está en los diez mockups de Figma. Lo que manda es lo
escrito aquí, y la forma la copia de la pantalla 4 (registro de glucosa), `node-id=7-2`:
<https://www.figma.com/design/TFOHJ9wm2lhsiEk1e3595A?node-id=7-2>

---

## 0. Antes de abrir Claude Code

### 0.1 La rama, antes que nada

```bash
cd ~/Documents/glucy-ios
git fetch origin
git switch -c feature/insulina origin/develop
git branch --show-current     # tiene que decir: feature/insulina
```

`origin/develop` ya tiene que llevar el modo oscuro fusionado. Si no, espérate.

### 0.2 Xcode no te pide nada, y esta vez de verdad

Los tres tipos de HealthKit que la app escribe —glucosa, carbohidratos e insulina— **ya se
piden juntos desde el paso 4**. Compruébalo y no toques nada más:

```bash
grep -n "toShare" Glucy/Data/HealthKit/HealthKitReal.swift
# tiene que decir: toShare: [tipoGlucosa, tipoCarbohidratos, tipoInsulina]
```

Por eso este paso puede escribir en Salud sin volver a pedirle permiso a la persona. Era la
razón de haberlo dejado para aquí y no haberlo hecho en el paso 6.

### 0.3 El iPhone

En Salud se comprueba lo que el simulador no: que la dosis aparezca con su razón de bolo o
basal, que escribirla dos veces no la duplique y que «Deshacer» la quite. Las cuatro
comprobaciones están en el apartado 8 bis.

---

## 1. Qué se construye en el paso 7, y por qué va ahora

El registro de insulina, y con él **la mitad que le faltaba al modelo**. El paso 1 ya dejó
escrita y probada la curva de insulina activa (`Insulina.iob`), con los mismos números que la
referencia en Python. Lo que no existe es la dosis que alimente esa curva: hoy `iob` siempre
devuelve cero porque no hay ninguna dosis guardada.

Al cerrar este paso, `COB` e `IOB` —las dos variables que más pesan en la predicción de los
dos modos— tienen por fin de dónde salir, y el paso 8 puede dibujar algo que signifique algo.

Y se cierra el pendiente que el paso 6 dejó a propósito: **escribir en Salud los carbohidratos
y la insulina**. Se hace aquí porque las dos escrituras comparten la misma autorización, y
pedirle permiso dos veces a la persona por dos pasos distintos es de mala educación.

---

## 1 bis. El requisito, pegado

### RF-14 (fase 1)

> El registro de insulina (unidades, tipo rápida o basal, hora) es parte central del flujo
> diario del usuario principal, y alimenta la estimación de insulina activa. Para el usuario
> secundario se puede ocultar desde ajustes.

Tres cosas salen de ahí y las tres son trabajo: las **unidades, el tipo y la hora**; que
**alimente el IOB**, que es lo que lo conecta con el paso 1; y que se pueda **ocultar**, que
es lo que lo conecta con el usuario secundario.

### Y el requisito no funcional que manda sobre todos los demás en este paso

> **Seguridad clínica.** El sistema registra la insulina que el usuario dice haberse
> aplicado; nunca calcula ni sugiere una dosis.

Es la regla 7 de las ocho que no se negocian, y es **la frontera con un dispositivo médico
regulado**. Un calculador de bolo es software médico y necesita certificación; un cuaderno
donde anotas lo que ya te pusiste, no. Todo este paso está del lado de acá de esa línea, y el
apartado 6 enumera lo que por eso no se construye.

### RF-15b (fase 1), que ya se cumplió para la glucosa y aquí aplica igual

> La app escribe en HealthKit solo las lecturas que ella misma capturó (manual y foto). Las
> que leyó del sensor comercial no se vuelven a escribir, para no duplicarlas.

---

## 2. Las seis decisiones del paso 7

### 2.1 La tercera migración: `motivo` opcional y el interruptor de ocultar

Dos campos no cuadran con lo que hace falta, y los dos se arreglan en la misma migración.

**`DosisInsulina.motivo` es obligatorio y el Documento 3 lo define opcional**
(`motivo (comida | correccion | programada, opcional)`). Con el modelo de hoy, la pantalla
tendría que inventar un motivo cuando la persona no lo diga, y **un motivo inventado es peor
que ninguno**: entra al histórico como si alguien lo hubiera afirmado. Es palabra por palabra
el mismo razonamiento por el que `ContextoComida` quedó opcional en el paso 1; se aplica
igual.

**`Perfil` no tiene con qué ocultar la insulina.** RF-14 lo pide y no hay dónde guardarlo.

```swift
// En DosisInsulina
var motivo: MotivoDosis?            // era MotivoDosis

// En Perfil
/// RF-14: el usuario secundario —prediabetes, resistencia a la insulina— no se aplica
/// insulina, y una pestaña que no usa nunca le estorba. Nace en `true` porque el usuario
/// principal es quien sí la usa.
var registraInsulina: Bool = true
```

```swift
nonisolated enum EsquemaGlucyV4: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(4, 0, 0) }
    static var models: [any PersistentModel.Type] { /* las mismas diez */ }
}

// Y una etapa ligera más, sin tocar las dos que ya están:
.lightweight(fromVersion: EsquemaGlucyV3.self, toVersion: EsquemaGlucyV4.self)
```

Ligera otra vez: un campo que pasa a opcional y uno nuevo con valor por omisión no necesitan
que nadie escriba cómo rellenar las filas viejas. **Las etapas de la V1 a la V3 se quedan como
están**; se agrega la cuarta al final de la lista.

### 2.2 En el modelo `bolo | basal`; en la pantalla «rápida (bolo)»

Esta es la contradicción **C-4** de `05-PENDIENTES-Y-CONTRADICCIONES.md` y se cierra aquí. El
reporte dice «rápida o basal»; el Documento 3 dice `bolo · basal`. Gana el Documento 3 en el
código, porque es lo que entiende HealthKit (`HKInsulinDeliveryReason` tiene `.bolus` y
`.basal`) y es lo que ya está escrito en `TipoInsulina`.

Y gana el reporte en la interfaz, porque «bolo» no es una palabra que use la gente:

| En el código | En la pantalla |
| --- | --- |
| `.bolo` | **Rápida** · debajo, en texto secundario: «la de las comidas (bolo)» |
| `.basal` | **Basal** · debajo: «la de todos los días (lenta)» |

**No se mezclan los dos nombres en el modelo.** Si en algún momento aparece un
`case rapida` en `TipoInsulina`, el paso está mal hecho.

### 2.3 El texto que marca la frontera, y dónde va

Es **el texto más importante de la aplicación**, y no puede estar en los créditos ni en una
pantalla de ayuda. Va en la propia pantalla de insulina, visible sin desplazar, con borde
ámbar y su icono, por encima del campo de unidades:

> **Glucy solo anota lo que tú te aplicaste.**
> No calcula ni sugiere dosis. Esa decisión es tuya y de tu médico.

Tres reglas sobre ese aviso:

1. **No se descarta.** No tiene «entendido», no tiene equis, no se encoge al segundo uso. Lo
   mismo que el aviso del modo sin sensor (RF-10b).
2. **No lleva el color como único portador de información** (regla de interfaz): borde ámbar,
   **más** icono, **más** las palabras. En escala de grises tiene que seguir leyéndose.
3. VoiceOver lo lee **antes** del campo de unidades, no después. El orden de lectura importa:
   quien no ve la pantalla tiene que oír la advertencia antes de escribir el número.

### 2.4 La dosis y los carbohidratos necesitan su UUID en Salud

`escribirGlucosa` ya guarda el UUID del registro como `HKMetadataKeySyncIdentifier`, y de ahí
salen dos cosas: escribir dos veces **reemplaza** en lugar de duplicar, y `eliminarGlucosa`
sabe cuál borrar sin poder tocar nunca una muestra del fabricante.

`escribirCarbohidratos` y `escribirInsulina` **no lo hacen**: reciben números sueltos
(`gramos:ts:` y `unidades:ts:tipo:`), no llevan identificador y no tienen un `eliminar`
hermano. Con eso, un «Deshacer» deja la muestra en Salud para siempre y un reintento la
duplica.

Se cambian para que reciban el `…Dato`, igual que la glucosa:

```swift
func escribirCarbohidratos(_ dato: ComidaDato) async throws
func eliminarCarbohidratos(uuid: UUID) async throws

func escribirInsulina(_ dato: DosisInsulinaDato) async throws
func eliminarInsulina(uuid: UUID) async throws
```

El metadato de la insulina sigue llevando `HKMetadataKeyInsulinDeliveryReason` —HealthKit
rechaza la muestra sin él— y se le suma el `HKMetadataKeySyncIdentifier` con el UUID. El
borrado filtra por `HKSource.default()` **y** por el identificador, las dos cosas, como el de
glucosa.

### 2.5 Un solo caso de uso que escribe en Salud, no tres

`EscribirEnHealthKit` ya existe y sabe de glucosa. En lugar de hacerle hermanos para comida y
dosis, se le agregan dos métodos: así la lista blanca de orígenes, la regla de no reescribir
lo del sensor y el «no lanzar nunca» viven en un solo archivo.

Y se mantiene la propiedad que hace seguro ese archivo: **nada de lo que hay ahí lanza**. Salud
es una copia; el teléfono es el dueño del dato (regla 1). Si Salud rechaza la escritura, la
dosis ya está guardada en el teléfono y la persona no tiene nada que corregir ni nada que
volver a teclear.

La escritura va **después** de guardar en el repositorio, nunca antes, y su fallo no deshace
el guardado local.

### 2.6 Lo que se arrastra del paso 5, y entra aquí porque ya lleva dos vueltas abierto

En `VisionOCR.numero(de:)` los dígitos se extraen con `candidato.string.filter(\.isNumber)`,
que **borra el separador decimal**. Dos consecuencias, las dos reales:

1. La comprobación de `SeleccionDeNumero.esCandidato` que descarta lo que no sea entero
   (`valor == valor.rounded()`) **no puede ser falsa nunca**, porque después de filtrar
   dígitos todo valor ya es entero. Es código muerto con apariencia de protección.
2. Un glucómetro en **mmol/L** que muestre `6.2` se lee como **62**, que cae dentro de 20–600
   y por tanto se propone. El valor de verdad son 112 mg/dL. La app propondría 62, que se lee
   como hipoglucemia, y es el peor sentido posible del error.

El arreglo: descartar la observación cuando su texto trae un separador decimal entre dos
dígitos, o un `:`. Lo segundo quita además las horas tipo `5:26`, que hoy se leen como 526 y
entran en rango.

Son diez renglones y dos pruebas. Si prefieres que vaya en su propia rama, dilo antes de
empezar; si no, va aquí.

---

## 3. Archivos que hay que crear o tocar

```
Glucy/
  Domain/
    Models/
      DosisInsulina.swift              motivo pasa a opcional
      Datos/DosisInsulinaDato.swift    igual
      Perfil.swift                     + registraInsulina
      Datos/PerfilDato.swift           igual
    Rules/
      Validacion.swift                 + validarDosis(...)
    UseCases/
      RegistrarDosis.swift             NUEVO · la única puerta
      EscribirEnHealthKit.swift        + carbohidratos y + insulina
      CalcularInsulinaActiva.swift     NUEVO · junta repositorio y regla
  Data/
    HealthKit/
      ServicioHealthKit.swift          firmas nuevas (2.4)
      HealthKitReal.swift              identificador de sincronización y borrados
    Repositories/
      RepositorioDosis.swift           + eliminar(uuid:) y + ultima()
    SwiftData/
      EsquemaGlucy.swift               + EsquemaGlucyV4 y su etapa
      EsquemasAnteriores.swift         la V3 congelada, como ya se hizo con la V2
      DosisSwiftData.swift             + eliminar
    OCR/
      VisionOCR.swift                  el arreglo de 2.6
  Features/
    RegistroInsulina/
      RegistroInsulinaView.swift       NUEVO
      RegistroInsulinaViewModel.swift  NUEVO
    Pestanas/
      SelectorDeRegistro.swift         + la tercera opción, y se esconde con el perfil

GlucyTests/
  RegistrarDosisTests.swift
  CalcularInsulinaActivaTests.swift
  MigracionEsquemaV4Tests.swift
  EscribirEnHealthKitTests.swift       se amplía el que ya existe
  SeleccionDeNumeroTests.swift         se amplía con los dos casos de 2.6
```

**No aparece `Theme.swift` en esa lista, y es a propósito.**

**Y una regla que dejó el modo oscuro, para la pantalla nueva:** `superficie` **solo va en
`.background`**. La letra y los iconos que van encima de un relleno de color —el botón
«Guardar», la franja de «dosis guardada»— llevan `Tema.Colores.textoSobreColor`. En oscuro la
superficie es casi negra, así que usarla como color de letra deja un botón azul con la letra
casi invisible. El token ya existe; no hay que agregar nada a `Theme.swift`.

---

## 4. Las firmas

```swift
/// Registrar una dosis que la persona **dice haberse aplicado**.
///
/// No hay ninguna función aquí que reciba una glucosa, un objetivo o unos carbohidratos y
/// devuelva unidades. No la hay y no la va a haber: eso es un calculador de bolo, es
/// software médico regulado, y es la regla 7.
nonisolated struct RegistrarDosis: Sendable {
    let repositorio: any RepositorioDosis
    var salud: EscribirEnHealthKit?

    /// - Parameter unidades: lo que la persona dice haberse aplicado, múltiplo de 0.5.
    /// - Parameter motivo: `nil` si no lo dijo. No se adivina (RF-37 es de comidas, pero el
    ///   principio es el mismo: lo que no se registró, no se infiere).
    /// - Parameter duracionAccionH: la del perfil **en el momento de aplicarse**. Se guarda
    ///   con la dosis para que el IOB del histórico no cambie si mañana el perfil la mueve.
    @discardableResult
    func ejecutar(
        unidades: Double,
        tsUtc: Date,
        tipo: TipoInsulina,
        motivo: MotivoDosis?,
        duracionAccionH: Double,
        ahora: Date = Date()
    ) async throws -> DosisInsulinaDato

    func deshacer(_ dato: DosisInsulinaDato) async throws
}
```

```swift
/// La insulina que todavía está trabajando, ahora mismo.
///
/// La curva ya está escrita y probada en `Insulina.iob` desde el paso 1, con los mismos
/// números que `referencia/reglas_clinicas.py`. Esto solo le da de comer.
nonisolated struct CalcularInsulinaActiva: Sendable {
    let dosis: any RepositorioDosis

    /// - Parameter ahora: se pasa, no se toma de `Date()` dentro, para poder probarlo.
    func ejecutar(ahora: Date) async throws -> Double
}
```

Dos detalles de ese cálculo que conviene no equivocar:

- Se piden las dosis de las **últimas ocho horas**, no de las cinco de la duración por
  omisión: el perfil admite hasta 8 (`duracionAccionConfigurableH = 2.0...8.0`) y cada dosis
  lleva la suya. Pedir cinco dejaría fuera insulina que sigue activa.
- **Cada dosis aporta con su propia `duracionAccionH`**, la que llevaba guardada, no con la
  del perfil de hoy. Es para eso que el campo existe en el modelo.

```swift
static func validarDosis(
    unidades: Double,
    tsUtc: Date,
    ahora: Date
) -> Rechazo?
```

Con los límites que ya están en `ConfiguracionDominio` y **nada escrito suelto**: unidades
0–50, múltiplo de `insulinaResolucionUI` (0.5), hora no futura. Una dosis de 0 unidades no es
una dosis: se rechaza con el mismo mensaje que un campo vacío.

---

## 5. La pantalla, de arriba abajo

1. El **aviso de la frontera** (2.3). Fijo, no descartable.
2. **Unidades.** Teclado decimal, el valor grande, con «UI» al lado. Más y menos de medio en
   medio a los lados, porque es una pluma y los valores reales son 2, 2.5, 4: teclear es más
   trabajo que tocar dos veces. El campo sigue aceptando que lo escribas.
3. **Tipo**, dos opciones del mismo tamaño, con la etiqueta de 2.2. **Ninguna preseleccionada**
   si es la primera dosis; después, la del último registro, que es lo que la persona hace casi
   siempre.
4. **Hora**, la actual, editable, como en glucosa.
5. **¿Por qué?**, los tres motivos, y **se puede no contestar**: es la línea que puede quedar
   en blanco (2.1). Debajo, en texto secundario: «Puedes dejarlo en blanco».
6. **Guardar**, un botón, 50 pt de alto.
7. Al guardar, la franja de **«Dosis guardada» con «Deshacer»** unos segundos. Deshacer es
   mejor que preguntar «¿estás seguro?», y aquí además quita la muestra de Salud.
8. Debajo, cuando hay insulina activa: **«Te quedan 2.4 UI trabajando»**, con la hora de la
   última dosis. Es una cifra, no un consejo, y no va seguida de ninguna recomendación.

El selector de la pestaña «Registrar» pasa a tener **tres** opciones: Glucosa · Comida ·
Insulina. Y si el perfil trae `registraInsulina == false`, la tercera **no se dibuja**: no
aparece en gris ni deshabilitada, no está. Una opción deshabilitada invita a preguntarse qué
falta.

---

## 6. Lo que este paso NO construye, y no es por falta de tiempo

Esta lista es parte del trabajo. Si algo de aquí aparece en el código, el paso está mal hecho
aunque compile, aunque pase las pruebas y aunque se vea bien.

- **Ningún campo de «ratio de carbohidratos» ni de «factor de sensibilidad».** Son las dos
  entradas de un calculador de bolo. No se piden, no se guardan, no se calculan.
- **Ninguna función que devuelva unidades.** Ni a partir de la glucosa, ni de los
  carbohidratos, ni de un objetivo, ni de las tres.
- **Ninguna frase que diga cuánto aplicarse**, ni envuelta en condicional, ni «otras personas
  suelen», ni «con estos carbohidratos normalmente». Ni en la interfaz, ni en un comentario
  del código que alguien pueda convertir en función mañana.
- **Ningún aviso de «te falta insulina» o «te sobra».** El IOB se enseña como número y nada
  más.
- **Nada de dosis programadas ni recordatorios de basal.** Eso es RF-18 y es fase 3.
- Leer insulina **desde** HealthKit. La app escribe insulina, no la lee: lo que otra app
  escribió no lo capturó Glucy, y la persona no lo confirmó aquí.
- El interruptor de ocultar **en la pantalla de Ajustes**. El campo del perfil sí; la pantalla
  es el paso 9. Mientras tanto se prueba cambiando el perfil.

---

## 7. Textos, palabra por palabra

| Situación | Texto |
| --- | --- |
| Aviso fijo, título | «Glucy solo anota lo que tú te aplicaste.» |
| Aviso fijo, cuerpo | «No calcula ni sugiere dosis. Esa decisión es tuya y de tu médico.» |
| Campo | «¿Cuántas unidades te aplicaste?» |
| Tipo, opción 1 | «Rápida» · «la de las comidas (bolo)» |
| Tipo, opción 2 | «Basal» · «la de todos los días (lenta)» |
| Motivo | «¿Por qué? (puedes dejarlo en blanco)» · «Por una comida» · «Para corregir» · «Es la de siempre» |
| Unidades vacías o cero | «Escribe cuántas unidades te aplicaste.» |
| Más de 50 | «Esa cantidad está fuera de lo que Glucy registra. Revisa el número.» |
| No múltiplo de 0.5 | «Las plumas dosifican de media en media unidad. Prueba con 2.5.» |
| Hora futura | «Esa hora todavía no llega. Revisa la fecha.» |
| Al guardar | «Dosis guardada» + «Deshacer» |
| Insulina activa | «Te quedan 2.4 UI trabajando · última dosis a las 14:30» |
| Sin insulina activa | «No te queda insulina trabajando» |

Nótese que **ningún mensaje de error dice qué hacer con el cuerpo**: dicen qué hacer con el
campo. «Revisa el número», no «ponte menos».

---

## 8. Las pruebas que tienen que pasar

| # | Qué prueba | Requisito |
| --- | --- | --- |
| 1 | 4 UI de bolo se guardan con su hora, su tipo y su zona horaria | RF-14 |
| 2 | el motivo se puede dejar en `nil` y la dosis se guarda igual | RF-14 |
| 3 | 0 unidades no se guarda | RF-14 |
| 4 | 60 unidades no se guarda | RF-14 |
| 5 | 2.3 unidades no se guarda: no es múltiplo de 0.5 | RF-14 |
| 6 | una hora futura no se guarda | RF-05 |
| 7 | la dosis guarda la duración de acción **del momento**, no la de después | RF-14 |
| 8 | mover la duración del perfil **no** cambia el IOB de una dosis ya guardada | RF-14 |
| 9 | una dosis de 4 UI hace cuatro horas da el mismo IOB que la referencia en Python | RF-14 |
| 10 | dos dosis a distinta hora suman su IOB | RF-14 |
| 11 | una dosis de hace nueve horas aporta cero | RF-14 |
| 12 | con dos dosis de distinta duración, cada una usa la suya | RF-14 |
| 13 | el cálculo pide ocho horas de dosis, no cinco | RF-14 |
| 14 | la dosis se escribe en Salud con su UUID como identificador | RF-15, 2.4 |
| 15 | escribirla dos veces no crea dos muestras | RF-15b |
| 16 | «Deshacer» borra la dosis y la quita de Salud | RF-15b |
| 17 | si Salud lanza, la dosis **sigue guardada** y no sube el error | regla 1 |
| 18 | una comida se escribe en Salud como carbohidratos, con su UUID | RF-15 |
| 19 | con `registraInsulina == false` el selector no dibuja la opción | RF-14 |
| 20 | la base V3 se abre con la V4 sin perder filas | — |
| 21 | una dosis migrada de la V3 conserva su motivo | — |
| 22 | un perfil migrado de la V3 queda con `registraInsulina == true` | — |
| 23 | **no existe ninguna forma de crear una `DosisInsulina` sin `RegistrarDosis`** | regla 7 |
| 24 | «6.2» en la pantalla del glucómetro **no** se propone como 62 | 2.6 |
| 25 | «5:26» no se propone como 526 | 2.6 |

La 9 es la que importa más: **el número tiene que coincidir con
`referencia/reglas_clinicas.py` de glucy-backend**, que es la especificación ejecutable. Si el
Swift y esa referencia no coinciden, uno de los dos está mal.

La 23 es un `grep`: `DosisInsulina(` fuera de `DosisSwiftData` y de las pruebas tiene que
salir vacío.

### 8 bis. En el iPhone físico

- [ ] Una dosis de 4 UI de rápida aparece en Salud **como bolo**, no como basal
- [ ] Guardar, deshacer y volver a guardar deja **una** muestra en Salud, no tres
- [ ] Una comida guardada aparece en Salud como carbohidratos
- [ ] Con la letra de accesibilidad más grande, el aviso de la frontera **no se corta** (P-15)

La última no es de adorno: es el texto que marca la frontera legal del proyecto, y un texto
cortado a la mitad puede acabar diciendo lo contrario de lo que dice.

---

## 9. Cómo se sabe que el paso 7 está hecho

- Las 25 pruebas pasan, más las de los pasos anteriores.
- La integración continua está verde **antes** de fusionar.
- `grep -rn "ratio\|sensibilidad\|factorCorreccion\|calcularDosis\|sugerirDosis" Glucy/` no
  devuelve nada.
- `grep -rn "Theme" Glucy/Features/RegistroInsulina/` usa solo tokens, ningún hex suelto.
- `git diff --stat origin/develop -- Glucy/App/Theme/ Glucy/Features/RegistroComida/`
  está vacío: este paso no toca ni el tema ni la pantalla de comidas.
- Una dosis guardada mueve el número de insulina activa, y ese número coincide con la
  referencia en Python.
- En Salud se ve la dosis con su razón, y «Deshacer» la quita.

---

## 10. Lo que NO entra en el paso 7

Además de todo el apartado 6:

- La pantalla de Ajustes con el interruptor (paso 9).
- El tipo de insulina ultrarrápida con su pico de 55 minutos. La constante ya existe en
  `ConfiguracionDominio`; elegirla desde el perfil es del paso 9.
- Gráficas del IOB a lo largo del día. Paso 8.
- Subir nada al backend: aquí solo se encola.

---

## 11. Git

```bash
git switch -c feature/insulina origin/develop
# …trabajo…
git add -A
git commit -m "feat: registro de insulina con cálculo de insulina activa"
git push -u origin feature/insulina
gh pr create --base develop --head feature/insulina --web
```

**El pull request va contra `develop`.** Y esta vez **espera a que la integración continua
termine antes de fusionar**: ya lleva tres pasos seguidos fusionados en verde-no-comprobado,
y el 26 de septiembre eso dejó una semana de código sin validar en `develop`.

---

## 11 bis. El cuerpo del pull request, ya escrito

```markdown
## Antes

Glucy sabía cuánta glucosa tenías y qué habías comido, pero no qué insulina te habías
aplicado. La curva de insulina activa estaba escrita y probada desde el primer paso, y
devolvía siempre cero porque no había ninguna dosis que meterle. La pestaña de registro
ofrecía glucosa y comida.

## Después

Se puede registrar una dosis: las unidades, si fue rápida o basal, la hora y, si se quiere, el
motivo. El motivo se puede dejar en blanco, porque un motivo inventado entra al histórico como
si alguien lo hubiera afirmado.

Arriba de todo, fijo y sin forma de descartarlo, el aviso de que **Glucy solo anota lo que tú
te aplicaste y no calcula ni sugiere dosis**. Es la frontera con un dispositivo médico
regulado y por eso está en la pantalla y no en los créditos.

Debajo del formulario, cuánta insulina te queda trabajando, con la hora de la última dosis. Es
una cifra y no va seguida de ninguna recomendación.

Y lo que el paso de comidas había dejado pendiente a propósito: **la comida y la dosis ahora se
escriben en Salud**, los carbohidratos como carbohidratos y la insulina con su razón de bolo o
basal. Se hace aquí porque las dos comparten la misma autorización que se pide una sola vez.

Quien no se aplica insulina puede ocultar todo esto: con el interruptor del perfil en `false`
la opción no se dibuja, ni en gris ni deshabilitada.

## Cómo

`RegistrarDosis` es la única puerta: no existe ninguna otra forma de crear una
`DosisInsulina`, y no hay ni una función en todo el cambio que reciba una glucosa o unos
carbohidratos y devuelva unidades. Tampoco hay campos de ratio ni de factor de sensibilidad,
que son las dos entradas de un calculador de bolo.

Cada dosis guarda la duración de acción vigente **en el momento de aplicarse**, así que mover
ese valor en el perfil no cambia el histórico. El cálculo de insulina activa pide ocho horas de
dosis, no cinco, porque el perfil admite hasta ocho y cada dosis aporta con la suya.

`escribirCarbohidratos` y `escribirInsulina` ahora reciben el registro completo y guardan su
UUID como identificador de sincronización en Salud, igual que la glucosa desde el paso 4. De
ahí salen dos cosas: escribir dos veces reemplaza en lugar de duplicar, y «Deshacer» sabe cuál
muestra borrar sin poder tocar nunca una del fabricante.

`motivo` pasa a opcional y `Perfil` gana el interruptor, así que el cambio trae la tercera
migración del esquema, `EsquemaGlucyV4`, con una etapa ligera más y las anteriores intactas.

Va además el arreglo del OCR que quedó señalado en el paso 5: al extraer los dígitos se
borraba el separador decimal, con lo que un glucómetro en mmol/L que mostrara 6.2 se proponía
como 62 mg/dL, que se lee como hipoglucemia.

## Requisitos que cubre

- **RF-14** — unidades, tipo y hora; alimenta la insulina activa; se puede ocultar.
- **RF-15** — la insulina y los carbohidratos se escriben en HealthKit.
- **RF-15b** — solo lo que Glucy capturó, y sin duplicar.
- **C-4** — `bolo | basal` en el modelo, «rápida (bolo)» en la pantalla.
- **Regla 7** — la app registra; nunca calcula ni sugiere una dosis.

## Comprobado

- [ ] Las pruebas pasan en local (<número> en total)
- [ ] La integración continua está en verde **antes** de fusionar
- [ ] No se agregó ninguna llave, token ni dato personal al repositorio
- [ ] No hay ninguna función que devuelva unidades de insulina
- [ ] `DosisInsulina(` no se construye fuera de `DosisSwiftData` y las pruebas
- [ ] Este cambio no toca `Theme.swift` ni la pantalla de comidas

En el iPhone físico:

- [ ] La dosis aparece en Salud como bolo, no como basal
- [ ] Guardar, deshacer y volver a guardar deja una sola muestra
- [ ] Una comida aparece en Salud como carbohidratos
- [ ] Con la letra más grande, el aviso de la frontera no se corta
```

---

## 12. El texto para pegarle a Claude Code

> Lee `CLAUDE.md` y `docs/paso-7-insulina.md`. Haz el paso 7 completo en una rama
> `feature/insulina`: el caso de uso `RegistrarDosis`, la validación, `CalcularInsulinaActiva`,
> la pantalla de insulina con su aviso fijo, la tercera opción del selector, las firmas nuevas
> de HealthKit con el identificador de sincronización, la migración del esquema a la V4 y las
> 25 pruebas.
>
> Lo que no se negocia es casi todo este paso, porque es donde está la frontera legal del
> proyecto. **No escribas ni una función que reciba una glucosa, unos carbohidratos o un
> objetivo y devuelva unidades de insulina**, ni campos de ratio de carbohidratos o factor de
> sensibilidad, ni una frase en la interfaz que diga cuánto aplicarse, ni envuelta en
> condicional. Glucy anota lo que la persona dice haberse aplicado y nada más: es la regla 7 y
> es lo que separa esta app de un dispositivo médico regulado. El apartado 6 del documento
> tiene la lista completa y es parte del trabajo, no una advertencia.
>
> El aviso de la pantalla va **fijo y no descartable**, arriba del campo de unidades, y
> VoiceOver lo lee antes que el campo. En el modelo el tipo es `bolo | basal`; en la pantalla
> se llama «Rápida» y «Basal». El motivo **se puede dejar en blanco** y no se adivina. Cada
> dosis guarda la duración de acción del momento, y el cálculo de insulina activa pide ocho
> horas de dosis, no cinco.
>
> **No toques `Theme.swift` ni nada de `Features/RegistroComida/`**: son del trabajo del modo
> oscuro, que ya está fusionado en `develop`. Si crees que necesitas un color que no existe,
> para y dímelo. De los que ya existen: `superficie` **solo va en `.background`**; la letra y
> los iconos encima de un relleno de color llevan `Tema.Colores.textoSobreColor`.
>
> La migración agrega una etapa ligera más sin tocar las de la V2 y la V3. La rama sale de
> `develop` —con el modo oscuro ya dentro— y el pull request va contra `develop`, con el cuerpo
> del apartado 11 bis. **Corre las pruebas y espera a que la integración continua esté verde
> antes de decirme que terminaste**, y dime cuántas pasaron.
