# Modo oscuro — los once colores con su variante oscura

Documento de trabajo para Claude Code. **No es uno de los diez pasos de la fase 1**: es un
arreglo transversal que va en su propia rama y no toca nada del paso 6.

Lo que había antes: `Tema.Colores` define once colores y ninguno tiene variante oscura. Con el
iPhone en modo oscuro, el sistema pinta de oscuro lo suyo (barra de pestañas, teclado,
selector de fecha) y la app sigue pintando de claro lo nuestro. La pantalla de registro manual
del paso 3 lo tapó con `.environment(\.colorScheme, .light)` dentro de la vista y un
`.tint(.black)`, que es un parche: si las otras nueve pantallas lo copian, la app queda mitad
clara y mitad oscura para siempre.

Por qué ahora y no al final: hoy el parche está en **una** pantalla. Cada pantalla nueva que se
escriba sin variantes oscuras es una pantalla más que hay que volver a revisar.

No hay diseño en Figma para esto (las llamadas del plan Starter están gastadas). Lo que manda
es lo escrito aquí, y todos los contrastes de este documento están calculados con la fórmula
de WCAG 2.x, no estimados a ojo.

---

## 0. Antes de abrir Claude Code

### 0.1 La rama, antes que nada

```bash
cd ~/Documents/glucy-ios
git fetch origin
git switch -c feature/modo-oscuro origin/develop
git branch --show-current     # tiene que decir: feature/modo-oscuro
```

### 0.2 Xcode

No hay capacidad que marcar ni ajuste que cambiar. **No** se agrega
`INFOPLIST_KEY_UIUserInterfaceStyle`: ese ajuste fuerza un modo para toda la app, que es
justo lo que este cambio decide no hacer (ver 2.1).

```bash
grep -c "UIUserInterfaceStyle" Glucy.xcodeproj/project.pbxproj   # 0
```

### 0.3 El iPhone

Todo se puede revisar en el simulador cambiando la apariencia con ⌘⇧A. El apartado 8 bis
lleva tres comprobaciones que sí van en el iPhone, a oscuras.

---

## 1. Qué se construye, y por qué así

1. Los once colores pasan a ser **pares** claro/oscuro, y un duodécimo color nuevo,
   `textoSobreColor`, para la letra que va encima de un relleno de color.
2. iOS elige el valor según la apariencia del sistema, en el momento de dibujar. **La app no
   decide el modo**: sigue al iPhone.
3. Se quita el parche de la pantalla de registro manual.
4. Cuatro valores del modo claro se corrigen porque **no cumplían el contraste que el propio
   Documento 1 exige** (ver 2.4).
5. Una prueba por cada par de colores que se usa junto, en los dos modos. A partir de aquí,
   un color que no llega a 4.5:1 no compila verde.

---

## 2. Las seis decisiones

### 2.1 La app sigue el modo del sistema; no se fuerza claro ni se agrega interruptor

Había tres caminos:

| Camino | Por qué no / por qué sí |
| --- | --- |
| Forzar claro en toda la app (`.preferredColorScheme(.light)` en `GlucyApp.swift`) | Es el parche, pero en grande. Una pantalla blanca a las tres de la mañana deslumbra a quien se despertó con una hipoglucemia, y deja la app como la única pantalla clara de un iPhone que está en oscuro. |
| Interruptor «Claro / Oscuro / Sistema» en Ajustes | Ninguno de los 37 RF lo pide, y es una decisión más en una app que se diseña para no tener decisiones complicadas. iOS ya permite el modo oscuro automático por horario, que es lo que una persona querría. |
| **Seguir al sistema** | Lo que hace cualquier app bien hecha en iOS. Sin código de decisión, sin ajuste, sin estado. |

Se elige el tercero. Si más adelante se quiere el interruptor, se agrega en Ajustes con un
`.preferredColorScheme` en la raíz y nada de este documento cambia.

### 2.2 Los colores se vuelven dinámicos dentro de `Theme.swift`, no en el catálogo de assets

Apple ofrece dos maneras: un *color set* en `Assets.xcassets` con variante «Dark», o un
`UIColor(dynamicProvider:)` en código. Se usa la segunda:

- **Los hex siguen viviendo en un solo archivo**, que es la regla del proyecto. Con el catálogo
  quedarían repartidos en doce `Contents.json` que nadie revisa en un pull request.
- **Se pueden probar.** Los valores quedan como números en `Tema.Paleta`, y la prueba calcula
  el contraste con la misma fórmula de WCAG sin dibujar nada. Un color del catálogo solo se
  puede medir resolviéndolo en ejecución.

### 2.3 Un color nuevo: `textoSobreColor`

Hoy la letra blanca de los botones se escribe con `Tema.Colores.superficie`, porque en claro
la superficie es blanca. En oscuro la superficie es casi negra, y el botón «Guardar» quedaría
con letra oscura sobre un azul que, en oscuro, es claro: funcionaría por casualidad, y la
franja verde de «Lectura guardada» igual. Pero `superficie` significa «fondo de tarjeta», no
«letra sobre color», y el día que alguien cambie uno se rompe el otro.

`textoSobreColor` es la letra y el icono que van encima de un relleno de `azulPrimario`,
`enRango`, `hipoglucemia` o `textoSecundario` (el botón deshabilitado). Blanco en claro, casi
negro en oscuro. Es el mismo patrón que usa Material Design (`onPrimary`): en oscuro los
colores de acción se aclaran, y la letra encima pasa a ser oscura.

### 2.4 Cuatro valores del modo claro se corrigen

Al medir todos los pares que de verdad se usan juntos aparecieron cuatro que **no cumplen** el
mínimo que fija el propio Documento 1 (4.5:1 en texto, 3:1 en bordes). El comentario de
`Theme.swift` dice que los colores no se ajustan «para que se vea mejor», y eso se respeta: se
ajustan porque no cumplen la regla con la que se eligieron.

| Token | Antes | Después | El par que fallaba | Antes | Después |
| --- | --- | --- | --- | --- | --- |
| `textoSecundario` | `#6B7280` | `#667085` | etiqueta sobre `fondo` | 4.47:1 | 4.60:1 |
| `hipoglucemia` | `#D92D20` | `#CC2A1E` | texto rojo sobre `fondo` | 4.47:1 | 4.95:1 |
| `alertaAmbar` | `#F79009` | `#DC6803` | borde del aviso sobre `superficie` | 2.35:1 | 3.49:1 |
| `azulClaro` | `#BBD5FF` | `#D1E2FF` | chip elegido: letra `azulPrimario` sobre `azulClaro` | 4.14:1 | 4.72:1 |

Los cambios son de matiz, no de color: el rojo sigue siendo el mismo rojo un poco más hondo, y
el ámbar pasa del tono 500 al 600 de la misma familia. El 2.4:1 del ámbar estaba escrito a
propósito («solo borde e icono»), pero un borde también tiene mínimo, y es 3:1 (WCAG 1.4.11).

En el reporte del Avance 2 esto se dice como lo que es: una corrección de contraste
encontrada al medir.

### 2.5 Cómo se construyó la paleta oscura

No se invierte la clara. Se siguen cinco criterios, en este orden:

1. **El fondo es casi negro, no negro puro** (`#0B0F17`, un negro con un punto de azul). El
   negro puro en la pantalla OLED del iPhone 17 deja una estela al desplazarse, porque los
   píxeles apagados tardan en encenderse.
2. **La letra es casi blanca, no blanca pura** (`#EEF1F6`). El blanco puro sobre negro se
   «corre» (halación) para el tercio de la gente con astigmatismo, y de madrugada la pupila
   está dilatada y lo empeora. Con 14.9:1 sobra contraste.
3. **Las tarjetas se separan del fondo por ser más claras**, igual que en claro: sin sombras.
   En oscuro, lo que está más cerca es más claro (`#171D28` sobre `#0B0F17`).
4. **Los colores clínicos se aclaran y pierden saturación**: un rojo saturado sobre negro
   vibra y cansa. Todos quedan por encima de 4.5:1 sobre `superficie` y sobre `fondo`.
5. **El rojo de hipoglucemia se separa del verde y del ámbar también por luminosidad**, no solo
   por tono. En claro, `hipoglucemia` y `enRango` tienen la misma luminosidad (razón 1.00:1):
   en escala de grises o para alguien con deuteranopía son el mismo gris. En oscuro se separan
   (1.77:1 contra el verde, 1.60:1 contra el ámbar). Esto no sustituye la regla de que el
   color nunca va solo —cada estado lleva icono y palabra—, pero en oscuro el color ayuda en
   vez de estorbar.

### 2.6 `alertaAmbar` en oscuro vuelve a `#F79009`

Sobre negro, el ámbar brillante ya tiene 7.2:1, de sobra para borde e icono. Oscurecerlo como
en claro lo apagaría. Sigue valiendo la regla: **solo borde e icono, nunca letra**, en los dos
modos.

---

## 3. La paleta completa

Doce tokens. Esta tabla es la especificación: lo que diga `Theme.swift` tiene que coincidir
con ella valor por valor (prueba 11).

| Token | Claro | Oscuro | Uso |
| --- | --- | --- | --- |
| `azulPrimario` | `#1A56DB` | `#7EA6FF` | botones, enlaces, línea de glucosa medida, pestaña activa |
| `azulClaro` | `#D1E2FF` | `#1E3560` | fondo de la opción elegida y de las tarjetas informativas |
| `azulProfundo` | `#0B2A6B` | `#DCE6FF` | las cifras grandes de glucosa |
| `fondo` | `#F4F6FA` | `#0B0F17` | fondo de todas las pantallas |
| `superficie` | `#FFFFFF` | `#171D28` | fondo de tarjetas |
| `textoPrincipal` | `#111827` | `#EEF1F6` | títulos y texto de lectura |
| `textoSecundario` | `#667085` | `#9BA4B4` | etiquetas, unidades, pies de gráfica, botón deshabilitado |
| `enRango` | `#0B7A54` | `#5EE0A0` | texto de estado favorable, franja de «guardado» |
| `precaucion` | `#B54708` | `#FDB022` | texto de la predicción cerca de un límite |
| `alertaAmbar` | `#DC6803` | `#F79009` | **solo borde e icono** de avisos |
| `hipoglucemia` | `#CC2A1E` | `#FF6259` | episodios < 70, aviso clínico, error, borrado |
| `textoSobreColor` | `#FFFFFF` | `#0B0F17` | letra e icono **encima** de un relleno de color |

---

## 4. Los contrastes, medidos

Mínimos: 4.5:1 para texto, 3:1 para bordes e iconos (WCAG 2.2, 1.4.3 y 1.4.11).

| Par | Claro | Oscuro |
| --- | --- | --- |
| `textoPrincipal` / `superficie` | 17.74 | 14.92 |
| `textoPrincipal` / `fondo` | 16.40 | 16.94 |
| `textoSecundario` / `superficie` | 4.97 | 6.73 |
| `textoSecundario` / `fondo` | 4.60 | 7.64 |
| `azulPrimario` / `superficie` | 6.18 | 7.07 |
| `azulPrimario` / `fondo` | 5.71 | 8.02 |
| `azulProfundo` / `superficie` | 13.48 | 13.52 |
| `azulProfundo` / `fondo` | 12.46 | 15.35 |
| `enRango` / `superficie` | 5.35 | 10.18 |
| `enRango` / `fondo` | 4.94 | 11.55 |
| `precaucion` / `superficie` | 5.43 | 9.18 |
| `precaucion` / `fondo` | 5.02 | 10.42 |
| `hipoglucemia` / `superficie` | 5.36 | 5.75 |
| `hipoglucemia` / `fondo` | 4.95 | 6.52 |
| `textoSobreColor` / `azulPrimario` | 6.18 | 8.02 |
| `textoSobreColor` / `enRango` | 5.35 | 11.55 |
| `textoSobreColor` / `hipoglucemia` | 5.36 | 6.52 |
| `textoSobreColor` / `textoSecundario` | 4.97 | 7.64 |
| `azulPrimario` / `azulClaro` | 4.72 | 5.07 |
| `textoPrincipal` / `azulClaro` | 13.54 | 10.70 |
| `alertaAmbar` / `superficie` (borde) | 3.49 | 7.20 |
| `alertaAmbar` / `fondo` (borde) | 3.22 | 8.17 |

Los 44 pasan. El más justo es `textoSecundario` sobre `fondo` en claro (4.60): no se le pone
letra más chica que la etiqueta de 13 pt.

---

## 5. El código

### 5.1 `Glucy/App/Theme/Theme.swift` — la sección de colores completa

Sustituye `enum Colores` y la extensión de `Color` del final por esto. Tipografía, Espacio,
Radio y Medida no se tocan.

```swift
import SwiftUI
import UIKit

/// Un color con su valor para modo claro y su valor para modo oscuro.
///
/// Los dos viven juntos para que nadie pueda cambiar uno sin ver el otro, y como números para
/// que las pruebas midan el contraste sin dibujar nada.
struct ParDeColores: Sendable, Equatable {
    let claro: UInt32
    let oscuro: UInt32
}

enum Tema {

    /// Los valores en hexadecimal. **Este es el único sitio de la app donde aparecen.**
    ///
    /// Cada par está medido contra los fondos donde se usa, en los dos modos, y las pruebas de
    /// `ContrasteTests` fallan si uno baja de 4.5:1 en texto o de 3:1 en bordes. Aquí el
    /// contraste no es estética: la pantalla se lee de madrugada, con una hipoglucemia encima.
    /// La tabla completa con cada razón está en `docs/modo-oscuro.md`.
    enum Paleta {
        static let azulPrimario    = ParDeColores(claro: 0x1A56DB, oscuro: 0x7EA6FF)
        static let azulClaro       = ParDeColores(claro: 0xD1E2FF, oscuro: 0x1E3560)
        static let azulProfundo    = ParDeColores(claro: 0x0B2A6B, oscuro: 0xDCE6FF)

        static let fondo           = ParDeColores(claro: 0xF4F6FA, oscuro: 0x0B0F17)
        static let superficie      = ParDeColores(claro: 0xFFFFFF, oscuro: 0x171D28)

        static let textoPrincipal  = ParDeColores(claro: 0x111827, oscuro: 0xEEF1F6)
        static let textoSecundario = ParDeColores(claro: 0x667085, oscuro: 0x9BA4B4)

        static let enRango         = ParDeColores(claro: 0x0B7A54, oscuro: 0x5EE0A0)
        static let precaucion      = ParDeColores(claro: 0xB54708, oscuro: 0xFDB022)
        static let alertaAmbar     = ParDeColores(claro: 0xDC6803, oscuro: 0xF79009)
        static let hipoglucemia    = ParDeColores(claro: 0xCC2A1E, oscuro: 0xFF6259)

        static let textoSobreColor = ParDeColores(claro: 0xFFFFFF, oscuro: 0x0B0F17)
    }

    /// Los colores que usan las vistas. iOS elige el valor claro u oscuro al dibujar, según la
    /// apariencia del sistema: la app no fuerza ningún modo.
    enum Colores {
        /// Botones, enlaces, línea de glucosa medida, pestaña activa.
        static let azulPrimario = Color(Paleta.azulPrimario)
        /// Fondo de la opción elegida y de las tarjetas informativas.
        static let azulClaro = Color(Paleta.azulClaro)
        /// Las cifras grandes de glucosa.
        static let azulProfundo = Color(Paleta.azulProfundo)

        /// Fondo de todas las pantallas. En oscuro es casi negro y no negro puro: el negro
        /// puro deja estela al desplazarse en una pantalla OLED.
        static let fondo = Color(Paleta.fondo)
        /// Fondo de tarjetas. La separación se consigue con una superficie más clara que el
        /// fondo, no con sombras: se ven mal con brillo alto y bajo el sol.
        static let superficie = Color(Paleta.superficie)

        /// Títulos y texto de lectura. En oscuro es casi blanco y no blanco puro: el blanco
        /// puro sobre negro se corre para quien tiene astigmatismo.
        static let textoPrincipal = Color(Paleta.textoPrincipal)
        /// Etiquetas, unidades, pies de gráfica y el botón deshabilitado.
        static let textoSecundario = Color(Paleta.textoSecundario)

        /// Texto de estado favorable y franja de «guardado».
        static let enRango = Color(Paleta.enRango)
        /// Texto de la predicción cerca de un límite.
        static let precaucion = Color(Paleta.precaucion)
        /// **Solo borde e icono** de avisos, nunca letra, en ninguno de los dos modos.
        static let alertaAmbar = Color(Paleta.alertaAmbar)
        /// Episodios por debajo de 70, aviso clínico, error y borrado. En oscuro se separa
        /// del verde y del ámbar también por luminosidad, no solo por tono.
        static let hipoglucemia = Color(Paleta.hipoglucemia)

        /// Letra e icono **encima** de un relleno de `azulPrimario`, `enRango`,
        /// `hipoglucemia` o `textoSecundario`. No es lo mismo que `superficie`: en oscuro
        /// la superficie es casi negra y la letra sobre un botón también, pero significan
        /// cosas distintas y cambiar una no debe romper la otra.
        static let textoSobreColor = Color(Paleta.textoSobreColor)
    }

    // enum Tipografia, Espacio, Radio y Medida: sin cambios.
}

extension Color {
    /// Un color que iOS resuelve al dibujar según la apariencia del sistema.
    fileprivate init(_ par: ParDeColores) {
        self.init(uiColor: UIColor { rasgos in
            UIColor(hex: rasgos.userInterfaceStyle == .dark ? par.oscuro : par.claro)
        })
    }
}

extension UIColor {
    fileprivate convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
```

Con concurrencia estricta, el cierre de `UIColor { … }` es `@Sendable`; captura un
`ParDeColores`, que es `Sendable`, así que compila sin avisos. Si Xcode se queja, la
solución es capturar `par.claro` y `par.oscuro` en dos constantes antes del cierre, **no**
poner `@preconcurrency` ni `nonisolated(unsafe)`.

### 5.2 `Glucy/App/Theme/Contraste.swift` — nuevo

```swift
import Foundation

/// La razón de contraste de WCAG 2.x entre dos colores.
///
/// Vive en el código y no solo en un documento porque es lo que impide que un color nuevo
/// entre sin medirse: las pruebas la usan sobre cada par que de verdad se dibuja junto.
enum Contraste {

    /// De 1:1 (el mismo color) a 21:1 (negro sobre blanco). El orden de los argumentos no
    /// importa.
    static func razon(_ a: UInt32, _ b: UInt32) -> Double {
        let (la, lb) = (luminancia(a), luminancia(b))
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    /// Luminancia relativa de sRGB, con la linealización de WCAG.
    static func luminancia(_ hex: UInt32) -> Double {
        func lineal(_ canal: UInt32) -> Double {
            let c = Double(canal) / 255
            return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * lineal((hex >> 16) & 0xFF)
             + 0.7152 * lineal((hex >> 8) & 0xFF)
             + 0.0722 * lineal(hex & 0xFF)
    }
}
```

---

## 6. Lo que cambia en las vistas

Solo esto. Ninguna vista deja de usar `Tema.Colores`; lo que cambia es **cuál**.

`Glucy/Features/RegistroGlucosa/RegistroGlucosaView.swift`:

- En `fechaYHora`: **borrar** `.environment(\.colorScheme, .light)` y cambiar
  `.tint(.black)` por `.tint(Tema.Colores.azulPrimario)`.
- En el `ToolbarItem` del título «Registrar»: `.foregroundStyle(.black)` →
  `.foregroundStyle(Tema.Colores.textoPrincipal)`.
- En `botonGuardar`: `ProgressView().tint(Tema.Colores.superficie)` y
  `.foregroundStyle(Tema.Colores.superficie)` → `Tema.Colores.textoSobreColor` en los dos.
- En `franjaGuardada`: las dos `.foregroundStyle(Tema.Colores.superficie)` (la etiqueta
  «Lectura guardada» y el botón «Deshacer») → `Tema.Colores.textoSobreColor`.
- El botón de cerrar el teclado **no cambia**: ahí `superficie` es el fondo del botón, que es
  justo lo que significa.

`Glucy/Features/RegistroGlucosa/ConfirmarLecturaOcrView.swift`:

- En el botón principal: `ProgressView().tint(Tema.Colores.superficie)` y
  `.foregroundStyle(Tema.Colores.superficie)` → `Tema.Colores.textoSobreColor`.

La regla para las pantallas que vienen: **`superficie` solo va en `.background`**. Si aparece
en `.foregroundStyle` o en `.tint`, es letra sobre color y le toca `textoSobreColor`.

`GlucyApp.swift` **no se toca**. No lleva `.preferredColorScheme`.

`Assets.xcassets/AccentColor` se queda vacío: la app no lo usa, el tinte lo pone
`PestanasView` con `azulPrimario`.

Y en `glucy-base/01-glucy-ios.md` (archivos del proyecto) la tabla de tokens ya está
actualizada con las dos columnas; eso lo hizo el hilo, no hay que tocarlo desde la Mac.

---

## 7. Las pruebas que tienen que pasar

Archivo nuevo `GlucyTests/ContrasteTests.swift`, con Swift Testing como las demás.

| # | Qué prueba | Por qué |
| --- | --- | --- |
| 1 | negro sobre blanco da 21:1 y un color sobre sí mismo da 1:1 | la fórmula está bien escrita |
| 2 | `razon(a, b) == razon(b, a)` | el orden no importa |
| 3 | `#1A56DB` sobre blanco da 6.18 ± 0.01 | coincide con el 6.2:1 del Documento 1 |
| 4 | **modo claro**: los siete colores de texto (`textoPrincipal`, `textoSecundario`, `azulPrimario`, `azulProfundo`, `enRango`, `precaucion`, `hipoglucemia`) sobre `superficie` y sobre `fondo`, todos ≥ 4.5 | WCAG 1.4.3 |
| 5 | **modo oscuro**: los mismos catorce pares, ≥ 4.5 | WCAG 1.4.3 |
| 6 | `textoSobreColor` sobre `azulPrimario`, `enRango`, `hipoglucemia` y `textoSecundario`, en los dos modos, ≥ 4.5 | la letra de los botones y la franja |
| 7 | `azulPrimario` y `textoPrincipal` sobre `azulClaro`, en los dos modos, ≥ 4.5 | el chip elegido |
| 8 | `alertaAmbar` sobre `superficie` y sobre `fondo`, en los dos modos, ≥ 3.0 | WCAG 1.4.11, borde e icono |
| 9 | `superficie` y `fondo` son distintos en los dos modos (razón > 1.05) | la tarjeta se separa del fondo sin sombra |
| 10 | `UIColor(Tema.Colores.hipoglucemia)` resuelto con `UITraitCollection(userInterfaceStyle: .dark)` da `#FF6259`, y con `.light` da `#CC2A1E` (tolerancia de 1/255 por canal) | el color dinámico de verdad cambia con el modo |
| 11 | los doce pares de `Tema.Paleta` son **exactamente** los de la tabla del apartado 3 | nadie cambia un color sin cambiar el documento |
| 12 | en oscuro, `razon(hipoglucemia, enRango) ≥ 1.5` y `razon(hipoglucemia, precaucion) ≥ 1.5` | el rojo se distingue por luminosidad, no solo por tono (2.5, criterio 5) |

Las pruebas 4 a 8 conviene escribirlas con `@Test(arguments:)` sobre una lista de pares, para
que cuando una falle el nombre diga cuál par fue. Algo así:

```swift
@Test("Texto sobre fondo, modo oscuro", arguments: ParesDeTexto.todos)
func textoOscuro(_ par: (nombre: String, frente: ParDeColores, fondo: ParDeColores)) {
    #expect(Contraste.razon(par.frente.oscuro, par.fondo.oscuro) >= 4.5, "\(par.nombre)")
}
```

### 7 bis. En el iPhone físico

- [ ] **A oscuras, con el brillo al mínimo**: abrir «Registrar» en modo oscuro y leer la cifra,
  las etiquetas y el botón sin entrecerrar los ojos.
- [ ] Cambiar de claro a oscuro desde el Centro de control **con la pantalla abierta**: todo
  cambia a la vez, sin una tarjeta que se quede blanca.
- [ ] Ajustes → Accesibilidad → Pantalla → **Escala de grises**, en oscuro: el mensaje de error
  rojo se sigue reconociendo por su icono y su texto.

---

## 8. Cómo se sabe que está hecho

- Las 12 pruebas nuevas pasan, más todas las anteriores.
- La integración continua está en verde.
- Ninguno de estos `grep` devuelve nada:

```bash
grep -rn "colorScheme, .light\|preferredColorScheme" Glucy/
grep -rnE "\.(black|white)\b|Color\((red|white):" Glucy/Features/
grep -rnE "(foregroundStyle|tint)\(Tema\.Colores\.superficie\)" Glucy/
grep -rn "0x[0-9A-Fa-f]\{6\}" Glucy/ | grep -v "Glucy/App/Theme/Theme.swift"
```

- En el simulador, ⌘⇧A con «Registrar» abierta cambia toda la pantalla, incluida la tarjeta
  de fecha y hora.

---

## 9. Lo que NO entra

- **Interruptor de apariencia en Ajustes.** Ver 2.1. Si se quiere, va en el paso de Ajustes.
- **Variantes para «Aumentar contraste»** (`accessibilityContrast == .high`). Los contrastes
  de este documento ya pasan con margen; si se agregan, va como tercera columna de
  `ParDeColores` y no cambia ninguna vista.
- **Ícono de la app en oscuro.** El catálogo ya trae el hueco; es diseño, no código.
- Tocar Tipografía, Espacio, Radio o Medida.
- Cualquier cosa del paso 6: ni `Comida`, ni Open Food Facts, ni la migración V3. Este cambio
  no toca el modelo de datos.

---

## 10. Git

```bash
git switch -c feature/modo-oscuro origin/develop
# …trabajo…
git add -A
git commit -m "feat: modo oscuro con los doce colores medidos en los dos modos"
git push -u origin feature/modo-oscuro
gh pr create --base develop --head feature/modo-oscuro --web
```

**El pull request va contra `develop`, no contra `main`.** Y no se fusiona hasta que la
integración continua termine en verde: no «en curso», verde.

---

## 10 bis. El cuerpo del pull request, ya escrito

```markdown
## Antes

Glucy solo tenía colores claros. Con el iPhone en modo oscuro, la barra de pestañas y el
teclado se ponían oscuros y las pantallas de la app seguían blancas. La pantalla de registro
lo tapaba forzando el modo claro dentro de la vista, y ninguna otra pantalla tenía arreglo.

## Después

La app sigue el modo del iPhone. En oscuro, el fondo es casi negro, las tarjetas un poco más
claras, la letra casi blanca, y el rojo de hipoglucemia, el verde de «en rango» y el ámbar de
precaución se aclaran lo justo para leerse de madrugada sin deslumbrar. Cambiar de modo con la
pantalla abierta cambia todo a la vez.

Cuatro colores del modo claro se ajustaron un matiz porque, medidos, no llegaban al contraste
mínimo que pide el propio diseño: el gris de las etiquetas y el rojo sobre el fondo, el borde
ámbar de los avisos y la letra del chip elegido.

## Cómo

Cada color pasó a ser un par claro/oscuro en `Tema.Paleta`, y `Tema.Colores` los entrega como
colores dinámicos que iOS resuelve al dibujar. Los hex siguen viviendo solo en `Theme.swift`.
Se agregó `textoSobreColor` para la letra encima de un botón o una franja de color, que antes
se escribía con `superficie` y en oscuro habría dejado de ser cierta.

`Contraste.razon` implementa la fórmula de WCAG, y `ContrasteTests` la aplica a cada par que
de verdad se dibuja junto, en los dos modos. Un color que baje de 4.5:1 en texto o de 3:1 en
borde deja la integración continua en rojo.

## Requisitos que cubre

- **Accesibilidad del Documento 1** — contraste mínimo 4.5:1 en texto y 3:1 en bordes, ahora
  comprobado por prueba en los dos modos.
- **Regla de interfaz** — el color nunca es el único portador de información; en oscuro el rojo
  de hipoglucemia además se separa por luminosidad del verde y del ámbar.

## Comprobado

- [x] Las pruebas pasan en local (<número> en total, 12 nuevas)
- [x] La integración continua está en verde
- [x] No quedó ningún `.colorScheme, .light`, `.black` ni `.white` en las vistas
- [x] Ningún hex fuera de `Theme.swift`

Comprobado en el iPhone físico:

- [x] A oscuras y con el brillo al mínimo, «Registrar» se lee sin esfuerzo
- [x] Cambiar de modo con la pantalla abierta cambia todo a la vez
- [x] En escala de grises el error sigue reconociéndose por icono y texto
```

---

## 11. El texto para pegarle a Claude Code

> Lee `CLAUDE.md` y `docs/modo-oscuro.md`. Trabaja en una rama `feature/modo-oscuro` que sale
> de `develop` (`git switch -c feature/modo-oscuro origin/develop`); **no trabajes en `main`
> ni en `develop`**. Haz el cambio completo: en `Theme.swift`, `ParDeColores`, `Tema.Paleta`
> con los doce pares exactamente como la tabla del apartado 3, y `Tema.Colores` como colores
> dinámicos con `UIColor(dynamicProvider:)`; el archivo nuevo `Contraste.swift`; los cambios
> de vista del apartado 6; y las 12 pruebas de `GlucyTests/ContrasteTests.swift`.
>
> Lo que **no** hay que hacer: no forzar ningún modo (ni `.preferredColorScheme` en
> `GlucyApp.swift` ni `UIUserInterfaceStyle` en el proyecto), porque la app sigue al
> sistema; no crear *color sets* en `Assets.xcassets`, porque los hex viven solo en
> `Theme.swift`; no cambiar ningún valor de la tabla «para que se vea mejor», porque cada uno
> está medido; no usar `superficie` como color de letra, para eso es `textoSobreColor`; no
> tocar Tipografía, Espacio, Radio ni Medida; y no tocar nada del paso 6.
>
> Corre las pruebas antes de decirme que terminaste y dime cuántas pasaron. Corre también los
> cuatro `grep` del apartado 8 y confirma que no devuelven nada. Después sube la rama y
> **abre el pull request contra `develop`** con el cuerpo del apartado 10 bis
> (`gh pr create --base develop --head feature/modo-oscuro`); no basta con subir la rama,
> porque sin pull request la integración continua no corre. No lo fusiones tú.
