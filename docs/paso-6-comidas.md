# Paso 6 — Comidas por código de barras

Documento de trabajo para Claude Code. Sexto de los diez pasos de la fase 1
(`glucy-base/04-PLAN-FASE-1.md`).

Lo que había antes de este paso: la glucosa se captura por las tres vías —a mano, del sensor
por HealthKit y por foto del glucómetro— y todo queda guardado en el teléfono. Lo que falta
para que el COB del paso 1 tenga con qué trabajar son las comidas, y este paso las trae.

Diseño de la pantalla: <https://www.figma.com/design/TFOHJ9wm2lhsiEk1e3595A?node-id=8-2>
(pantalla 5, «Registro de comida»). El enlace es para que tú compares; Claude Code no puede
abrirlo, así que lo que manda es lo escrito aquí.

---

## 0. Antes de abrir Claude Code

### 0.1 La rama, antes que nada

```bash
cd ~/Documents/glucy-ios
git fetch origin
git switch -c feature/comidas origin/develop
git branch --show-current     # tiene que decir: feature/comidas
```

### 0.2 Xcode: solo un texto que hay que corregir

No hay capacidad que marcar. Pero **el texto del permiso de cámara del paso 5 quedó
incompleto**: dice que la cámara se usa para leer la pantalla del glucómetro, y desde este
paso también se usa para el código de barras y para la etiqueta nutrimental. iOS enseña ese
texto tal cual en el diálogo del permiso, así que mentiría.

```
INFOPLIST_KEY_NSCameraUsageDescription = "Glucy usa la cámara para leer el número de tu
glucómetro, el código de barras de un producto y su tabla nutrimental. Las fotos se procesan
en tu teléfono y no se guardan ni se suben."
```

**En las dos configuraciones, Debug y Release.** Sigue siendo el error que ya costó tres
veces en este proyecto.

```bash
grep -c "INFOPLIST_KEY_NSCameraUsageDescription" Glucy.xcodeproj/project.pbxproj   # 2
```

### 0.3 El iPhone

El escáner de código de barras **no funciona en el simulador**: no hay cámara que apuntar a
un producto. La consulta a Open Food Facts sí se puede probar en el simulador, y el OCR de la
etiqueta también sobre una imagen ya cargada. Deja para el iPhone las cuatro comprobaciones
del apartado 8 bis.

---

## 1. Qué se construye en el paso 6, y por qué va ahora

Tres vías para llegar a un número de carbohidratos, en cascada, cada una respaldando a la
anterior:

1. **Código de barras** → Open Food Facts → carbohidratos por 100 g → por porción.
2. **Foto de la etiqueta nutrimental** → el OCR del paso 5 → los gramos de carbohidratos.
3. **A mano** → los gramos, que es lo que nunca falla.

Va después de la foto del glucómetro porque **reutiliza el OCR que ese paso construyó**, y va
antes de la insulina porque el COB es la mitad de las características del modelo y la comida
es el registro que más veces al día hace una persona.

Este paso es también el primero que **sale a internet**. Todo lo anterior funciona en un
teléfono en modo avión, y eso no cambia: si la red no está, la cascada baja al siguiente
escalón y la comida se registra igual (RF-20, caso P-07).

---

## 1 bis. Los cuatro requisitos, pegados

### RF-12 (fase 1)

> El usuario registra una comida escaneando el código de barras, resuelto contra Open Food
> Facts.

### RF-12b (fase 1)

> Cada comida guarda un tiempo de absorción en minutos, con 180 por omisión. **La app no lo
> pregunta salvo que el usuario elija ajustarlo**, y entonces ofrece tres opciones: 30
> minutos (rápida), 180 (normal) y 300 (lenta).

**Ojo con la frase de en medio, porque contradice cómo se lee la pantalla 5 de un vistazo.**
Los tres botones de absorción **no** están a la vista con 180 marcado: 180 se aplica solo, en
silencio, y los tres botones viven detrás de un renglón que dice «Absorción: normal, 3 horas ·
Ajustar». Quien no toca nada no ve una decisión que tomar, que es justo lo que pide el
requisito. El texto que explica qué pasa si no se toca va debajo de ese renglón, siempre
visible.

### RF-13 (fase 1)

> Si el producto no existe en Open Food Facts, el usuario fotografía la tabla nutricional y
> el OCR extrae los carbohidratos.

### RF-37 (fase 2 en el servidor, pero la app es donde se cumple o se rompe)

> El sistema no infiere comidas no registradas: no las deduce de una subida de glucosa ni las
> marca como probables. Si no hay registro, no hay dato. Lo que falte se le pregunta al
> usuario en el momento en que registra.

**Qué lo cumple aquí:** que no exista ni una función que cree una `Comida` sin que alguien
haya tocado un botón. Ni una comida «sugerida», ni una en gris «¿comiste algo aquí?», ni un
valor por omisión que rellene los carbohidratos. Lo que falta se pregunta **en el momento**, y
si la persona no contesta, no hay comida.

---

## 2. Las cinco decisiones del paso 6

### 2.1 La segunda migración del esquema: falta `porciones`

`Comida` tiene `porcionG` —cuántos gramos trae una porción— pero **no tiene `porciones`**,
cuántas porciones se comió la persona. Son dos cosas distintas y las dos hacen falta:

```
carbsG = carbsPor100g / 100 × porcionG × porciones
```

El Documento 3 lo pide así: `porciones` (> 0, obligatorio en la vía de código de barras). Y
es el error de captura más común de toda la app: media bolsa y dos bolsas del mismo producto
dan el mismo código de barras y cuatro veces de diferencia en el COB.

```swift
nonisolated enum EsquemaGlucyV3: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(3, 0, 0) }
    static var models: [any PersistentModel.Type] { /* las mismas diez */ }
}

nonisolated enum PlanMigracionGlucy: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [EsquemaGlucyV1.self, EsquemaGlucyV2.self, EsquemaGlucyV3.self]
    }
    static var stages: [MigrationStage] {
        [.lightweight(fromVersion: EsquemaGlucyV1.self, toVersion: EsquemaGlucyV2.self),
         .lightweight(fromVersion: EsquemaGlucyV2.self, toVersion: EsquemaGlucyV3.self)]
    }
}
```

`porciones: Double` con valor por omisión `1`, no opcional: una comida sin porciones no
significa nada, y con `1` las filas que ya existan siguen dando el mismo `carbsG`. Etapa
ligera, como la del paso 5.

**Lo que NO se agrega, y está decidido:** `proteina_g`, `grasa_g` y `fibra_g`. El Documento 3
los lista, pero nada de la fase 1 los lee, el COB solo usa carbohidratos (D-8, RF-24b) y los
juegos de características del modelo no los incluyen. El requisito no funcional de
minimización dice que solo se recolecta lo que alimenta al modelo. Si los quieres para que la
tabla del reporte cuadre campo por campo con el Documento 3, **van en esta misma V3 y no en
una V4 después**: dímelo antes de empezar el paso, no a la mitad.

### 2.2 Open Food Facts detrás de un protocolo, en `Data/Network/`

Mismo motivo que HealthKit en el paso 4 y Vision en el paso 5, y aquí con uno más: **las
pruebas no pueden pegarle al servicio de verdad**. El límite es de 15 consultas por minuto y
por IP, y una suite que corre en cada pull request lo quemaría; además la integración continua
no tiene red garantizada, y una prueba que depende de internet falla por razones que no son el
código.

```
Glucy/Data/Network/
  ServicioProductos.swift      el protocolo + el struct Producto
  OpenFoodFactsHTTP.swift      la implementación de verdad
  ErrorProductos.swift
GlucyTests/Dobles/
  ProductosFalso.swift         devuelve lo que la prueba le diga, incluido fallar
```

La petición, tal cual:

```
GET https://world.openfoodfacts.org/api/v2/product/{codigo}.json
    ?fields=code,product_name,brands,nutriments,serving_size
```

Sin autenticación, pero **con `User-Agent` propio obligatorio**: una petición sin él puede
quedar bloqueada.

```
User-Agent: Glucy/1.0 (<un correo de contacto>)
```

**Ese correo lo pones tú, y piénsalo:** el repositorio es público, así que va a quedar
indexado. Si no quieres tu correo personal ahí, crea uno para el proyecto. No lo escribas en
el código suelto; que salga de una constante en un solo archivo, junto a la URL base.

Tiempo de espera **5 segundos**, no el que traiga el sistema. Nadie de pie en una cocina espera
treinta segundos a que cargue una bolsa de pan, y la siguiente vía —la foto de la etiqueta—
está ahí mismo. Pasados los 5 segundos se baja de escalón y ya.

### 2.3 El escáner: `AVCaptureMetadataOutput`, no `DataScannerViewController`

VisionKit trae un escáner ya hecho, con su recuadro y su resaltado. Pero exige comprobar
`isSupported` y `isAvailable`, no corre en todos los dispositivos y obliga a escribir de todas
formas un camino alterno para cuando dice que no. `AVCaptureMetadataOutput` con
`metadataObjectTypes = [.ean13, .ean8, .upce]` funciona en cualquier iPhone con cámara, no
necesita comprobación previa y son treinta renglones envueltos en un `UIViewRepresentable`,
igual que la cámara del paso 5.

Un camino menos que probar vale más aquí que un recuadro más bonito.

### 2.4 El dígito verificador se comprueba en el teléfono, antes de consultar

Un EAN-13 mal leído es un código que no existe, y consultarlo gasta una de las 15 del minuto
para recibir un «no lo tengo» que ya se podía saber. El dígito verificador se calcula en el
teléfono y, si no cuadra, se vuelve a leer sin salir a la red.

Va en `Domain/Rules/CodigoBarras.swift`, no en `Data/`: es una regla, no tiene nada de red y
se prueba con una lista de códigos escritos a mano.

```swift
nonisolated enum CodigoBarras {
    /// EAN-13 y EAN-8 con su dígito verificador correcto. Un código mal leído se descarta
    /// aquí y no gasta una de las 15 consultas por minuto de Open Food Facts.
    static func esValido(_ codigo: String) -> Bool
}
```

El cálculo del EAN-13: los doce primeros dígitos, sumando los de posición impar por 1 y los de
posición par por 3; el verificador es lo que falta para el siguiente múltiplo de diez.

### 2.5 El OCR del paso 5 no alcanza: hay que extenderlo

`ServicioOCR` devuelve **números** (`numerosEn(imagen:)`), y en una etiqueta nutrimental los
números solos no sirven: hay que saber cuál está en el renglón que dice «Hidratos de carbono».
Hace falta el texto.

La extensión es **aditiva**, no un cambio: se agrega un método al protocolo y las pruebas del
paso 5 siguen pasando tal como están.

```swift
nonisolated struct TextoLeido: Sendable, Equatable {
    let texto: String
    let confianza: Double
    let caja: CGRect
}

nonisolated protocol ServicioOCR: Sendable {
    func numerosEn(imagen: Data) async throws -> [NumeroLeido]
    /// Los renglones tal como los leyó, sin interpretar nada.
    func textosEn(imagen: Data) async throws -> [TextoLeido]
}
```

Y en `Data/OCR/` una regla nueva, hermana de `SeleccionDeNumero`:

```swift
nonisolated enum SeleccionDeCarbohidratos {
    /// Los gramos de carbohidratos por 100 g que dice la etiqueta, o `nil`.
    static func gramos(entre renglones: [TextoLeido]) -> Double?
}
```

Cómo decide, y el orden importa:

1. Busca el renglón que contenga, sin acentos y sin distinguir mayúsculas, alguna de:
   «hidratos de carbono», «carbohidratos», «carbohydrate», «glucidos». Las etiquetas mexicanas
   dicen «Hidratos de carbono»; las importadas, cualquiera de las otras.
2. **Descarta el que además diga «azúcares», «sugars», «fibra» o «fiber»**: en la tabla
   mexicana los azúcares y la fibra son renglones sangrados debajo de los hidratos de carbono,
   y confundirlos subestima los carbohidratos, que es el error que más daño hace.
3. En ese renglón, el número; y si el renglón no trae número —las tablas en columnas ponen el
   nombre a la izquierda y la cifra a la derecha, en observaciones distintas— el número cuya
   caja se solape verticalmente con ese renglón y esté a su derecha.
4. Si no encuentra nada, `nil`, y eso es la captura manual (RF-13 lleva a la tercera vía).

**Aquí también la confianza no decide nada** (D-11): el número que salga de la etiqueta se
enseña y se confirma, exactamente igual que el del glucómetro.

---

## 3. Archivos que hay que crear

```
Glucy/
  Domain/
    Rules/
      CodigoBarras.swift                   el dígito verificador
      Validacion.swift                     + validarComida(...)
    UseCases/
      BuscarProductoPorCodigo.swift         consulta + caché
      RegistrarComida.swift                 el único camino al repositorio
  Data/
    Network/
      ServicioProductos.swift
      OpenFoodFactsHTTP.swift
      ErrorProductos.swift
    OCR/
      SeleccionDeCarbohidratos.swift
      ServicioOCR.swift                     + textosEn(imagen:)
      VisionOCR.swift                       + textosEn(imagen:)
    Repositories/
      RepositorioComidas.swift              + eliminar(uuid:) y porCodigo(...)
      RepositorioProductos.swift            la caché, nueva
    SwiftData/
      EsquemaGlucy.swift                    + EsquemaGlucyV3 y su etapa
      ProductosSwiftData.swift              nuevo @ModelActor
      ComidasSwiftData.swift                + eliminar
  Features/
    RegistroComida/
      RegistroComidaView.swift
      RegistroComidaViewModel.swift
      EscanerCodigoView.swift               UIViewRepresentable
      ConfirmarProductoView.swift

GlucyTests/
  CodigoBarrasTests.swift
  SeleccionDeCarbohidratosTests.swift
  BuscarProductoPorCodigoTests.swift
  RegistrarComidaTests.swift
  MigracionEsquemaV3Tests.swift
  Dobles/ProductosFalso.swift
  Recursos/etiqueta-mexicana.png
  Recursos/etiqueta-en-columnas.png
```

---

## 4. Los dos protocolos nuevos

```swift
/// Lo que Open Food Facts contestó, ya traducido a lo que la app necesita.
nonisolated struct Producto: Sendable, Equatable {
    let codigoBarras: String
    let nombre: String
    let marca: String?
    /// Carbohidratos por 100 g, como los publica la fuente.
    let carbsPor100g: Double
    /// Los gramos de una porción, **solo si la fuente los dio en gramos**. Ver 5.2.
    let porcionSugeridaG: Double?
}

nonisolated protocol ServicioProductos: Sendable {
    /// `nil` cuando la fuente contesta que no conoce el código, o lo conoce y no trae
    /// carbohidratos. Lanza cuando no se pudo preguntar (sin red, tiempo agotado, 5xx).
    ///
    /// La diferencia importa: «no lo conozco» y «no pude preguntar» llevan al mismo sitio
    /// para la persona —la foto de la etiqueta— pero uno se puede cachear y el otro no.
    func producto(codigo: String) async throws -> Producto?
}

nonisolated enum ErrorProductos: Error, Equatable {
    case sinRed
    case tiempoAgotado
    case respuestaIlegible
    case fuenteFallo(codigoHttp: Int)
}
```

```swift
nonisolated protocol RepositorioProductos: Sendable {
    func porCodigo(_ codigo: String) async throws -> ProductoCacheDato?
    func guardar(_ dato: ProductoCacheDato) async throws
}
```

Y a `RepositorioComidas` le faltan dos:

```swift
/// Para el «Deshacer» de la franja de confirmación.
func eliminar(uuid: UUID) async throws
/// La última comida registrada con ese código, para ofrecer las mismas porciones.
func ultimaConCodigo(_ codigo: String) async throws -> ComidaDato?
```

---

## 5. El flujo, escalón por escalón

### 5.1 La cascada

```
[Escanear]
   │  código válido (dígito verificador en el teléfono)
   ▼
¿está en ProductoCache?  ── sí ──► producto, sin salir a la red
   │ no
   ▼
GET Open Food Facts, 5 s de espera
   │
   ├─ producto con carbohidratos ──► se guarda en la caché ──► producto
   ├─ status 0, o sin carbohidratos ──► se cachea el «no lo tengo» ──┐
   └─ lanza (sin red, 5xx, tiempo agotado) ──────────────────────────┤
                                                                     ▼
                                              «Este código no está en la base.
                                               Toma una foto de la etiqueta.»
                                                          │
                                                          ▼
                                            Foto de la etiqueta → OCR → gramos
                                                          │ nil
                                                          ▼
                                              Campo de gramos, teclado abierto
```

**Nunca hay un callejón sin salida.** Los tres escalones terminan en el mismo sitio: el
número de carbohidratos en un campo, a la vista, esperando que la persona toque «Guardar».
Ese es el caso **P-10** y hay que poder demostrarlo con el wifi apagado.

### 5.2 La trampa de la porción, que es la que puede hacer daño

Open Food Facts da los carbohidratos **por 100 g**. Lo que la persona se comió casi nunca son
100 g. El campo `serving_size` es **texto libre**: «30 g», «1 taza (240 ml)», «2 galletas»,
vacío.

Las reglas, y no se negocian:

- Si `serving_size` se puede leer como gramos, se ofrece como porción **ya escrita en el
  campo, visible y editable**.
- Si no se puede, **el campo de gramos por porción sale vacío y no se puede guardar hasta que
  tenga un número**. Lo que falta se pregunta en el momento (RF-37).
- **Nunca, en ningún caso, se supone 100 g.** Si la porción de verdad son 30 g, suponer 100
  triplica los carbohidratos, y esos carbohidratos entran al COB, y el COB entra a la
  predicción. Es la clase de error que se ve tres semanas después como «el modelo no sirve».
- La cifra de carbohidratos que resulta **se enseña calculada, con sus tres factores a la
  vista**: «45 g de carbohidratos · 30 g por porción × 2 porciones · 75 g por 100 g».

### 5.3 El único camino al repositorio

Igual que en el paso 5: una sola puerta.

```swift
nonisolated struct RegistrarComida: Sendable {
    let repositorio: any RepositorioComidas

    /// - Parameter carbsG: los gramos que la persona confirmó. **Es el dato.**
    /// - Parameter origen: `.barcode`, `.ocrEtiqueta` o `.manual`, según de dónde salió el
    ///   número, no dónde se tocó el botón (regla 4).
    func ejecutar(
        carbsG: Double,
        tsUtc: Date,
        origen: Origen,
        tiempoAbsorcionMin: Int = ConfiguracionDominio.absorcionPorOmisionMin,
        descripcion: String? = nil,
        codigoBarras: String? = nil,
        nombreProducto: String? = nil,
        porcionG: Double? = nil,
        porciones: Double = 1,
        ahora: Date = Date()
    ) async throws -> ComidaDato

    func deshacer(_ dato: ComidaDato) async throws
}
```

No existe ninguna otra función que escriba una `Comida`. Ni la vista, ni el ViewModel, ni el
caso de uso de la búsqueda.

### 5.4 La validación que hay que agregar

`Validacion` solo sabe de lecturas. Le falta:

```swift
static func validarComida(
    carbsG: Double,
    tiempoAbsorcionMin: Int,
    porciones: Double,
    tsUtc: Date,
    ahora: Date
) -> Rechazo?
```

Con los límites que ya están en `ConfiguracionDominio` y **nada escrito suelto aquí**:
carbohidratos 0–300 g, absorción 30–300 min, porciones > 0, hora no futura.

Un detalle del paso 1 que se cierra aquí: el COB en Swift devuelve los carbohidratos
completos cuando le pasan minutos negativos, y la referencia en Python lanza. Con la hora
futura rechazada antes de guardar, el caso ya no puede llegar al COB desde la app. Deja el
comentario que lo diga, porque la divergencia con la referencia sigue existiendo y alguien la
va a encontrar.

---

## 6. La absorción, tal como la pide RF-12b

Lo que se ve sin tocar nada, un renglón:

> Absorción: normal, 3 horas · **Ajustar**

Y debajo, siempre visible, en texto secundario:

> Si no lo cambias, Glucy cuenta estos carbohidratos repartidos en 3 horas.

Al tocar «Ajustar», los tres chips, con 180 ya marcado:

| Chip | Minutos | Texto de apoyo |
| --- | --- | --- |
| Rápida | 30 | «Jugo, refresco, algo dulce solo» |
| **Normal** | **180** | «Una comida como las de siempre» |
| Lenta | 300 | «Mucha grasa o mucha fibra: pizza, tacos, guisado» |

Los minutos se guardan **en la comida**, no solo en el perfil, porque el histórico tiene que
poder recalcularse con el valor que estaba vigente. El campo ya existe.

---

## 7. Textos, palabra por palabra

| Situación | Texto |
| --- | --- |
| Botón de la vía | «Escanear código de barras» |
| Mientras escanea | «Apunta al código de barras del producto» |
| Buscando | «Buscando el producto…» |
| Código mal leído | «No alcancé a leer el código. Acércate un poco más.» |
| Producto no encontrado | «Este código no está en la base. Toma una foto de la etiqueta nutrimental.» |
| Sin red | «No pude consultar ahora. Toma una foto de la etiqueta nutrimental.» |
| Etiqueta ilegible | «No alcancé a leer los carbohidratos. Puedes escribirlos tú.» |
| Porción desconocida | «¿Cuántos gramos trae una porción? Viene en la etiqueta.» |
| Al guardar | «Comida guardada» + «Deshacer» |
| Atribución, al pie de la ficha | «Datos del producto: Open Food Facts (ODbL). Pueden estar incompletos.» |

La atribución **no va en los créditos de Ajustes**: va en la pantalla que usa el dato, que es
lo que pide la licencia y lo que además es honesto, porque esos datos los captura gente
voluntaria y pueden estar mal.

Ninguno de estos textos es un error de sistema. «No pude consultar ahora» no es «error de
conexión»: sin conexión es una condición normal y la app sigue completa.

---

## 8. Las pruebas que tienen que pasar

| # | Qué prueba | Requisito |
| --- | --- | --- |
| 1 | un EAN-13 real se acepta | RF-12 |
| 2 | el mismo con un dígito cambiado se rechaza y no consulta | RF-12 |
| 3 | un EAN-8 válido se acepta | RF-12 |
| 4 | un código con letras o de trece dígitos mal contados se rechaza | RF-12 |
| 5 | un producto conocido se traduce a `Producto` con sus carbohidratos | RF-12 |
| 6 | el segundo escaneo del mismo código **no** llama al servicio: sale de la caché | RF-12 |
| 7 | `status: 0` devuelve `nil` y no lanza | RF-13 |
| 8 | un producto sin carbohidratos devuelve `nil`, igual que si no existiera | RF-13 |
| 9 | **P-10**: el servicio lanza `sinRed` y el flujo llega a la foto de la etiqueta | P-10 |
| 10 | el tiempo agotado a los 5 s lleva al mismo sitio que `sinRed` | P-10 |
| 11 | «Hidratos de carbono 75 g» en la etiqueta da 75 | RF-13 |
| 12 | un renglón de «Azúcares 30 g» **no** se toma por los carbohidratos | RF-13 |
| 13 | tabla en columnas: el número a la derecha del renglón se asocia bien | RF-13 |
| 14 | una etiqueta sin la palabra devuelve `nil` y eso lleva al campo manual | RF-13 |
| 15 | 75 g por 100 g, porción de 30 g, 2 porciones = **45 g** | RF-12 |
| 16 | sin porción en gramos **no se puede guardar**; nunca se supone 100 g | RF-37 |
| 17 | una comida sin tocar la absorción se guarda con 180 | RF-12b |
| 18 | con «Lenta» se guarda con 300, y queda en la comida | RF-12b |
| 19 | 350 g de carbohidratos no se guarda | RF-05 |
| 20 | porciones en 0 no se guarda | RF-12 |
| 21 | una hora futura no se guarda | RF-05 |
| 22 | lo guardado por código lleva `origen: barcode`; por etiqueta, `ocrEtiqueta` | RF-04 |
| 23 | «Deshacer» borra la comida y la cola queda sin ese registro | RF-36b |
| 24 | la base V2 se abre con la V3 sin perder filas, y las viejas quedan con `porciones: 1` | — |
| 25 | **no existe ninguna forma de crear una `Comida` sin llamar a `RegistrarComida`** | RF-37 |

La 25 no es una prueba de ejecución, es una comprobación de código: un `grep` de
`Comida(` fuera de `ComidasSwiftData` y de las pruebas tiene que salir vacío. Déjalo escrito
en el apartado de comprobaciones del pull request.

### 8 bis. En el iPhone físico

- [ ] Escanear un producto de verdad de la cocina y ver su nombre y sus carbohidratos
- [ ] Escanear algo sin código (fruta) y llegar a la captura manual sin pantallas de error
- [ ] **Con el wifi apagado**: escanear, caer en la etiqueta, fotografiarla y guardar la comida
- [ ] Registrar una comida por código de barras **en menos de 15 segundos**, cronómetro en mano

El último es el criterio del plan, no un adorno. Si toma más, algo del flujo tiene un paso de
más.

---

## 9. Cómo se sabe que el paso 6 está hecho

- Las 25 pruebas pasan, más las 101 de los pasos anteriores.
- La integración continua está verde **sin haber consultado Open Food Facts ni una vez**.
- `grep -rn "openfoodfacts" Glucy/ | grep -v "Glucy/Data/Network/"` no devuelve nada.
- `grep -rn "import Vision" Glucy/ | grep -v "Glucy/Data/OCR/"` sigue sin devolver nada.
- Con el teléfono en modo avión se registra una comida por las tres vías.
- La atribución de Open Food Facts se ve en la pantalla del producto.
- El `User-Agent` sale de una constante, y ni la URL ni el correo están escritos sueltos en
  más de un archivo.

---

## 10. Lo que NO entra en el paso 6

- **Escribir los carbohidratos en HealthKit.** Va en el paso 7, junto con la insulina: las dos
  son escrituras y comparten una sola llamada a `requestAuthorization`. Hacerlo aquí
  significaría pedir permiso dos veces a la persona.
- Buscar un producto por nombre. Open Food Facts tiene búsqueda por texto, pero es otra
  pantalla y otro límite de consultas.
- Guardar comidas favoritas o repetir la de ayer. Es una buena idea y es el paso 8 o más allá.
- Proteína, grasa y fibra (ver 2.1).
- Cualquier cosa que estime carbohidratos a partir de una foto del plato. No está en los
  requisitos y sería inventar un dato.
- Subir nada al backend. Eso es la fase 2; aquí solo se encola.

---

## 11. Git

```bash
git switch -c feature/comidas origin/develop
# …trabajo…
git add -A
git commit -m "feat: registro de comidas por código de barras con Open Food Facts"
git push -u origin feature/comidas
gh pr create --base develop --head feature/comidas --web
```

**El pull request va contra `develop`, no contra `main`.** Y no se fusiona con la integración
continua en rojo.

---

## 11 bis. El cuerpo del pull request, ya escrito

```markdown
## Antes

Glucy sabía cuánta glucosa tenías pero no qué habías comido, así que los carbohidratos
activos —la mitad de lo que hace falta para predecir— eran siempre cero. La pestaña de
registro solo ofrecía glucosa.

## Después

Se puede registrar una comida escaneando el código de barras del producto: la app lo consulta,
enseña el nombre, la marca y los carbohidratos, y pregunta cuántos gramos trae una porción y
cuántas porciones fueron. La cifra final se ve calculada, con sus tres factores a la vista,
antes de guardar.

Si el producto no está en la base, o si no hay red, la app lo dice en una línea y ofrece una
foto de la tabla nutrimental, que lee con el mismo OCR del paso anterior. Y si la etiqueta
tampoco se lee, queda el campo de gramos con el teclado abierto. **Las tres vías terminan en
el mismo sitio y ninguna deja a la persona sin poder registrar su comida.**

El tiempo de absorción no se pregunta: son 3 horas y se dice en una línea debajo. Quien quiera
cambiarlo toca «Ajustar» y elige entre rápida, normal y lenta.

## Cómo

Open Food Facts vive detrás del protocolo `ServicioProductos`, en `Data/Network/`, con un
doble en las pruebas: la integración continua no consulta el servicio ni una vez, porque el
límite es de 15 peticiones por minuto y por IP y una prueba que depende de internet falla por
razones que no son el código. La consulta sale del teléfono de cada persona, nunca del
servidor en nombre de todas, y lo que contesta se guarda en `ProductoCache` para no volver a
preguntar.

El dígito verificador del código se comprueba en el teléfono antes de salir a la red, así que
un código mal leído no gasta una consulta. La regla de qué número de la etiqueta son los
carbohidratos está aparte, en `SeleccionDeCarbohidratos`, y descarta a propósito los renglones
de azúcares y de fibra: en la tabla mexicana van sangrados debajo, y confundirlos subestima
los carbohidratos.

`Comida` no tenía `porciones` —solo los gramos de una porción—, así que este cambio trae la
segunda migración del esquema, `EsquemaGlucyV3`, con etapa ligera y `1` por omisión para las
filas que ya existan.

## Requisitos que cubre

- **RF-12** — comida por código de barras resuelta contra Open Food Facts.
- **RF-12b** — 180 minutos por omisión, sin preguntar, y tres opciones al ajustar.
- **RF-13** — si el producto no existe, foto de la tabla nutricional con OCR.
- **RF-37** — no se infiere ninguna comida; lo que falta se pregunta al registrar.
- **RF-04** — cada comida guarda su origen: `barcode`, `ocrEtiqueta` o `manual`.
- **RF-20** — con el teléfono sin conexión se registra igual y queda en la cola.
- **P-10** — Open Food Facts caído → foto → manual.

## Comprobado

- [x] Las pruebas pasan en local (<número> en total)
- [x] La integración continua está en verde, sin consultar Open Food Facts
- [x] No se agregó ninguna llave, token ni dato personal al repositorio
- [x] `Comida(` no se construye en ningún sitio fuera de `ComidasSwiftData` y las pruebas
- [x] La atribución de Open Food Facts se ve en la pantalla del producto

Comprobado en el iPhone físico:

- [x] Un producto real de la cocina se escanea y resuelve
- [x] Con el wifi apagado: escanear → etiqueta → guardar
- [x] Una comida por código de barras toma menos de 15 segundos
```

---

## 12. El texto para pegarle a Claude Code

> Lee `CLAUDE.md` y `docs/paso-6-comidas.md`. Haz el paso 6 completo en una rama
> `feature/comidas`: el protocolo `ServicioProductos` con `OpenFoodFactsHTTP` y su doble, la
> regla del dígito verificador, la extensión de `ServicioOCR` con `textosEn`, la regla
> `SeleccionDeCarbohidratos`, los dos casos de uso, la migración del esquema a la V3 con
> `porciones`, la pantalla de registro de comida con sus tres vías y las 25 pruebas.
>
> Cuatro cosas no se negocian. **Nunca se supone que una porción son 100 g**: si Open Food
> Facts no dio los gramos, se preguntan y no se puede guardar sin ellos; suponer 100 cuando
> son 30 triplica los carbohidratos y eso entra al COB y a la predicción. **Ninguna prueba
> consulta Open Food Facts de verdad**: el límite es de 15 por minuto y por IP, y todas van
> contra el doble. **No existe ninguna forma de crear una `Comida` sin pasar por
> `RegistrarComida`**, y ninguna comida se infiere ni se sugiere (RF-37). Y **el tiempo de
> absorción no se pregunta**: son 180 minutos, dichos en una línea, y los tres chips viven
> detrás de «Ajustar» (RF-12b lo dice así, aunque la pantalla del Figma los enseñe a la
> vista).
>
> Corrige el texto de `INFOPLIST_KEY_NSCameraUsageDescription` en las **dos** configuraciones,
> Debug y Release, para que mencione también el código de barras y la etiqueta: el texto del
> paso 5 solo habla del glucómetro y ahora mentiría. El `User-Agent` de Open Food Facts es
> obligatorio y va en una constante, con el correo de contacto que te pase yo; no lo inventes.
> La migración va versionada con una etapa ligera más, sin tocar la del paso 5.
>
> La rama sale de `develop` y el pull request va contra `develop`, con el cuerpo del apartado
> 11 bis. Corre las pruebas antes de decirme que terminaste y dime cuántas pasaron.
