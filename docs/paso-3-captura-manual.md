# Paso 3 — Captura manual de glucosa

Instrucciones concretas para el tercer paso de la fase 1. Están escritas para pegárselas a
Claude Code corriendo en la MacBook, dentro de esta misma carpeta, pero se leen igual de bien
a mano.

Contexto general: `CLAUDE.md` en la raíz. Plan completo de la fase:
`glucy-base/04-PLAN-FASE-1.md`. Los pasos anteriores: `docs/paso-1-dominio-y-reglas.md` y
`docs/paso-2-persistencia-local.md`, los dos terminados y fusionados.

---

## 0. Antes de abrir Claude Code

```bash
cd ~/Documents/glucy-ios
git switch develop
git pull origin develop
git switch -c feature/captura-manual
```

**La rama sale de `develop`, nunca de `main`.** `develop` ya trae los pasos 1 y 2 y está al
día. Es la convención del proyecto: `feature` → `develop` → `main`, y en los dos pasos
anteriores se saltó. El pull request también va **contra `develop`**.

Para comprobar que estás donde debes antes de empezar:

```bash
git branch --show-current     # tiene que decir: feature/captura-manual
git log --oneline -1 develop  # tiene que ser el merge del paso 2
```

---

## 1. Qué se construye en el paso 3, y por qué va ahora

**Esta es la primera pantalla de verdad.** Hasta hoy la app abre en el «Hello, Glucy!» que
dejó el asistente de Xcode; al terminar este paso, una persona puede anotar su glucosa y
verla guardada.

Va ahora porque es el camino más corto para tener algo que **se puede usar de verdad**, y
porque prueba de punta a punta las dos capas de abajo: las reglas del paso 1 rechazando un
valor imposible y los repositorios del paso 2 guardándolo y encolándolo. Si algo quedó mal
ahí, aquí se ve.

Es **solo la vía manual** de la pantalla 4. La foto del glucómetro es el paso 5 y HealthKit
el paso 4; la pantalla se diseña desde hoy sabiendo que va a tener tres vías, pero solo una
funciona.

Requisitos que cubre: **RF-01**, **RF-04** y **RF-05**.

---

## 1 bis. Los tres requisitos, pegados

Copiados literalmente del Documento 2 v6, con lo que en el paso 3 los cumple y la prueba que
lo demuestra.

### RF-01 (fase 1)

> El usuario captura manualmente un valor de glucosa: número en mg/dL, fecha y hora (por
> omisión la actual, editable) y una etiqueta de contexto entre en ayunas, antes de comer,
> 2 h después de comer, antes de dormir y otro.

**Qué lo cumple aquí:** la pantalla de registro con sus tres campos. Las cinco etiquetas ya
existen en `ContextoComida`, del paso 1, y son exactamente esas cinco: no se inventa una
sexta ni se quita ninguna.

**Prueba:** la 1, la 2 y la 7 del apartado 11.

### RF-04 (fase 1)

> Cada lectura guarda su origen: sensor, manual o foto_glucometro. El origen viaja con el
> dato hasta el dashboard.

**Qué lo cumple aquí:** todo lo que se guarde por esta pantalla lleva `origen: .manual`,
puesto por el caso de uso y no por la vista. En el paso 5 la misma pantalla va a guardar con
`.fotoGlucometro`, y en el paso 4 HealthKit con `.sensor`.

**Prueba:** la 3.

### RF-05 (fase 1)

> La app avisa si el valor capturado está fuera del rango fisiológico (20–600 mg/dL) o si la
> hora es futura, y pide corregirlo antes de guardar.

**Qué lo cumple aquí:** el caso de uso llama a `Validacion.validarLectura`, del paso 1, y
traduce el `Rechazo` a un mensaje en español. **La regla no se vuelve a escribir en la vista
ni en el ViewModel**: ya está probada, y una segunda copia es una segunda copia que algún día
va a estar en otro valor.

**Prueba:** la 4 y la 5, que son el caso P-02.

---

## 2. Las dos decisiones del paso 3

### La cadena de dependencias, que aquí se estrena

```
RegistroGlucosaView  →  RegistroGlucosaViewModel  →  RegistrarLecturaManual  →  RepositorioLecturas
   dibuja                 estado y formato              la regla                  guarda y encola
```

- La **vista** no valida, no calcula y no toca SwiftData. Dibuja y recoge gestos.
- El **ViewModel** guarda el texto del campo, el `Date`, el contexto elegido y el mensaje de
  error que hay que mostrar. **Ninguna regla clínica.** Que 900 sea inválido no lo decide él.
- El **caso de uso** es quien sabe: valida, pone el origen, arma el `LecturaGlucosaDato` y
  llama al repositorio.

Si el ViewModel compara contra 600 en algún lado, el paso está mal hecho aunque funcione.

### `Theme.swift` y la carcasa de pestañas entran ahora

Es la primera pantalla, así que toca crear dos cosas que van a usar todas las demás:

1. **`App/Theme/Theme.swift`** con los once colores y los siete niveles de tipografía. A
   partir de hoy, **ningún hex suelto dentro de una vista**.
2. **La carcasa de cuatro pestañas** — Inicio · Registrar · Historial · Ajustes — que
   reemplaza a `ContentView`. Solo **Registrar** hace algo; las otras tres muestran el estado
   de «vacío, primer día» que ya está especificado. Se hace hoy y no en el paso 8 porque de
   otro modo la pantalla de registro tendría que ser la raíz de la app y habría que
   desmontarla después.

---

## 3. Archivos que hay que crear

```
Glucy/
  App/
    Theme/
      Theme.swift                     ← colores, tipografía, espacios y radios
    GlucyApp.swift                    ← ya existe: cambia ContentView por PestanasView
  Domain/
    UseCases/
      RegistrarLecturaManual.swift
  Features/
    Pestanas/
      PestanasView.swift              ← el TabView de cuatro pestañas
      PendienteView.swift             ← el marcador de las tres pestañas que no toca este paso
    RegistroGlucosa/
      RegistroGlucosaView.swift
      RegistroGlucosaViewModel.swift

GlucyTests/
  RegistrarLecturaManualTests.swift
  RegistroGlucosaViewModelTests.swift
  Dobles/
    RepositorioLecturasFalso.swift    ← para probar el ViewModel sin SwiftData

GlucyUITests/
  RegistroGlucosaUITests.swift
```

`Glucy/ContentView.swift` se borra.

---

## 4. `Theme.swift`, con los valores exactos

Los once colores del Documento 1, tal cual. **No se redondean ni se ajustan «para que se vea
mejor»**: están elegidos por su contraste, y la columna de la derecha es la razón.

| Token | Hex | Para qué | Contraste sobre blanco |
| --- | --- | --- | --- |
| `azulPrimario` | `#1A56DB` | botones, enlaces, línea de glucosa medida, pestaña activa | 6.2:1 |
| `azulClaro` | `#BBD5FF` | fondo de la opción elegida y tarjetas informativas | fondo |
| `azulProfundo` | `#0B2A6B` | las cifras grandes de glucosa | 13.5:1 |
| `fondo` | `#F4F6FA` | fondo de todas las pantallas salvo el splash | fondo |
| `superficie` | `#FFFFFF` | fondo de tarjetas | fondo |
| `textoPrincipal` | `#111827` | títulos y texto de lectura | 17.7:1 |
| `textoSecundario` | `#6B7280` | etiquetas, unidades, pies de gráfica | 4.8:1 |
| `enRango` | `#0B7A54` | texto de estado favorable | 5.2:1 |
| `precaucion` | `#B54708` | texto de la predicción cerca de un límite | 5.4:1 |
| `alertaAmbar` | `#F79009` | **solo borde e icono** de avisos, nunca texto | 2.4:1 |
| `hipoglucemia` | `#D92D20` | episodios < 70, aviso clínico, borrado | 4.8:1 |

Hay dos verdes y dos ámbares a propósito: el brillante no alcanza 4.5:1 como letra de 13 pt,
así que el texto usa las variantes oscuras y las brillantes quedan para rellenos y bordes,
donde el mínimo es 3:1. **`alertaAmbar` nunca se usa como color de letra.**

Tipografía, siete niveles, ninguno por debajo de 11 pt, y todos con `Font` relativa para que
Dynamic Type los mueva:

| Nivel | Tamaño y peso |
| --- | --- |
| cifra de glucosa | bold 56 |
| cifra secundaria | bold 44 |
| título de pantalla | semibold 22–26 |
| título de tarjeta | semibold 16–17 |
| texto de lectura | regular 16 |
| valor de fila | regular/semibold 15 |
| etiqueta y pie | 11–13 |

Espacio y forma: rejilla de **4 pt**, margen lateral **20**, separación entre tarjetas **14**.
Radios: 20 tarjetas grandes, 16 bloques internos, 12 campos y botones pequeños, completo para
chips e interruptores. **Sin sombras**: se ven mal con brillo alto y bajo el sol, y la
separación se consigue con blanco sobre `#F4F6FA`. Botón principal **50** pt de alto, renglón
de ajustes 56, chip 36 con área tocable de **44**.

La fuente es **San Francisco**, la del sistema. En el dibujo de Figma aparece Inter; en la app
no se usa, porque San Francisco es la única que responde bien a Dynamic Type.

---

## 5. El caso de uso, con su firma exacta

```swift
// Domain/UseCases/RegistrarLecturaManual.swift

/// Lo que la pantalla necesita saber cuando algo no se pudo guardar.
///
/// Es el `Rechazo` del paso 1 ya traducido a algo que se puede enseñar. La traducción vive
/// aquí y no en la vista para que el mismo texto salga igual en las tres vías de captura.
nonisolated struct FalloRegistro: Error, Equatable {
    let mensaje: String
    let campo: CampoRegistro
}

nonisolated enum CampoRegistro: Equatable { case valor, fecha, ninguno }

nonisolated struct RegistrarLecturaManual: Sendable {
    let repositorio: any RepositorioLecturas

    /// Valida, pone el origen y guarda. Devuelve la lectura tal como quedó guardada.
    ///
    /// El origen lo pone este caso de uso, no quien lo llama: es la única forma de
    /// garantizar que ninguna lectura entre sin él (regla 4, RF-04).
    func ejecutar(
        mgDl: Double,
        tsUtc: Date,
        contexto: ContextoComida?,
        nota: String? = nil,
        ahora: Date = Date()
    ) async throws -> LecturaGlucosaDato
}
```

Los mensajes, palabra por palabra. Son los que va a leer alguien a las tres de la mañana:

| Rechazo | Mensaje | Campo |
| --- | --- | --- |
| `fueraDeRango` | «Ese valor está fuera de lo que un medidor puede leer. Anota un número entre 20 y 600 mg/dL.» | `.valor` |
| `marcaDeTiempoFutura` | «Esa hora todavía no llega. Revisa la fecha.» | `.fecha` |
| campo vacío o no numérico | «Escribe el número que te marcó el medidor.» | `.valor` |

**No se dice «error», no se dice «inválido» y no se dice el nombre de ninguna regla.** Se dice
qué corregir.

---

## 6. El ViewModel

```swift
// Features/RegistroGlucosa/RegistroGlucosaViewModel.swift

@Observable
final class RegistroGlucosaViewModel {
    var textoValor: String = ""
    var fecha: Date = Date()
    var contexto: ContextoComida? = nil

    private(set) var fallo: FalloRegistro? = nil
    private(set) var guardando: Bool = false
    private(set) var ultimaGuardada: LecturaGlucosaDato? = nil

    init(registrar: RegistrarLecturaManual)

    func guardar() async
    func limpiar()
}
```

Tres cosas que se hacen mal con facilidad:

1. **El error se borra en cuanto la persona empieza a corregir.** Un mensaje rojo que se queda
   puesto mientras ya se está escribiendo el valor bueno hace pensar que la app se trabó.
2. **`textoValor` es `String`, no `Double`.** Con `Double` no se puede distinguir «vacío» de
   «cero», y el campo se llena solo con un 0 en cuanto se toca.
3. **La coma decimal.** En México el teclado ofrece coma; `Double("5,5")` devuelve `nil`. Se
   normaliza la coma a punto antes de convertir, o el mensaje de error aparece con un número
   perfectamente válido escrito en pantalla.

---

## 7. La pantalla, y lo que no se puede perder

### El diseño

**Pantalla 4 — Registro de glucosa**, abierta directamente en su node-id:

> **https://www.figma.com/design/TFOHJ9wm2lhsiEk1e3595A?node-id=7-2**

El archivo completo con las diez pantallas:
https://www.figma.com/design/TFOHJ9wm2lhsiEk1e3595A · 393 × 852 pt.
Las otras trece pantallas del alcance: https://claude.ai/artifact/JjwUJfsZunXFGvQZyrG8pX

Dos advertencias sobre ese enlace:

- **Claude Code no lo va a poder abrir** desde la MacBook, salvo que tengas el conector de
  Figma configurado ahí. El enlace es **para ti**: ábrelo en el navegador mientras revisas, y
  compara. Lo que manda para escribir el código es la lista de abajo, que es esa misma ficha
  puesta en palabras.
- En el dibujo la tipografía es **Inter**; en la app se usa **San Francisco**, la del sistema,
  porque es la única que responde bien a Dynamic Type. No hay que importar Inter.

### Lo que no se puede perder

De la ficha del mockup, lo que es obligatorio aunque el dibujo no se pueda abrir:

- **Las tres vías en un solo lugar.** Arriba, tres opciones: «A mano», «Foto del medidor» y
  «Del sensor». En este paso solo la primera hace algo; las otras dos se ven, se pueden tocar
  y dicen en qué paso llegan («Todavía no está lista»), en gris. No se ocultan: la persona
  tiene que ver desde el principio que existen.
- **Un dato y una acción por pantalla.** El campo del valor es el protagonista, con la cifra
  grande (bold 56) y «mg/dL» al lado en `textoSecundario`. Abajo, un solo botón principal de
  50 pt: «Guardar».
- **El teclado numérico se abre solo** al entrar a la pantalla, y es `.decimalPad`.
- **La fecha y la hora arrancan en «ahora»** y se pueden tocar para cambiarlas. No se pide
  confirmación de la hora si no se tocó.
- **Las cinco etiquetas de contexto son chips** de 36 pt con área tocable de 44, en una fila
  que se envuelve. Se puede no elegir ninguna: el contexto es opcional (`ContextoComida?`).
- **El error sale pegado al campo que hay que corregir**, no en un diálogo. Un diálogo tapa el
  valor que se está corrigiendo.
- **Al guardar, franja breve «Lectura guardada» con «Deshacer»** unos segundos. Deshacer es
  mejor que preguntar «¿estás seguro?».

---

## 8. Estados que la pantalla tiene que tener

- **Inicial:** campo vacío, teclado abierto, botón «Guardar» deshabilitado.
- **Escribiendo:** botón habilitado en cuanto hay algo escrito. La validación **no** se hace
  tecla por tecla: se hace al tocar «Guardar». Marcar en rojo mientras alguien escribe «112»
  al pasar por «1» es hostil.
- **Guardando:** el botón muestra su indicador y no se puede tocar dos veces.
- **Guardado:** franja «Lectura guardada» con «Deshacer», el campo se limpia y el teclado se
  queda abierto para la siguiente.
- **Rechazado:** mensaje bajo el campo en `hipoglucemia` (`#D92D20`) **con un icono al lado**,
  porque el color nunca es el único portador de información.
- **Sin conexión:** no se enseña nada. No es un error, es lo normal: la app completa funciona
  sin red y el registro se queda en la cola (caso P-07).

Las otras tres pestañas, en este paso, muestran: «Todavía no tengo lecturas tuyas» en Inicio,
«Necesito al menos tres días de datos para calcular tu tiempo en rango» en Historial, y un
marcador en Ajustes. **Nunca un cero ni una pantalla en blanco**: hacen pensar que la app
está rota.

---

## 9. Accesibilidad, que es requisito y no capa final

- **Dynamic Type en todo**, con `Font` relativa. Hay que abrir la pantalla en el tamaño
  extragrande y comprobar que no se corta ni una palabra: es el caso **P-15**. Si los chips no
  caben, se apilan en una columna.
- **VoiceOver** lee cada cifra con su unidad: el campo se anuncia como «valor de glucosa en
  miligramos por decilitro», no como «campo de texto».
- Los chips de contexto llevan `accessibilityLabel` con la etiqueta completa («dos horas
  después de comer», no «2 h después»).
- El mensaje de rechazo se anuncia solo al aparecer.
- Contraste mínimo **4.5:1** en texto y **3:1** en bordes. Los tokens ya lo cumplen si se usan
  donde dice la tabla.
- Todo en **español de México** y en **mg/dL**.

---

## 10. Cómo se escriben los textos

De tú y en presente. Sin tecnicismos. Todo número con su unidad. **Ninguna frase da una
instrucción de tratamiento**: la pantalla registra lo que la persona midió, no le dice qué
hacer con ese número. Ni un «deberías», ni un «conviene que te apliques», ni un color que
sugiera una acción.

---

## 11. Las pruebas que tienen que pasar

Unitarias, sobre el caso de uso y el ViewModel. El ViewModel se prueba con un repositorio
falso, sin levantar SwiftData.

| # | Qué comprueba | Por qué |
| --- | --- | --- |
| 1 | Una lectura válida se guarda y vuelve con su UUID | Es el criterio de «hecho» |
| 2 | Se guarda con el contexto elegido, y también sin ninguno | El contexto es opcional (RF-01) |
| 3 | Lo guardado por esta pantalla siempre lleva `origen: .manual` | RF-04, y nadie más lo pone |
| 4 | **900 mg/dL no se guarda** y devuelve el mensaje del rango, sin tocar el repositorio | Caso **P-02** |
| 5 | 20 y 600 sí se guardan | Los extremos son válidos, no hay que apretarlos |
| 6 | Una hora futura no se guarda y señala el campo de la fecha | RF-05 |
| 7 | Lo guardado nace en `pendiente` y queda en la cola | RF-20 y RF-36b, caso **P-07** |
| 8 | Lo guardado conserva `tsUtc` **y** `zonaHoraria` | Regla 5 |
| 9 | «5,5» con coma se interpreta igual que «5.5» | El teclado mexicano ofrece coma |
| 10 | Un campo vacío no llama al repositorio y pide el número | No se guarda basura |
| 11 | El mensaje de error se borra al cambiar el valor | Un rojo pegado parece que la app se trabó |
| 12 | Dos toques seguidos en «Guardar» no guardan dos veces | `guardando` es la guarda |

Y una de recorrido en `GlucyUITests`: abrir la app, ir a **Registrar**, escribir 112, elegir
«en ayunas», guardar, y comprobar que aparece la franja de confirmación.

---

## 12. Cómo se sabe que el paso 3 está hecho

1. `xcodebuild … -only-testing:GlucyTests test` en verde, con las de los pasos 1 y 2 **y**
   estas doce.
2. Se registra una lectura **en modo avión**, queda en la cola, y **900 mg/dL no se deja
   guardar** (P-02).
3. `grep -rn "import SwiftData" Glucy/Features/` no devuelve nada.
4. `grep -rn "#[0-9A-Fa-f]\{6\}" Glucy/Features/` no devuelve nada: ningún hex suelto fuera de
   `Theme.swift`.
5. No hay ningún número clínico escrito suelto fuera de `ConfiguracionDominio.swift`. En el
   ViewModel no aparecen ni 20 ni 600.
6. La pantalla abierta en el tamaño de letra más grande no corta texto (P-15).

---

## 13. Lo que NO entra en el paso 3

La foto del glucómetro (paso 5), HealthKit (paso 4), las comidas (paso 6), la insulina
(paso 7), las gráficas (paso 8), el alta del perfil y los ajustes (paso 9). Las tres pestañas
que no son Registrar se quedan en su estado vacío. Nada de red, nada de predicción.

---

## 14. Git

```bash
git switch develop
git pull origin develop
git switch -c feature/captura-manual
# …trabajo…
git add .
git commit -m "feat: captura manual de glucosa con validación y tema de la app"
git push -u origin feature/captura-manual
```

```bash
# Cuando esté listo, el pull request se abre contra develop. Con --web se abre el
# navegador ya con la plantilla puesta, y ahí se pega el cuerpo del apartado 14 bis:
gh pr create --base develop --head feature/captura-manual --web
```

No se fusiona con la integración continua en rojo, y **hay que esperar a que termine**, no
solo a que arranque. En los dos pasos anteriores se fusionó antes de tiempo.

---

## 14 bis. El cuerpo del pull request, ya escrito

La plantilla de `.github/pull_request_template.md` **se llena, no se deja con los comentarios
puestos**. Es un punto de la rúbrica: el «qué se veía antes / qué se ve después» es
exactamente lo que se califica en control de versiones.

Este es el cuerpo completo para este paso. Solo hay que cambiar el número de pruebas y marcar
las casillas:

```markdown
## Antes

La app abría en la pantalla de ejemplo que deja el asistente de Xcode, con el texto
«Hello, Glucy!» y un icono de globo terráqueo. No había forma de anotar una glucosa: las
reglas del paso 1 y la base de datos del paso 2 ya existían, pero nada las usaba.

## Después

La app abre en cuatro pestañas — Inicio, Registrar, Historial y Ajustes — y en Registrar se
puede anotar una glucosa a mano: el número con el teclado ya abierto, la fecha y la hora
puestas en «ahora» y editables, y una etiqueta de contexto opcional entre las cinco.
Al guardar aparece una franja de confirmación con «Deshacer».

Si el valor está fuera de 20–600 mg/dL, no se guarda y sale el mensaje pegado al campo:
«Ese valor está fuera de lo que un medidor puede leer. Anota un número entre 20 y 600
mg/dL». Si la hora es futura, lo mismo sobre el campo de la fecha.

Las otras tres pestañas muestran su estado vacío con su texto, no un cero ni una pantalla en
blanco. Las vías «Foto del medidor» y «Del sensor» se ven en la pantalla de registro, en
gris, diciendo que todavía no están listas.

## Cómo

La cadena es vista → ViewModel → caso de uso → repositorio, y la regla clínica vive en un
solo lugar: `RegistrarLecturaManual` llama a `Validacion.validarLectura`, que ya estaba
probada desde el paso 1, y traduce el `Rechazo` a un mensaje en español. El ViewModel no
compara contra ningún umbral; solo guarda el texto del campo y el mensaje que hay que
enseñar. El origen `.manual` lo pone el caso de uso, no la vista, que es la única forma de
garantizar que ninguna lectura entre sin él.

Se agregan también `Theme.swift`, con los once colores y los siete niveles de tipografía, y
la carcasa de pestañas que reemplaza a `ContentView`. Van en este paso y no en el 8 porque
si no, la pantalla de registro tendría que ser la raíz de la app y habría que desmontarla
después.

## Requisitos que cubre

- **RF-01** — captura manual con valor, fecha y hora editables y etiqueta de contexto entre
  las cinco.
- **RF-04** — cada lectura guarda su origen; todo lo de esta pantalla nace `manual`.
- **RF-05** — se avisa si el valor está fuera de 20–600 mg/dL o si la hora es futura, y se
  pide corregir antes de guardar.
- **P-02** — 900 mg/dL no se guarda.
- **P-07** — se registra en modo avión y queda en la cola.
- **P-15** — la pantalla no corta texto con la letra de accesibilidad más grande.

## Comprobado

- [x] Las pruebas pasan en local (<número> en total: las de los pasos 1 y 2 más las doce
      nuevas)
- [x] La integración continua está en verde
- [x] No se agregó ninguna llave, token ni dato personal al repositorio
```

---

## 15. El texto para pegarle a Claude Code

> Lee `CLAUDE.md` y `docs/paso-3-captura-manual.md`. Haz el paso 3 completo en una rama
> `feature/captura-manual`: `Theme.swift` con los once colores y los siete niveles de
> tipografía, la carcasa de cuatro pestañas que reemplaza a `ContentView`, el caso de uso
> `RegistrarLecturaManual`, el ViewModel y la pantalla de registro manual, más las doce
> pruebas y la de recorrido. La vista no valida y el ViewModel no tiene ninguna regla
> clínica: quien valida es `Validacion.validarLectura` del paso 1, llamada desde el caso de
> uso. Ningún hex suelto fuera de `Theme.swift` y ningún número clínico fuera de
> `ConfiguracionDominio.swift`. Los requisitos son RF-01, RF-04 y RF-05, pegados completos en
> el apartado 1 bis, y el caso que no puede fallar es P-02: 900 mg/dL no se guarda. Corre las
> pruebas antes de decirme que terminaste y dime cuántas pasaron. La rama sale de `develop`,
> no de `main`, y el pull request va contra `develop`: usa como cuerpo el del apartado 14 bis
> del documento, con los apartados «Antes», «Después», «Cómo» y «Requisitos que cubre» ya
> llenos, nunca la plantilla con los comentarios puestos. El diseño de la pantalla está en
> https://www.figma.com/design/TFOHJ9wm2lhsiEk1e3595A?node-id=7-2 y su ficha escrita está en
> el apartado 7; si no puedes abrir el enlace, manda el apartado 7.
