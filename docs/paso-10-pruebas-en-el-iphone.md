# Paso 10 bis — Las pruebas en el iPhone, conducidas por Claude Code

Documento de trabajo para Claude Code. **No es un paso nuevo**: es el apartado 9 de
`docs/paso-10-cierre.md` convertido en algo que se puede correr, en vez de dieciocho casillas
que alguien marca de memoria a las once de la noche.

El problema que resuelve. El código de la fase 1 está completo y en verde: 250 pruebas en 46
suites. Pero la integración continua corre `-only-testing:GlucyTests` sobre un **simulador**,
así que hoy nada ha comprobado en un teléfono de verdad ni la letra de accesibilidad, ni el
modo avión, ni que el PDF del informe lleve o no el nombre, ni que revocar el permiso de Salud
no tumbe la app. Y de las diecinueve casillas de la lista solo está marcada una, la del
arranque en frío.

La idea de este documento es repartir el trabajo donde cada uno sirve:

- **Lo que una prueba puede afirmar, lo afirma una prueba** y corre en el iPhone, no en el
  simulador.
- **Lo que depende de un interruptor del teléfono** (modo avión, permiso de Salud revocado,
  sensor apagado) lo pone la persona y lo comprueba una prueba, guiada por un script que va
  pidiendo cada cosa a su turno.
- **Lo que solo se puede ver**, se ve, pero **sin navegar diez pantallas a mano**: la prueba
  recorre y captura, y después se revisan las capturas juntas, en color y en gris.
- **Lo que solo se puede oír** —que Audio Graphs suene y en qué orden lee VoiceOver— se queda
  a oído, porque no hay otra forma honesta. Son dos casillas, no dieciocho.

---

## 0. Antes de empezar

1. El iPhone conectado por cable, **desbloqueado**, y el Mac autorizado en él.
2. `xcrun devicectl list devices` para tener su identificador. Si ese comando no lo lista,
   `xcrun xctrace list devices`. **Ese identificador va al script, no a mano en cada corrida.**
3. **VoiceOver APAGADO** mientras corren las pruebas. VoiceOver intercepta los toques y
   `XCUITest` deja de poder tocar nada: las pruebas fallarían por eso y no por la app. Las
   afirmaciones sobre las etiquetas de accesibilidad valen igual con VoiceOver apagado, porque
   la etiqueta es la misma; lo único que necesita VoiceOver encendido es escucharlo, y eso es
   el apartado 6.
4. Las pruebas de interfaz arrancan con `-GlucyBaseEnMemoria`, así que **no tocan los datos
   reales de quien las corre**. Eso ya está hecho desde el paso 9 y hay que mantenerlo: una
   prueba que borre el historial de una persona de verdad es un error que no se puede deshacer.

---

## 1. Las diecinueve casillas, repartidas

`A` = lo afirma una prueba · `E` = la persona pone el estado del teléfono y lo afirma una
prueba · `C` = la prueba captura y la persona revisa la captura · `O` = solo a ojo o a oído.

| # | Casilla del apartado 9 | Cómo | Dónde queda |
| --- | --- | --- | --- |
| 1 | Las diez pantallas con la letra más grande: todo se alcanza, nada se sale de ancho | **A** | `AccesibilidadUITests`, ya existe — ahora corre **en el iPhone** |
| 2 | Registrar una glucosa con esa letra, de punta a punta | **A** | `AccesibilidadUITests`, ya existe |
| 3 | La cifra de Inicio y su unidad no se enciman con esa letra | **C** | captura de Inicio a AX5 |
| 4 | Nada truncado con puntos suspensivos en las diez pantallas | **C** | la galería de capturas |
| 5 | Las ocho filas de la tabla del color, entendibles sin color | **C** | la galería, convertida a gris en el Mac |
| 6 | La gráfica con sensor: la continua se distingue de una punteada | **C** | captura de Inicio con sensor |
| 7 | La gráfica sin sensor: los de fuera de escala son triángulos | **C** | captura de Inicio sin sensor |
| 8 | Inicio lee primero el valor con su unidad y su antigüedad | **A** (el contenido) + **O** (el orden) | apartado 4 |
| 9 | Historial lee las tres cifras con su unidad y su `n` | **A** | apartado 4 |
| 10 | Las dos gráficas tienen descripción | **A** | apartado 4 |
| 11 | **Audio Graphs suena** en las dos | **O** | apartado 6 |
| 12 | El alta completa con VoiceOver | **O** | apartado 6 |
| 13 | Con «reducir movimiento», el splash desaparece en vez de desvanecerse | **E** | apartado 5 |
| 14 | Modo avión: glucosa, comida manual y dosis se guardan y la cola las cuenta | **E** | apartado 5 |
| 15 | Modo avión: el código de barras lleva a la foto y luego a lo manual, no a un error | **E** | apartado 5 |
| 16 | El PDF **sin** el interruptor no trae nombre ni peso | **A** | apartado 3, y es mejor que a ojo |
| 17 | El PDF **con** el interruptor sí los trae | **A** | apartado 3 |
| 18 | El PDF se ve bien en Archivos y la gráfica sale dibujada | **C** + **O** | apartado 3 |
| 19 | Revocar Salud no tumba la app (P-09) | **E** | apartado 5 |
| 20 | La serie no se duplica tras reiniciar (P-14) | **E** | apartado 5 |
| 21 | Con sensor y la app del sensor cerrada, sale la franja nueva | **E** | apartado 5 |

Son veintiuna líneas porque dos casillas del documento llevaban dos cosas dentro. **Quedan dos
en `O` puro**, la 11 y la 12, más el ojo final de la 18. Todo lo demás se corre o se revisa en
una galería.

---

## 2. Lo que hay que construir

```
scripts/pruebas-en-el-iphone.sh            el conductor: pide cada estado y corre lo que toca
GlucyTests/InformePdfTests.swift           lee el PDF de vuelta con PDFKit (casillas 16 y 17)
GlucyUITests/VozUITests.swift              las etiquetas que VoiceOver va a leer (8, 9, 10)
GlucyUITests/CapturasUITests.swift         recorre y captura las diez pantallas (3-7, 18)
GlucyUITests/EntornoDelTelefonoUITests.swift  las que dependen de un interruptor (13-15, 19-21)
```

No se toca ni el dominio ni ninguna vista, **salvo** lo que el apartado 7 lista como
identificadores que faltan. Si para afirmar algo hace falta cambiar una vista, es que faltaba
un identificador, no que la prueba necesite otra cosa.

---

## 3. El informe: el PDF se lee de vuelta, no se mira

Las casillas 16 y 17 decían «abrirlo y comprobarlo, no suponerlo». Se puede hacer mejor que
eso: **PDFKit abre el archivo y devuelve su texto**, así que la prueba afirma lo que una
persona tendría que leer a ojo, y lo afirma cada vez.

```swift
@MainActor
struct InformePdfTests {
    /// Casilla 16. Con el interruptor apagado, el nombre no está en el archivo. No «no se
    /// ve»: no está, y eso es lo que importa cuando el PDF se va por correo.
    @Test func sinIdentidadElPdfNoTraeElNombre() async throws { … }

    /// Casilla 17. Con el interruptor encendido, sí.
    @Test func conIdentidadElPdfTraeElNombre() async throws { … }
}
```

Cómo, sin inventar nada:

1. Un perfil de prueba con un nombre **que no pueda aparecer por casualidad** en una plantilla:
   no «Jesús», sino algo como `Zzyzx` y apellido `Qwertyuiop`. Si se busca «Jesús» y la hoja
   dice «Jesús» en otro sitio, la prueba pasa por el motivo equivocado.
2. `ArmarInforme.ejecutar(dias:conIdentidad:ahora:)` con el interruptor en cada posición.
3. `GeneradorDePdf().generar(InformeView(informe:), nombre:)`.
4. `PDFDocument(url:)` y su `string`. Afirmar que **no contiene** el nombre, el apellido ni el
   peso con el interruptor apagado, y que **sí** los contiene encendido.
5. Afirmar en las dos posiciones que el PDF **nunca** contiene el `uuid` del perfil ni la
   palabra que usan las notas. Eso es la regla 3 comprobada, no prometida.
6. Afirmar que el texto trae el aviso de que no es un dispositivo médico certificado. Si una
   plantilla cambia y ese párrafo se cae, nadie lo notaría nunca.
7. `generador.borrar(url)` al final de cada prueba, y una prueba más que afirme que **después
   de `cerrar()` el archivo ya no existe**.

Si `PDFDocument(url:).string` devuelve vacío, **no se da por bueno**: querría decir que el PDF
salió como una imagen rasterizada sin capa de texto, y entonces la casilla 16 no se puede
afirmar así y hay que decirlo en vez de dejar una prueba que no prueba nada. En ese caso la
prueba se cambia a afirmar sobre el `Informe` —que `identidad` sea `nil`— y la del archivo se
queda en `O`, dicho en el documento.

La casilla 18, que el PDF «se vea bien» en Archivos y en Correo, se queda a ojo: eso no es una
afirmación, es un juicio.

---

## 4. Las etiquetas que VoiceOver va a leer

VoiceOver apagado. Lo que se afirma es **el contenido** de las etiquetas, que es lo que
VoiceOver dice; el **orden** en que lo dice se oye en el apartado 6.

```swift
/// Casilla 8. La etiqueta del valor lleva la cifra, su unidad y su antigüedad. Una cifra sola
/// no sirve: «112» no dice si es de ahora o de hace tres horas.
func testElValorSeLeeConSuUnidadYSuAntiguedad()
```

- `app.otherElements["valorActual"].label` contiene `"miligramos por decilitro"` y alguna
  marca de antigüedad. **No** se afirma el texto completo palabra por palabra: una prueba que
  fija la frase entera se rompe cada vez que se mejora la redacción, y entonces se borra.
- `letreroDelModo` existe y su etiqueta nombra el modo.
- Casilla 9: `cifraTiempoEnRango`, `cifraPromedio` y `cifraGmi` existen y su `label` trae la
  unidad (`por ciento`, `miligramos por decilitro`) y sobre cuántas mediciones se calculó.
  Con la base en memoria y una sola lectura, el GMI no es fiable: la prueba afirma que la
  etiqueta **dice por qué** y no que haya un número.
- Casilla 10: en Inicio y en Historial, el elemento `graficaGlucosa` existe y su `label` **no
  está vacía**. Que además tenga `accessibilityChartDescriptor` no se puede leer desde
  `XCUITest`; lo que sí hay es una prueba de dominio que ya fija el descriptor
  (`GraficaGlucosaTests`), así que entre las dos queda cubierto.
- Casilla 12, el alta con VoiceOver: aquí **sí** se puede afirmar algo útil sin VoiceOver. Que
  cada control del alta tenga etiqueta: recorrer los cinco pasos y afirmar que ningún
  `button` ni `textField` alcanzable tiene `label` vacía. Un control sin etiqueta es
  exactamente lo que deja a alguien atascado, y se detecta sin oír nada. Oírlo de verdad sigue
  siendo del apartado 6.

---

## 5. Las que dependen del teléfono: el estado lo pone la persona, la prueba lo comprueba

Cada una de estas pruebas empieza con un `XCTSkipUnless` sobre una variable de entorno. Así
**no fallan nunca por no estar en el estado correcto**: se saltan y dicen qué hacía falta. Una
prueba que falla cuando el teléfono no está como ella quiere acaba desactivada, y con ella se
van las que sí servían.

```swift
func testEnModoAvionTodoSeGuardaYLaColaLoCuenta() throws {
    try XCTSkipUnless(
        ProcessInfo.processInfo.environment["GLUCY_MODO_AVION"] == "1",
        "Pon el modo avión y corre con GLUCY_MODO_AVION=1"
    )
    …
}
```

| Variable | Qué tiene que estar puesto en el teléfono | Qué afirma |
| --- | --- | --- |
| `GLUCY_MODO_AVION=1` | modo avión encendido | casilla 14: registra glucosa, comida **manual** y dosis; las tres salen en Inicio o en Historial y `pendientesEnCola` cuenta tres. Casilla 15: `campoCodigoDeBarras` con un código válido lleva a `botonFotoDeEtiqueta` y de ahí a `campoCarbohidratos`, y **no** aparece ningún `falloComida` que hable de error de conexión |
| `GLUCY_REDUCIR_MOVIMIENTO=1` | «Reducir movimiento» encendido | casilla 13: el `splash` desaparece entre dos fotogramas. Se afirma lo afirmable: que `splash` existe al arrancar y que a los 0.6 s ya no existe y las pestañas sí. Que no haya desvanecido es la captura |
| `GLUCY_SALUD_REVOCADA=1` | perfil con sensor y el permiso de glucosa **negado** en la app Salud | casilla 19 (P-09): la app arranca, llega a las pestañas, `avisoSinSensor` está visible y no hay ningún diálogo de error |
| `GLUCY_SENSOR_CALLADO=1` | perfil con sensor y la app del sensor cerrada hace más de 15 min | casilla 21: `textoSinDatosDelSensor` existe, su texto **no** contiene «conexión», y `botonReintentarSensor` se puede tocar |
| `GLUCY_SALUD_CON_DATOS=1` | Salud con lecturas del sensor y alguna escrita por Glucy | casilla 20 (P-14): se cuenta cuántas lecturas hay en Historial, se cierra y se vuelve a abrir la app, y el número **es el mismo**. Si se duplicara, aquí se vería |

**La casilla 20 es la más importante de las seis y la que menos se puede comprobar de otra
forma.** Duplicar la serie del sensor en cada arranque es el tipo de defecto que no se nota
hasta que alguien lleva tres semanas de datos y su promedio no cuadra. Si esta prueba no se
puede correr porque no hay un sensor prestado todavía, **se dice en las notas del release** en
lugar de marcar la casilla.

Dos avisos de mecánica:

- Con el **modo avión encendido** las pruebas siguen corriendo: `xcodebuild` habla con el
  teléfono por el cable, no por red. Lo que no funciona con el avión es la base de Open Food
  Facts, que es justo lo que se quiere comprobar.
- La base en memoria (`-GlucyBaseEnMemoria`) hace que el alta se recorra cada vez. Para
  `GLUCY_SALUD_CON_DATOS` eso es un problema, porque hace falta un perfil **con sensor**: esa
  prueba recorre el alta eligiendo «Con sensor» y aceptando la hoja de Salud. Hay que agregar
  a `Ayudas.swift` un `completarAltaConSensor()` al lado del que ya existe.

---

## 6. Lo que se queda a oído, y cómo se hace en diez minutos

Dos cosas, y solo dos:

**Casilla 11, Audio Graphs.** Con VoiceOver encendido, enfocar la gráfica de Inicio, hacer el
gesto de tres dedos hacia arriba, elegir «Audio Graph» y comprobar que **suena** y que el tono
sube y baja con los valores. Lo mismo en el día típico de Historial. Si no aparece la opción,
el descriptor no está llegando y eso sí es un defecto que arreglar.

**Casilla 12, el alta con VoiceOver.** Con VoiceOver encendido, completar el alta entera
deslizando y tocando dos veces, sin mirar la pantalla. Lo que se busca no es que sea cómodo,
es que **no haya un punto del que no se pueda salir**: un control sin etiqueta, un paso que no
anuncia que cambió, un botón que no se alcanza deslizando.

**Casilla 8, el orden.** Con VoiceOver encendido, en Inicio, deslizar desde arriba: lo primero
tiene que ser el valor con su unidad y su antigüedad, y después el aviso de sin sensor. Si lee
primero la gráfica, el `accessibilitySortPriority` no está haciendo su trabajo.

Las tres se hacen de corrido en una sola sesión con VoiceOver encendido, y después se apaga
para volver a correr lo demás.

---

## 7. Identificadores que faltan y hay que agregar

Para afirmar lo de arriba hacen falta estos, y no hay ninguno hoy. Se agregan **solo** como
`accessibilityIdentifier`; ninguna etiqueta visible cambia.

| Identificador | Dónde | Para qué |
| --- | --- | --- |
| `tarjetaConSensor` | `AltaView`, paso 3 | `completarAltaConSensor()` |
| `pasoDelAlta` | `AltaView`, el contenedor | afirmar en qué paso va sin depender del botón |
| `totalDeLecturas` | `HistorialView` | contar lecturas antes y después de reiniciar (casilla 20) |
| `avisoDelInforme` | `InformeView` | que el aviso clínico esté en la hoja |

Si para afirmar algo hiciera falta cambiar una vista más allá de agregar un identificador,
**no se cambia**: se dice en el informe final que esa casilla se queda a ojo. Las pruebas se
adaptan a la app, no al revés.

---

## 8. El script que lo conduce

`scripts/pruebas-en-el-iphone.sh`. Lo que tiene que hacer, en este orden:

1. Encontrar el iPhone conectado y **decir cuál encontró** (nombre, iOS y identificador). Si
   hay más de uno o ninguno, parar y decirlo; nunca elegir por su cuenta.
2. Avisar de que VoiceOver tiene que estar apagado y esperar un Enter.
3. **Bloque sin estado especial**, de corrido: `GlucyTests` completo (incluidas las del PDF) y
   después `GlucyUITests` sin las de entorno. Es lo que hoy no corre en un teléfono.
4. **Bloque de capturas**: `CapturasUITests` dos veces, una con la letra normal y otra con
   `AccessibilityXXXL`.
5. **Bloque por estado**: para cada una de las cinco variables del apartado 5, pedir el estado
   en una línea («Enciende el modo avión y pulsa Enter; escribe `s` para saltarla»), y correr
   solo esa prueba con su variable puesta. Saltarse una tiene que ser posible y quedar
   anotado.
6. Sacar las capturas del `.xcresult` a una carpeta, y **hacer una copia en gris de cada una**
   con `sips`, para revisar la casilla 5 sin depender de que el filtro de color del teléfono
   salga en la captura.
7. Imprimir al final un resumen: **qué casillas quedaron afirmadas, cuáles saltadas y cuáles
   siguen siendo de ojo o de oído**, con sus números. Ese resumen es lo que se pega en las
   notas del release.

Sobre el punto 6: la forma de exportar adjuntos de un `.xcresult` **cambió entre versiones de
Xcode**. No hay que escribir de memoria los parámetros de `xcresulttool`: hay que correr
`xcrun xcresulttool --help` y `xcrun xcresulttool get test-results --help` en el Mac, usar lo
que diga esa versión, y dejarlo comentado en el script con la versión de Xcode con la que se
probó. Un script con parámetros inventados falla en el primer uso y hace perder la tarde.

El script **no fusiona nada, no etiqueta nada y no toca git**. Corre pruebas y escribe un
resumen.

---

## 9. Cómo se sabe que esto está hecho

- `./scripts/pruebas-en-el-iphone.sh` corre de principio a fin en el iPhone y termina con su
  resumen.
- `GlucyTests` pasa en el teléfono, no solo en el simulador, **con las pruebas del PDF
  dentro**.
- `GlucyUITests` pasa en el teléfono con la letra normal y con `AccessibilityXXXL`.
- Las cinco pruebas de entorno, o pasan, o están saltadas **con su motivo escrito**.
- Hay una carpeta con las capturas de las diez pantallas en los dos tamaños de letra, y su
  copia en gris.
- `grep -rn "accessibilityLabel" Glucy/Features/Alta/` no es la forma de comprobarlo: lo que
  cuenta es que la prueba del apartado 4 no encuentre ningún control del alta con etiqueta
  vacía.
- El apartado 9 de `docs/paso-10-cierre.md` queda actualizado: cada casilla marcada **dice
  cómo** se comprobó (prueba, captura u ojo), y las que no se pudieron comprobar quedan sin
  marcar con su motivo.

---

## 10. Lo que esto NO hace

- **No mete XCUITest en la integración continua.** Un simulador en un runner compartido ya
  costó una tarde de corridas colgadas, y estas pruebas necesitan un teléfono y una persona
  que encienda el modo avión. Esto se corre a mano antes de etiquetar, y la CI sigue siendo
  `GlucyTests` en el simulador.
- **No cambia ninguna vista** más allá de agregar los cuatro identificadores del apartado 7.
- **No toca `Theme.swift`**, ni ningún `@Model`, ni ninguna etapa de migración.
- **No automatiza lo que no se puede automatizar.** Si una prueba no puede afirmar algo, se
  dice y la casilla se queda a ojo. Una prueba que pasa sin comprobar nada es peor que no
  tenerla, porque da permiso para dejar de mirar.

---

## 11. Git

```bash
git switch -c feature/pruebas-en-el-iphone origin/develop
# …trabajo…
git add -A
git commit -m "test: las pruebas del apartado 9 corren en el iPhone, conducidas por un script"
git push -u origin feature/pruebas-en-el-iphone
gh pr create --base develop --head feature/pruebas-en-el-iphone
```

### El cuerpo del pull request, ya escrito

```markdown
## Antes

El apartado 9 de `docs/paso-10-cierre.md` eran diecinueve casillas que alguien tenía que
marcar navegando la app a mano, en el tamaño de letra más grande, en escala de grises, con
VoiceOver, en modo avión y con el permiso de Salud revocado. Solo una estaba marcada. La
integración continua corre en un simulador y con `-only-testing:GlucyTests`, así que las
pruebas de interfaz nuevas del paso 10 nunca se habían ejecutado en un teléfono, y que el PDF
del informe no llevara el nombre de la persona dependía de que alguien lo abriera y mirara.

## Después

`./scripts/pruebas-en-el-iphone.sh` recorre todo en el iPhone conectado: las pruebas de
dominio, las de interfaz en los dos tamaños de letra, las capturas de las diez pantallas, y
las cinco que dependen de un interruptor del teléfono, pidiendo cada estado a su turno y
permitiendo saltarlo. Al final imprime qué casillas quedaron afirmadas, cuáles saltadas y
cuáles siguen siendo de ojo o de oído.

De las diecinueve casillas, dos siguen necesitando oído: que Audio Graphs suene y en qué orden
lee VoiceOver. El resto se afirma o se revisa en una galería de capturas, con su copia en
gris.

## Cómo

Las pruebas que dependen del teléfono empiezan con `XCTSkipUnless` sobre una variable de
entorno, así que se saltan y dicen qué hacía falta en lugar de fallar.

Que el PDF del informe no lleve el nombre ya no se mira: `PDFDocument` lo abre y la prueba
afirma sobre su texto, en las dos posiciones del interruptor, con un nombre que no puede
aparecer por casualidad.

Cuatro identificadores nuevos de accesibilidad y ningún cambio de interfaz. Sin migración, sin
colores nuevos, y la CI se queda como estaba.

## Comprobado

- El script completo en el iPhone 17, con su resumen.
- Las pruebas del PDF en las dos posiciones del interruptor.
- Las cinco de entorno: las que se pudieron poner, pasan; las que no, saltadas con su motivo.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

https://claude.ai/code/session_01U7KrWasYkZhWRhqUnQcJ86
```

---

## 12. El texto para pegarle a Claude Code

> Lee `CLAUDE.md`, `docs/paso-10-cierre.md` (sobre todo su apartado 9) y
> `docs/paso-10-pruebas-en-el-iphone.md`. Trabaja en una rama
> `feature/pruebas-en-el-iphone` que sale de `develop`
> (`git switch -c feature/pruebas-en-el-iphone origin/develop`); **no trabajes en `main` ni en
> `develop`**. Construye lo del apartado 2: el script, las pruebas del PDF con PDFKit, las de
> las etiquetas de voz, las de capturas y las cinco que dependen del teléfono, más los cuatro
> identificadores del apartado 7.
>
> **Tengo el iPhone conectado**: corre todo en el teléfono, no en el simulador. Antes de
> empezar, dame el identificador del dispositivo que encontraste para que yo confirme que es
> el mío.
>
> **Las pruebas que dependen de un interruptor del teléfono se saltan con `XCTSkipUnless` y un
> mensaje que diga qué hacía falta; no fallan.** Una prueba que falla porque el teléfono no
> está como ella quiere acaba desactivada y se lleva por delante a las demás.
>
> **No metas XCUITest en la integración continua.** La CI se queda exactamente como está:
> `GlucyTests` en el simulador. Esto se corre a mano.
>
> **No cambies ninguna vista más allá de agregar los cuatro identificadores del apartado 7.**
> Si para afirmar algo hiciera falta cambiar una vista, no lo cambies: dímelo y esa casilla se
> queda a ojo. Las pruebas se adaptan a la app, no al revés. No toques `Theme.swift`, ningún
> `@Model` ni ninguna etapa de migración.
>
> **Para exportar las capturas del `.xcresult` no escribas de memoria los parámetros de
> `xcresulttool`**: corre `xcrun xcresulttool --help` y `xcrun xcresulttool get test-results
> --help`, usa lo que diga tu versión de Xcode y déjalo comentado en el script con esa
> versión.
>
> **Si `PDFDocument(url:).string` sale vacío, dímelo en vez de dejar una prueba que no prueba
> nada**: querría decir que el PDF salió sin capa de texto, y entonces esas dos casillas
> cambian de forma.
>
> Cuando termines, corre el script completo conmigo aquí para que yo vaya poniendo el modo
> avión, el filtro de gris y lo demás cuando me lo pida. Después **actualiza el apartado 9 de
> `docs/paso-10-cierre.md`**: marca cada casilla que quedó comprobada diciendo **cómo** se
> comprobó, y deja sin marcar las que no, con su motivo. Y sube la rama y **abre el pull
> request contra `develop`** con el cuerpo del apartado 11
> (`gh pr create --base develop --head feature/pruebas-en-el-iphone`); sin pull request la
> integración continua no corre. **Espera a que el run termine y dime su resultado antes de que
> yo lo fusione**: «cancelado» no es verde. No lo fusiones tú.
