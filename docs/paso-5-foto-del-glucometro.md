# Paso 5 — Captura por foto del glucómetro

Instrucciones concretas para el quinto paso de la fase 1. Están escritas para pegárselas a
Claude Code corriendo en la MacBook, dentro de esta misma carpeta, pero se leen igual de bien
a mano.

Contexto general: `CLAUDE.md` en la raíz. Plan completo de la fase:
`glucy-base/04-PLAN-FASE-1.md`. Los pasos anteriores, del 1 al 4, están terminados y
fusionados; sus documentos siguen en `docs/`.

---

## 0. Antes de abrir Claude Code

### 0.1 La rama, antes que nada

```bash
cd ~/Documents/glucy-ios
git fetch origin
git switch -c feature/foto-glucometro origin/develop
git branch --show-current     # tiene que decir: feature/foto-glucometro
```

### 0.2 Esta vez Xcode no te pide nada

A diferencia del paso 4, aquí **no hay capacidad que marcar ni firma que tocar**. La cámara
solo necesita una clave de Info.plist, y esa es un ajuste de compilación que Claude Code sí
puede escribir solo:

```
INFOPLIST_KEY_NSCameraUsageDescription = "Glucy usa la cámara para leer el número de la
pantalla de tu glucómetro. La foto se procesa en tu teléfono y no se guarda ni se sube."
```

**Va en las dos configuraciones, Debug y Release.** Es el error que ya costó dos veces en
este proyecto: el iOS mínimo en el paso 0 y los permisos de HealthKit en el paso 4.

```bash
grep -c "INFOPLIST_KEY_NSCameraUsageDescription" Glucy.xcodeproj/project.pbxproj   # 2
```

### 0.3 El iPhone, otra vez

La cámara **no existe en el simulador**. Vision sí corre ahí sobre una imagen cargada, así que
las pruebas del OCR se pueden automatizar; lo que hay que probar en tu iPhone 17 es la
captura de verdad: apuntar al glucómetro y ver si lee.

Si no tienes glucómetro a la mano, sirve cualquier pantalla con un número grande: una
calculadora, un reloj digital, un número escrito grueso en papel.

---

## 1. Qué se construye en el paso 5, y por qué va ahora

La tercera vía de captura, y la que le da nombre a la promesa de que Glucy sirve **sin
sensor**: fotografiar la pantalla del glucómetro y que la app lea el número.

Va después del paso 3 porque reutiliza su pantalla: la vía «Foto del medidor» ya está ahí,
en gris, diciendo que todavía no está lista. Este paso la enciende.

Requisitos que cubre: **RF-02**, **RF-03** y **RF-05b**.

---

## 1 bis. Los tres requisitos, pegados

### RF-02 (fase 1)

> El usuario fotografía la pantalla de su glucómetro y el OCR del dispositivo extrae el valor
> numérico. La app siempre muestra el valor leído y pregunta si es correcto. Ningún valor se
> guarda sin esa confirmación, sin importar la confianza que reporte el OCR.

**Lo importante está en la última frase.** «Sin importar la confianza» quiere decir que **no
hay atajo**: ni con 99 % de confianza se guarda solo. Es la decisión D-11 y el caso **P-01**.

### RF-03 (fase 1)

> Si el OCR no encuentra ningún número en la imagen, la app lo dice y ofrece la captura
> manual. No existe un umbral de confianza que decida por el usuario.

**Qué lo cumple aquí:** el estado «no alcancé a leer el número», con el teclado ya abierto
para escribirlo. No es una pantalla de error: es la misma pantalla, en otro estado.

### RF-05b (fase 1)

> La app registra si el usuario corrigió el valor propuesto por el OCR, y guarda también la
> confianza que el OCR reportó. Esa confianza no decide nada: se guarda para poder evaluar
> después si predice bien los errores.

**Y aquí está el trabajo escondido de este paso:** esos campos **no existen todavía** en
`LecturaGlucosa`. Hay que agregarlos, y eso significa la **primera migración del esquema**.

---

## 2. Las tres decisiones del paso 5

### 2.1 La primera migración de SwiftData, que es justo para lo que se hizo el plan

`LecturaGlucosa` guarda hoy once campos y ninguno es el valor que leyó el OCR. RF-05b pide
tres más:

| Campo nuevo | Tipo | Qué guarda |
| --- | --- | --- |
| `valorLeidoOcr` | `Double?` | lo que el OCR propuso, antes de que la persona lo tocara |
| `fueCorregido` | `Bool` | si el valor guardado no es el que propuso el OCR |
| `confianzaOcr` | `Double?` | lo que el OCR reportó, de 0 a 1. **No decide nada** |

El valor que cuenta como dato clínico sigue siendo `mgDl`: es el confirmado.

En el paso 2 se dejó escrito un `PlanMigracionGlucy` con una sola versión, diciendo que
existía «para cuando llegue la segunda». **Llegó.** Así queda:

```swift
nonisolated enum EsquemaGlucyV2: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }
    static var models: [any PersistentModel.Type] { /* las mismas diez */ }
}

nonisolated enum PlanMigracionGlucy: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [EsquemaGlucyV1.self, EsquemaGlucyV2.self] }
    /// Ligera: los tres campos nuevos son opcionales o traen valor por omisión, así que
    /// SwiftData puede migrar sin que nadie escriba cómo rellenar los existentes.
    static var stages: [MigrationStage] {
        [.lightweight(fromVersion: EsquemaGlucyV1.self, toVersion: EsquemaGlucyV2.self)]
    }
}
```

**Por qué importa hacerlo bien y no simplemente agregar los campos:** si se cambia el modelo
sin versionar, SwiftData no sabe migrar y **borra la base al arrancar**. En desarrollo eso es
una molestia; en las pruebas de campo de la fase 7, con datos de una persona real de varias
semanas, es un desastre que no se puede deshacer.

### 2.2 Vision detrás de un protocolo, igual que HealthKit

Mismo motivo que en el paso 4: la integración continua no tiene cámara. Pero con una
diferencia a favor: **Vision sí corre en el simulador y en el runner sobre una imagen
cargada**, así que aquí sí se puede probar el OCR de verdad, no solo con un doble.

```
ServicioOCR (protocolo, en Data/OCR/)
   ├── VisionOCR     ← la implementación, la única que importa Vision
   └── OCRFalso      ← para probar la pantalla sin imágenes
```

Y unas cuantas imágenes de prueba en `GlucyTests/Recursos/`, que **sí se suben al
repositorio**: son fotos de una pantalla con números, no datos de nadie.

### 2.3 Cuál número de la pantalla es la glucosa

Una pantalla de glucómetro no enseña un número: enseña la fecha, la hora, a veces la unidad y
a veces un promedio. El OCR los va a leer todos. Elegir mal es peor que no leer nada, porque
la persona confirma sin mirar.

La regla, en este orden:

1. Se descarta lo que no sea un número entero.
2. Se descarta lo que esté fuera de **20–600**, que es el rango que ya conocen las reglas del
   paso 1. Una fecha «12» o una hora «0830» se caen solas aquí.
3. De lo que queda, gana **el de mayor altura de caja**: en todo glucómetro el valor es el
   número más grande de la pantalla. No el de mayor confianza; el más grande.
4. Si quedan dos del mismo tamaño, gana el de arriba.
5. Si no queda ninguno, es el caso de RF-03: se dice y se ofrece escribirlo.

**El recuadro ámbar sobre la zona interpretada no es adorno.** Es lo que deja a la persona
ver que el número señalado es el de la glucosa y no el de la hora. Va con el color
`alertaAmbar` (`#F79009`) **como borde, nunca como texto**, que es lo que dice el tema.

Detalle de Vision que importa: **`usesLanguageCorrection = false`**. Con la corrección
encendida, Vision intenta convertir el número en una palabra conocida y «112» puede volver
«IIZ». Y `recognitionLevel = .accurate`, porque la velocidad aquí no importa: la foto ya se
tomó.

---

## 3. Archivos que hay que crear

```
Glucy/
  Data/
    OCR/
      ServicioOCR.swift          ← protocolo, tipos y el resultado con sus cajas
      VisionOCR.swift            ← la única que importa Vision
      SeleccionDeNumero.swift    ← la regla del apartado 2.3, sin Vision, probable sola
  Domain/
    UseCases/
      RegistrarLecturaPorFoto.swift
  Features/
    RegistroGlucosa/
      CapturaFotoView.swift      ← la cámara, envuelta en UIViewControllerRepresentable
      ConfirmarLecturaOcrView.swift
      (RegistroGlucosaViewModel.swift crece con el estado de la foto)

GlucyTests/
  Recursos/                      ← tres o cuatro fotos de pantallas con números
  SeleccionDeNumeroTests.swift
  RegistrarLecturaPorFotoTests.swift
  VisionOCRTests.swift           ← este sí usa Vision, sobre las imágenes de Recursos
  Dobles/OCRFalso.swift
```

Y se tocan: `EsquemaGlucy.swift` (la V2), `LecturaGlucosa.swift` y `LecturaGlucosaDato.swift`
(los tres campos), y `RegistroGlucosaView.swift` (encender la vía que estaba en gris).

---

## 4. El protocolo

```swift
// Data/OCR/ServicioOCR.swift

/// Un número que el OCR encontró en la imagen, con dónde estaba y qué tan seguro estaba.
nonisolated struct NumeroLeido: Sendable, Equatable {
    let valor: Double
    /// De 0 a 1, tal como lo reporta Vision. **No decide nada** (D-11, RF-05b): se guarda
    /// para poder evaluar después si predice bien los errores.
    let confianza: Double
    /// En coordenadas normalizadas de la imagen, para dibujar el recuadro ámbar encima.
    let caja: CGRect
}

nonisolated protocol ServicioOCR: Sendable {
    /// Devuelve todos los números que encontró, sin elegir. Quien elige es
    /// `SeleccionDeNumero`, que se puede probar sin imágenes.
    func numerosEn(imagen: Data) async throws -> [NumeroLeido]
}
```

```swift
// Data/OCR/SeleccionDeNumero.swift

nonisolated enum SeleccionDeNumero {
    /// La regla del apartado 2.3. Devuelve `nil` cuando no hay ningún candidato válido,
    /// que es el caso de RF-03.
    static func glucosa(entre numeros: [NumeroLeido]) -> NumeroLeido?
}
```

---

## 5. El flujo, y el punto donde se guarda

```
foto  →  OCR  →  SeleccionDeNumero  →  la app enseña el número y el recuadro
                                              ↓
                              «¿es correcto?»  →  Sí  →  se guarda
                                              ↓
                                          Corregir  →  teclado con el valor puesto  →  se guarda
                                              ↓
                                     no leyó nada  →  teclado vacío  →  se guarda
```

**El único punto donde se guarda está después de la confirmación.** No hay otro camino al
repositorio desde esta pantalla, y esa es la forma de que P-01 no se pueda romper por
accidente: si solo existe una puerta, nadie entra por la ventana.

```swift
// Domain/UseCases/RegistrarLecturaPorFoto.swift

nonisolated struct RegistrarLecturaPorFoto: Sendable {
    let repositorio: any RepositorioLecturas

    /// - Parameter valorConfirmado: lo que la persona aprobó. Es el dato clínico.
    /// - Parameter valorLeidoOcr: lo que el OCR había propuesto, o `nil` si no leyó nada.
    ///
    /// No existe una versión de esta función sin confirmación. Guardar sin que la persona
    /// apruebe el valor es justo lo que D-11 prohíbe (RF-02, caso P-01).
    func ejecutar(
        valorConfirmado: Double,
        valorLeidoOcr: Double?,
        confianzaOcr: Double?,
        tsUtc: Date,
        contexto: ContextoComida?,
        ahora: Date = Date()
    ) async throws -> LecturaGlucosaDato
}
```

`fueCorregido` **no se pide**: lo calcula el caso de uso comparando los dos valores. Un
parámetro que se puede deducir es un parámetro que algún día llega mal.

La validación es la misma del paso 3: `Validacion.validarLectura`, con
`origen: .fotoGlucometro` y `confirmadaPorUsuario: true`. Un 900 leído por el OCR y
confirmado por error **tampoco se guarda**.

---

## 6. La imagen no se guarda. Nunca

Regla 6 del proyecto, y no tiene excepciones:

- La foto vive en memoria mientras Vision la procesa y se suelta.
- **No** se escribe en disco, **no** va al carrete, **no** se sube, **no** se mete en
  SwiftData, **no** se guarda «solo para depurar».
- Lo único que sobrevive es el número, su confianza y si se corrigió.

Con la cámara envuelta en `UIViewControllerRepresentable`, ojo con lo fácil que es dejar
`UIImageWriteToSavedPhotosAlbum` o un `savedPhotosAlbum` de ejemplo pegado de un tutorial. Se
comprueba con un `grep` en el apartado 9.

Y el permiso de cámara negado **no es un error**: se dice en una línea y se ofrece escribir
el número. La misma salida que RF-03.

---

## 7. Textos, palabra por palabra

| Situación | Texto |
| --- | --- |
| Leyó un número | «¿Es este el valor que te marcó?» con la cifra grande y el recuadro ámbar |
| Botones | «Sí, es correcto» · «Corregir» |
| No leyó nada (RF-03) | «No alcancé a leer el número. Puedes escribirlo tú.» |
| Cámara negada | «Sin permiso de cámara no puedo leer la pantalla. Escribe el número y listo.» |
| Corrigiendo | el teclado numérico abierto con el valor propuesto ya escrito y seleccionado |

Nada de «error», nada de «confianza baja», nada de porcentajes en pantalla. La confianza se
guarda; no se enseña. Enseñarla invitaría a confiar en ella, y no decide nada.

---

## 8. Las pruebas que tienen que pasar

| # | Qué comprueba | Por qué |
| --- | --- | --- |
| 1 | **Sin confirmar no se guarda nada**: no existe camino al repositorio sin el valor confirmado | **P-01**, D-11 |
| 2 | Con 0.99 de confianza tampoco se guarda solo | «sin importar la confianza» (RF-02) |
| 3 | Se guarda `valorLeidoOcr`, `confianzaOcr` y `fueCorregido` | RF-05b |
| 4 | Confirmar sin cambiar deja `fueCorregido` en `false` | RF-05b |
| 5 | Corregir 112 → 121 deja `fueCorregido` en `true` y `mgDl` en 121 | RF-05b |
| 6 | Lo guardado lleva `origen: .fotoGlucometro` | RF-04 |
| 7 | Un 900 confirmado por error **no** se guarda | RF-05, la validación del paso 3 no se salta |
| 8 | Entre 12, 0830 y 112, la selección devuelve **112** | La regla del 2.3, fecha y hora descartadas |
| 9 | Entre dos números en rango, gana el de caja más alta | El valor es el número más grande |
| 10 | Entre dos del mismo tamaño, gana el de arriba | Desempate estable |
| 11 | Sin ningún candidato válido devuelve `nil` | **RF-03** |
| 12 | La selección **no** usa la confianza para ordenar | D-11: no decide nada |
| 13 | Vision lee el número de las imágenes de `Recursos/` | Que el OCR de verdad funcione |
| 14 | La base con datos de la V1 se abre con la V2 sin perder filas | La migración |
| 15 | Una lectura por foto se escribe en Salud | El paso 4 ya lo contempla: `.fotoGlucometro` está en la lista |

Y en el iPhone, a mano: apuntar a un número grande de verdad y comprobar que lo lee, que el
recuadro cae encima del número correcto, y que negar el permiso de cámara no tumba la app.

---

## 9. Cómo se sabe que el paso 5 está hecho

1. Las pruebas en verde: las 77 de los pasos anteriores **y** estas quince.
2. `grep -rn "import Vision" Glucy/ | grep -v "Glucy/Data/OCR/"` no devuelve nada.
3. **La imagen no se guarda en ningún lado:**
   ```bash
   grep -rniE "savedPhotosAlbum|UIImageWrite|\.jpeg|\.png|write\(to:" Glucy/Features/ Glucy/Data/OCR/
   ```
   No debe devolver nada que escriba una imagen.
4. `grep -c "INFOPLIST_KEY_NSCameraUsageDescription" Glucy.xcodeproj/project.pbxproj` da **2**.
5. No hay ninguna comparación contra un umbral de confianza. La palabra `umbral` no aparece
   junto a `confianza` en todo `Glucy/`.
6. En el iPhone: lee un número real y el recuadro cae encima del número correcto.

---

## 10. Lo que NO entra en el paso 5

El OCR de la etiqueta nutrimental, que es del paso 6 y usa el mismo servicio con otra regla de
selección. Las comidas, la insulina, las gráficas, el onboarding. Nada de red ni de
predicción. Y no se toca la vía de HealthKit.

---

## 11. Git

```bash
git switch -c feature/foto-glucometro origin/develop
# …trabajo…
git add .
git commit -m "feat: captura de glucosa por foto del glucómetro con confirmación obligatoria"
git push -u origin feature/foto-glucometro
gh pr create --base develop --head feature/foto-glucometro --web
```

Contra `develop`, en español, con la plantilla llena, y **esperando a que la integración
continua termine** antes de fusionar.

---

## 11 bis. El cuerpo del pull request, ya escrito

```markdown
## Antes

En la pantalla de registro, la vía «Foto del medidor» se veía en gris y decía que todavía no
estaba lista. Para anotar una glucosa había que teclearla, aunque el número estuviera ahí
mismo en la pantalla del glucómetro.

## Después

Se puede fotografiar la pantalla del glucómetro y la app lee el número en el propio teléfono.
Enseña la cifra con un recuadro ámbar encima de la zona que interpretó, para que se vea que
señaló la glucosa y no la hora, y pregunta si es correcta. **Nada se guarda hasta que la
persona lo confirma**, tenga el OCR la confianza que tenga. Si prefiere corregirlo, el teclado
se abre con el valor ya escrito; si el OCR no encontró ningún número, la app lo dice y ofrece
escribirlo.

La foto se procesa en el teléfono y no se guarda ni se sube. Lo único que queda es el número
confirmado, el que el OCR había propuesto, si hubo corrección y la confianza que reportó.

## Cómo

Vision vive detrás del protocolo `ServicioOCR`, en `Data/OCR/`, y la regla de cuál número de
la pantalla es la glucosa está aparte, en `SeleccionDeNumero`, para poder probarla sin
imágenes: se descarta lo que no esté entre 20 y 600 —con lo que la fecha y la hora se caen
solas— y de lo que queda gana el de caja más alta, porque en un glucómetro el valor es siempre
el número más grande. La confianza del OCR se guarda y no participa en esa decisión.

Los tres campos que pide RF-05b no existían en `LecturaGlucosa`, así que este cambio trae la
primera migración del esquema: `EsquemaGlucyV2` con una etapa ligera desde la V1. El plan de
migración se dejó escrito en el paso 2 justo para esto; cambiar el modelo sin versionarlo
habría borrado la base al arrancar.

## Requisitos que cubre

- **RF-02** — foto, OCR en el dispositivo y confirmación obligatoria del valor.
- **RF-03** — si no lee nada, lo dice y ofrece la captura manual.
- **RF-05b** — se guarda el valor leído, si hubo corrección y la confianza.
- **RF-04** — lo guardado lleva `origen: fotoGlucometro`.
- **D-11** — no hay umbral de confianza; la confianza no decide nada.
- **P-01** — sin confirmar no se guarda nada.

## Comprobado

- [x] Las pruebas pasan en local (<número> en total)
- [x] La integración continua está en verde
- [x] No se agregó ninguna llave, token ni dato personal al repositorio
- [x] La imagen no se escribe en disco, ni va al carrete, ni se sube

Comprobado en el iPhone físico:

- [x] Lee el número de una pantalla real y el recuadro cae encima del número correcto
- [x] Negar el permiso de cámara no tumba la app y ofrece escribir el valor
```

---

## 12. El texto para pegarle a Claude Code

> Lee `CLAUDE.md` y `docs/paso-5-foto-del-glucometro.md`. Haz el paso 5 completo en una rama
> `feature/foto-glucometro`: el protocolo `ServicioOCR` con `VisionOCR` y su doble, la regla
> `SeleccionDeNumero`, el caso de uso, la cámara y la pantalla de confirmación, la migración
> del esquema a la V2 con los tres campos de RF-05b, y las quince pruebas.
>
> Tres cosas no se negocian. **Nada se guarda sin que la persona confirme el valor**, con la
> confianza que sea: es D-11 y el caso P-01, y la forma de garantizarlo es que solo exista un
> camino al repositorio, el que pasa por la confirmación. **La imagen no se guarda en ningún
> lado**: ni en disco, ni en el carrete, ni en SwiftData, ni para depurar. Y **la confianza del
> OCR se guarda pero no decide nada**: no la uses para ordenar candidatos ni para comparar
> contra ningún umbral.
>
> Agrega `INFOPLIST_KEY_NSCameraUsageDescription` a las **dos** configuraciones del target
> `Glucy`, Debug y Release; poner un ajuste en una sola ya costó dos veces en este proyecto.
> La migración va versionada con una etapa ligera: cambiar el modelo sin versionarlo borra la
> base al arrancar. La rama sale de `develop` y el pull request va contra `develop`, con el
> cuerpo del apartado 11 bis. Corre las pruebas antes de decirme que terminaste y dime cuántas
> pasaron.
