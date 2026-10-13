# Paso 9 — Alta del perfil, ajustes y el cierre del alcance de la fase 1

Documento de trabajo para Claude Code. Es el **noveno de los diez pasos** de la fase 1
(`glucy-base/04-PLAN-FASE-1.md`), y el que convierte la app en algo que una persona puede
instalar y empezar a usar sin que nadie le meta datos a mano.

Lo que hay hasta ahora: las cuatro pestañas funcionan menos Ajustes, se registra glucosa por
tres vías, comida e insulina, y el inicio y el historial ya dibujan. Pero **no hay alta**: la
app arranca sin preguntar nada, pide el permiso de HealthKit sola al arrancar y no existe el
consentimiento que la ley exige para datos de salud.

El criterio de «hecho» del plan es una frase y conviene leerla antes que nada:

> Se puede completar el alta eligiendo «Sin sensor» y sin dar ningún permiso, y la app queda
> usable.

Este paso cierra además tres contradicciones abiertas entre los documentos del proyecto
(C-1, C-2 y C-3 de `05-PENDIENTES-Y-CONTRADICCIONES.md`), y una de ellas es la más delicada
de todo el proyecto: la pantalla de ajustes dibujada en Figma pide los tres números con los
que se calcula una dosis de insulina. El apartado 2.3 explica por qué no entran y por qué la
integración continua ya los rechazaría sola.

Mockups: https://www.figma.com/design/TFOHJ9wm2lhsiEk1e3595A — pantalla 1 (`4-2`), pantalla 2
(`4-8`) y pantalla 9 (`10-2`). Ábrelos tú para comparar; lo que manda es lo escrito aquí, y en
tres puntos este documento **corrige** el dibujo a propósito.

---

## 0. Antes de abrir Claude Code

### 0.1 La rama, antes que nada

```bash
cd ~/Documents/glucy-ios
git fetch origin
git switch -c feature/alta-y-ajustes origin/develop
git branch --show-current     # tiene que decir: feature/alta-y-ajustes
```

`origin/develop` ya tiene que llevar el paso 8 dentro:

```bash
ls Glucy/Features/Inicio/ Glucy/Features/Historial/
ls Glucy/Domain/Rules/DiaTipico.swift
```

### 0.2 Xcode: esta vez sí hay algo que agregar, y va en los dos sitios

Face ID necesita su propia llave de uso en el Info.plist. Es el mismo tropiezo del paso 0 y
del paso 4: **un ajuste puesto con un solo renglón seleccionado en Xcode vale solo para ese
renglón**, y la vez pasada la llave de HealthKit quedó solo en Debug.

Con el **proyecto** seleccionado (el renglón de arriba, no el target), en *Info*, agrega:

```
Privacy - Face ID Usage Description
Glucy puede pedirte Face ID para abrir la app, para que tu historial de glucosa no quede a
la vista de quien tome tu teléfono desbloqueado.
```

Y compruébalo. Tiene que decir **2**, una por configuración, igual que las tres que ya están:

```bash
grep -c "INFOPLIST_KEY_NSFaceIDUsageDescription" Glucy.xcodeproj/project.pbxproj   # 2
grep -o "INFOPLIST_KEY_NS[A-Za-z]*" Glucy.xcodeproj/project.pbxproj | sort | uniq -c
# 2 INFOPLIST_KEY_NSCameraUsageDescription
# 2 INFOPLIST_KEY_NSFaceIDUsageDescription
# 2 INFOPLIST_KEY_NSHealthShareUsageDescription
# 2 INFOPLIST_KEY_NSHealthUpdateUsageDescription
```

No hay capacidad nueva que marcar: `LocalAuthentication` no la pide.

### 0.3 El iPhone

Este paso es el que **más** necesita el teléfono físico, porque tres cosas no existen en el
simulador: Face ID de verdad (el simulador lo simula y nunca falla como falla el real), la
hoja de permisos de Salud con una cuenta que tiene datos, y el borrado de muestras de Salud.
El apartado 8 bis lleva siete comprobaciones.

---

## 1. Qué se construye en el paso 9, y por qué va ahora

Cuatro pantallas, y una de ellas es la primera que la persona ve en su vida:

- **Pantalla 1, el splash.** Fondo azul lleno y el eslogan completo. Se retira sola.
- **Pantalla 2, el alta del perfil.** Los campos de F-1, las dos tarjetas de sensor del mismo
  tamaño y el consentimiento expreso con su fecha.
- **Pantalla 9, Ajustes.** Los parámetros que el cálculo sí usa, la sincronización solo por
  wifi con su contador, la privacidad enumerada y borrar la cuenta.
- **El candado**, que no es una pantalla del Documento 1 pero sí un requisito no funcional:
  Face ID o Touch ID para abrir la app.

Va ahora, y no antes, porque el alta tiene que preguntar por cosas que hasta este punto no
existían: la duración de acción de la insulina no se podía pedir antes del paso 7, y el
interruptor de ocultar insulina no tenía sentido sin la pantalla que oculta. Y va antes del
paso 10 porque el paso 10 repasa **las diez pantallas** en el tamaño de letra más grande, y
tres de ellas se escriben aquí.

---

## 1 bis. Los requisitos, pegados

### RF-06 (fase 1), la parte que toca a este paso

> La app solicita permiso de lectura de HealthKit sobre HKQuantityTypeIdentifier.bloodGlucose
> y toma de ahí las lecturas que escribió la app del sensor comercial (Dexcom, FreeStyle
> Libre). Usa HKObserverQuery con enableBackgroundDelivery para recibir las muestras nuevas
> sin que la app esté abierta. **El onboarding permite saltarse este paso: tener sensor es
> opcional.** Ya no hay emparejamiento Bluetooth: los protocolos BLE de esos sensores son
> cerrados y no están documentados.

La lectura ya está construida desde el paso 4. Lo que falta, y es de este paso, es la frase
en negritas.

### RF-07 (fase 1)

> El usuario puede cambiar de modo en cualquier momento: si activa la lectura de HealthKit
> después de meses de captura manual, el histórico previo se conserva y se integra. También
> puede revocar el permiso desde Salud sin que la app deje de funcionar; simplemente vuelve al
> modo sin sensor.

### RF-10b (fase 1), que en este paso toca **el onboarding**

> En modo sin sensor, la app declara de forma explícita y visible que no puede anticipar
> hipoglucemias, **tanto en el onboarding** como en la pantalla de inicio.

El paso 8 cumplió la mitad de la pantalla de inicio. La otra mitad es la tarjeta «Sin sensor»
del alta, que tiene que decirlo antes de que la persona elija, no después.

### RF-14 (fase 1), la parte que falta

> El registro de insulina (unidades, tipo rápida o basal, hora) es parte central del flujo
> diario del usuario principal, y alimenta la estimación de insulina activa. **Para el usuario
> secundario se puede ocultar desde ajustes.**

El campo `registraInsulina` existe desde el paso 7 y nadie lo puede cambiar todavía.

### Los cuatro requisitos no funcionales que manda este paso

> **Autenticación.** Tokens JWT de corta vigencia con rotación; **Face ID o Touch ID para
> abrir la app.**

> **Normatividad.** LFPDPPP (**consentimiento expreso para datos de salud**) y
> NOM-024-SSA3-2012.

> **Privacidad del nombre.** Nombre y apellidos son opcionales y nunca se sincronizan. El
> backend solo conoce un UUID.

> **Seguridad clínica.** El sistema registra la insulina que el usuario dice haberse aplicado;
> **nunca calcula ni sugiere una dosis.**

### Y el formulario F-1 del Documento 3, pegado tal cual

| Campo | Tipo | Obligatorio | Validación | Para qué sirve |
| --- | --- | --- | --- | --- |
| nombre | Texto corto, máx. 40 | No | Solo letras, espacios y acentos | Para que la app hable con la persona por su nombre y para encabezar el informe que exporte. Se queda en el teléfono y nunca se sincroniza (principio 3). |
| apellidos | Texto corto, máx. 60 | No | Igual | Solo si la persona lo quiere. Sirve para el informe que le lleve a su médico. Mismo trato: no sube. |
| tipo_usuario | Opción: tipo 1 · tipo 2 insulinodependiente · prediabetes · resistencia a la insulina | Sí | Una de las cuatro | Decide qué pantallas se muestran y qué alertas aplican. |
| anio_nacimiento | Entero | Sí | Edad resultante ≥ 15 | Criterio de inclusión. **Se guarda el año, no la fecha completa.** |
| peso_kg | Decimal, kilogramos | No | 25–300 | Sirve para el informe que la persona le lleva a su médico y para que vea su propia evolución junto con la glucosa. Es opcional, editable en cualquier momento y se queda en el teléfono. |
| unidad_preferida | Opción: mg/dL · mmol/L | Sí | — | HealthKit permite al usuario elegir su unidad y expone preferredUnits(for:). Internamente todo se guarda en mg/dL. |
| umbral_hipo | Entero, mg/dL | No (por omisión 70) | 50–90 | Define cuándo dispara la alerta y cómo se calcula el TBR. |
| umbral_hiper | Entero, mg/dL | No (por omisión 180) | 140–300 | Igual, para el TAR. |
| tipo_insulina_rapida | Texto corto | Solo insulinodependientes | — | Determina la curva de acción de la insulina activa. |
| duracion_accion_insulina | Entero, horas | No (por omisión 5) | 2–8 | Parámetro DIA. |
| consentimiento_aceptado | Booleano + fecha | Sí | **Verdadero para continuar** | La LFPDPPP exige consentimiento expreso para datos de salud. |
| sincronizacion_activa | Booleano | No (por omisión falso) | — | El usuario decide si sus datos suben. En falso, la app funciona completa y nada sale del teléfono. |
| lectura_healthkit_activa | Booleano | No (por omisión falso) | — | Indica si el usuario autorizó que Glucy lea la glucosa que escribe la app de su sensor comercial. Se puede activar o revocar en cualquier momento; al revocarlo la app vuelve al modo sin sensor sin perder nada. |

> Lo que este formulario no pide, a propósito: CURP, dirección, teléfono, correo, número de
> expediente y **estatura**. Ninguno alimenta al modelo y todos aumentarían el daño de una
> fuga.

---

## 2. Las nueve decisiones del paso 9

### 2.1 La cuarta migración: cinco campos que F-1 pide y el perfil no tiene

Al comparar F-1 con `Perfil` tal como quedó en el paso 7 faltan cinco. Cuatro son de F-1 y el
quinto es del requisito de autenticación:

```swift
nonisolated enum EsquemaGlucyV5: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(5, 0, 0) }
    static var models: [any PersistentModel.Type] { /* las mismas diez */ }
}

// etapa nueva, sin tocar las tres anteriores:
.lightweight(fromVersion: EsquemaGlucyV4.self, toVersion: EsquemaGlucyV5.self)
```

Y en `Perfil`:

```swift
/// Cuándo la persona aceptó, en UTC. `nil` significa **que no ha aceptado**, y mientras
/// sea `nil` la app no entra: la LFPDPPP exige consentimiento expreso para datos de salud
/// y un booleano sin fecha no sirve para demostrar cuándo se dio.
var consentimientoTsUtc: Date?

/// En qué unidad quiere ver sus cifras. Adentro **todo se guarda en mg/dL**; esto solo
/// cambia cómo se muestran y cómo se interpreta lo que teclea.
var unidadPreferida: UnidadGlucosa = .mgDl

/// El nombre comercial de su insulina rápida, tal como ella lo escriba. Es texto libre a
/// propósito: una lista cerrada se queda corta en cuanto cambie de marca o de país.
/// `nil` en quien no se aplica insulina.
var tipoInsulinaRapida: String?

/// Nace en `false`: nada sale del teléfono hasta que la persona lo decida (F-1). En la
/// fase 1 no hay servidor todavía, así que encenderlo solo llena la cola.
var sincronizacionActiva: Bool = false

/// Si la app pide Face ID o Touch ID al abrirse. Nace **apagado**: ver el apartado 2.6.
var bloqueoBiometrico: Bool = false
```

Los cinco son opcionales o tienen valor por omisión, así que la etapa ligera basta y las tres
anteriores no se tocan. **Cambiar un `@Model` sin versionarlo borra la base al arrancar**, y
ya van cuatro migraciones: `MigracionEsquemaV5Tests` tiene que abrir la V4 con datos dentro y
comprobar que al pasar a la V5 el perfil sigue ahí con sus valores y los campos nuevos en su
omisión.

Y `consentimientoTsUtc` **no sube al backend** por sí mismo en la fase 1, pero sí es de los
que subirán en la fase 2: el Documento 3, sección 9, dice que el consentimiento vive en los
dos lados y es revocable con borrado total en ambos.

### 2.2 El año de nacimiento, no la fecha: la forma barata de arreglarlo

F-1 es explícito: «Se guarda el año, no la fecha completa», y es el principio 1, minimización.
Pero `Perfil` quedó desde el paso 1 con `fechaNacimiento: Date`, que guarda el día exacto.

Hay dos maneras de arreglarlo:

| Cómo | Qué cuesta |
| --- | --- |
| Cambiar el campo a `anioNacimiento: Int` | **Una etapa de migración personalizada**, la primera del proyecto: cambiar el tipo de un campo no es una etapa ligera. Es exactamente donde las bases se borran. |
| **Dejar el `Date` y no capturar nunca el día** | El formulario pide **solo el año**, y lo que se guarda es el **1 de enero de ese año**. Ninguna fecha de nacimiento precisa entra nunca a la base. |

**Se hace la segunda.** El dato minimizado es el que no se captura, y con el formulario pidiendo
solo el año el día exacto no existe aunque el campo pudiera guardarlo. Lo fija una prueba: el
`Date` que guarda el alta tiene mes 1 y día 1, siempre.

Si más adelante se quiere el `Int` limpio, es una etapa personalizada en su propia rama y con
su propia prueba de migración, no un cambio de paso. No se mete aquí.

La edad se calcula del año, contra `ConfiguracionDominio.edadMinima`, que es 15. Y se valida
**antes** de poder continuar, no al guardar: quien tiene 14 años no debe llegar a llenar el
resto del formulario para que al final se le diga que no.

### 2.3 C-2 cierra: los tres números de la pantalla 9 no entran, y la CI ya los rechaza

Esta es la decisión más importante del paso.

La ficha de la pantalla 9 en Figma dice que Ajustes guarda «relación insulina/carbohidratos,
factor de sensibilidad y dosis basal, que son las tres cifras que su médico le dio y que el
cálculo de insulina activa necesita». Las dos mitades de esa frase son falsas:

1. **La insulina activa no las necesita.** Necesita el tipo de insulina y la duración de
   acción, que sí están en F-1 y sí entran. La curva de `Insulina.iob` no toma ninguna de las
   tres.
2. **Esas tres cifras son, exactamente, las entradas de un calculador de bolo.** Relación
   insulina/carbohidratos más factor de sensibilidad más glucosa objetivo es la fórmula con la
   que se calcula una dosis. Es la regla 7 del proyecto y la frontera con un dispositivo médico
   regulado.

Así que **no entran, ni como campos de solo consulta.** Y aquí está lo bueno: ya no depende de
que alguien se acuerde. El paso 7 dejó `scripts/regla-7.sh` corriendo como primer paso de la
integración continua, y entre sus comprobaciones está esta:

```bash
grep -rnwiE --include='*.swift' 'ratio|sensibilidad' Glucy
```

Un campo llamado `factorSensibilidad` o `ratioCarbohidratos` pone la CI en rojo antes de
compilar. La prohibición está en el código, no en un documento.

**Lo que Ajustes sí edita**, todo ya en `Perfil`:

| Sección | Campos |
| --- | --- |
| Tus datos | nombre, apellidos, peso, año de nacimiento, tipo de usuario |
| Cómo ves tus cifras | unidad preferida (mg/dL · mmol/L) |
| Tus umbrales | umbral hipo (50–90), umbral hiper (140–300) |
| Insulina | tipo de insulina rápida, duración de acción (2–8 h), **registrar insulina** (sí/no) |
| Comidas | tiempo de absorción por omisión (30 · 180 · 300) |
| Sensor | lectura de HealthKit activa, con lo que pasa al apagarla |
| Sincronización | solo por wifi (fijo, explicado), activa (sí/no), pendientes en la cola |
| Privacidad | la enumeración del apartado 2.8 |
| Seguridad | Face ID o Touch ID al abrir |
| — | **Borrar mi cuenta**, en rojo, al final |

Y una línea fija en la sección de Insulina, porque es donde alguien buscaría los tres números
y hay que decirle que no están y por qué:

> Glucy no calcula dosis. Guarda estos dos datos porque con ellos estima cuánta insulina
> sigue trabajando, no cuánta deberías aplicarte.

### 2.4 C-1 y C-3 cierran de un renglón cada una

- **C-1, la altura: no se captura.** La ficha de la pantalla 2 la pide; F-1 la nombra entre lo
  que el formulario no pide a propósito. Manda F-1, que es el documento que razona por qué
  existe cada campo: la altura no alimenta al modelo, no entra en ningún indicador y no hace
  falta para el informe. El modelo de datos nunca la tuvo, así que **en el código no hay nada
  que hacer**: el formulario simplemente no la pregunta. Lo que hay que corregir es la ficha
  del mockup, y eso no es trabajo de Claude Code.
- **C-3, los tipos de diabetes: las cuatro.** La ficha ofrece tres; `TipoUsuario` define
  cuatro y la resistencia a la insulina es uno de los dos segmentos secundarios declarados del
  proyecto. Dejarla fuera del alta sería reconocerla como usuaria y no dejarla entrar.

Y de C-3 sale una decisión de comportamiento que conviene escribir: **`registraInsulina` nace
calculado del tipo de usuario.**

```swift
/// RF-14: el usuario secundario no se aplica insulina y una pestaña que no usa le estorba.
/// Nace calculado y queda editable en Ajustes: lo que la persona elija después gana.
static func registraInsulinaPorOmision(para tipo: TipoUsuario) -> Bool {
    switch tipo {
    case .tipo1, .tipo2Insulinodependiente: true
    case .prediabetes, .resistenciaInsulina: false
    }
}
```

Así quien entra como prediabético nunca ve la pantalla de dosis, sin tener que ir a apagarla.

### 2.5 El consentimiento es la puerta, y el alta se termina sin dar un solo permiso

Dos reglas, y la segunda es el criterio de «hecho» del plan.

**La puerta es el consentimiento, no el perfil.** La raíz de la app decide entre el alta y las
pestañas con `consentimientoTsUtc != nil`, **no** con `perfil.existe()`. Un perfil a medias
—alguien que cerró la app en el segundo paso del alta— existe y no ha consentido, y dejarlo
entrar sería guardar datos de salud sin la base legal para hacerlo. Al volver, el alta sigue
donde estaba con lo que ya tecleó.

**Ningún permiso es obligatorio.** Las dos tarjetas de sensor, del mismo tamaño y una al lado
de la otra:

| | Con sensor | Sin sensor |
| --- | --- | --- |
| Qué dice | «Tengo un sensor (Dexcom, FreeStyle Libre) y su app escribe en Salud» | «Me mido con glucómetro» |
| Qué hace al tocarla | pide el permiso de lectura de Salud, con su explicación antes de la hoja del sistema | nada, no pide nada |
| Qué pasa si la persona dice que no en la hoja de Salud | **el alta continúa**, en modo sin sensor | — |
| Qué advierte | — | **«Sin sensor no puedo anticipar hipoglucemias»**, antes de elegir (RF-10b) |

Un permiso negado **no es un error** y no lleva a ninguna pantalla de error: lleva al modo sin
sensor, que es un modo completo. Y como iOS no dice nunca si hay permiso de lectura (devuelve
`notDetermined` aunque esté concedido, a propósito), el alta no intenta comprobarlo: guarda lo
que la persona declaró en `usaSensor` y **el modo real lo sigue decidiendo `DecisionModo`** con
la frescura de la última lectura, igual que desde el paso 4. El campo del alta es una
declaración de intención, no un estado.

Esto también quita el apaño del paso 4. En `GlucyApp.init` hay un comentario que lo anuncia:

> Pedir el permiso al arrancar es provisional: el onboarding del paso 9 lo va a pedir con su
> explicación y permitirá saltárselo.

Ese `Task { await sincronizar.iniciar() }` se queda —el observador tiene que registrarse en el
arranque o se pierde la entrega en segundo plano—, pero **la petición de permiso sale de ahí**
y se va a la tarjeta «Con sensor».

### 2.6 Face ID bloquea, no protege, y nunca deja a nadie fuera

Tres decisiones, y la tercera es de seguridad clínica.

1. **`LAPolicy.deviceOwnerAuthentication`, no `deviceOwnerAuthenticationWithBiometrics`.** La
   primera acepta el código del teléfono cuando no hay biometría o cuando falla tres veces. Con
   la segunda, quien no tiene Face ID configurado jamás podría abrir su propia app.
2. **Nace apagado.** La persona lo enciende en Ajustes si quiere. Una app de salud que se
   bloquea sola el primer día, sin que nadie lo pidiera, se desinstala.
3. **Si algo falla, la app se abre.** Si `LAContext` no puede evaluar la política —no hay
   hardware, no hay código, el servicio no responde—, se entra. Es lo contrario de lo que haría
   una app de banco, y es a propósito: **a las tres de la mañana, con una hipoglucemia encima,
   una app que no abre es peor que una app que alguien podría espiar.** El dato ya está cifrado
   por el dispositivo; este candado solo estorba a quien levante un teléfono desbloqueado.

Y hay que decirlo en la pantalla, porque si no se lee como lo que no es:

> Esto no cifra nada: tu iPhone ya cifra tus datos. Solo evita que alguien que tome tu teléfono
> desbloqueado vea tu historial.

El candado se dibuja sobre la app, no en lugar de ella, y vuelve a pedirse al regresar de
segundo plano pasado un rato. No se pide al cambiar de pestaña.

### 2.7 Borrar la cuenta: la única barrera del proyecto, y también borra en Salud

Es la única acción irreversible de la app y la única que merece barrera (Documento 1, punto 8).
Tres partes:

1. **Enumera qué se pierde**, con los números de verdad leídos de la base: «Vas a borrar 412
   lecturas, 96 comidas y 140 dosis, tu perfil y tus ajustes.» Un «¿estás seguro?» sin cifras
   no informa de nada.
2. **Obliga a escribir la palabra `borrar`.** No una casilla, no un toque largo: teclear.
3. **Borra también lo que Glucy escribió en Salud, y solo eso.** Es el otro lado de RF-15b: si
   la app escribió sus lecturas, sus carbohidratos y sus dosis en Salud, dejarlas ahí después de
   borrar la cuenta sería no haber borrado nada. Pero **nunca** se toca lo que escribió la app
   del fabricante del sensor: se distingue por `HKSource.default()`, igual que al leer.

Hace falta un método nuevo en el servicio, porque los que hay borran de uno en uno por UUID:

```swift
/// Borra de Salud **solo** las muestras que escribió Glucy, distinguidas por
/// `HKSource.default()`. Lo del sensor comercial no se toca: no es nuestro, y borrarlo
/// dejaría a la persona sin su serie en Salud por haber borrado su cuenta de Glucy.
func eliminarTodoLoPropio() async throws
```

Si Salud falla o no hay permiso de escritura, **el borrado local se hace igual** y la pantalla
lo dice: «Borré todo lo de Glucy. No pude borrar lo que había escrito en Salud; puedes
quitarlo desde la app Salud.» Media verdad dicha es mejor que un borrado que se detiene a la
mitad.

Al terminar, la app vuelve al splash y al alta, como recién instalada.

### 2.8 La privacidad enumera; no resume

La ficha de la pantalla 9 dice que la privacidad «enumera» lo que no sale del teléfono, y es
una palabra elegida: «respetamos tu privacidad» no es información. La lista sale del Documento
3, sección 3.3, y va completa:

> **Esto nunca sale de tu teléfono:**
> - Tu nombre y tus apellidos
> - Tu peso
> - Tus notas
> - Las fotos del glucómetro y de las etiquetas: se leen y se descartan, no se guardan
> - Los productos que consultaste por código de barras
>
> **Esto sube solo si tú enciendes la sincronización:** tus lecturas, tus comidas, tus dosis y
> tu contexto, bajo un identificador que no dice quién eres.

Y debajo, la verdad del estado actual, que es de fase 1 y hay que decirla:

> Todavía no hay servidor: aunque enciendas la sincronización, por ahora nada sale de tu
> teléfono. Los registros esperan en la cola.

La sincronización por wifi **no es un interruptor**, es una línea fija que explica el
comportamiento, porque D-10 lo cerró y no es configurable:

> Glucy sincroniza solo con wifi, por lotes. No usa tus datos móviles.

El contador de pendientes sale de `RepositorioCola.contarPendientes()`, que existe desde el
paso 2.

### 2.9 El splash no hace esperar a nadie

Pantalla 1: la única con fondo azul lleno, el eslogan completo —«Tu glucosa, media hora
antes»— y el logo. Tres reglas:

- **Se retira sola**, nunca espera un toque.
- **No bloquea el arranque.** El paso 10 mide el arranque en frío contra «menos de 2 segundos
  hasta ver el valor actual». Un splash que se queda 1.5 segundos por decoración se come casi
  todo ese presupuesto. Así que se dibuja **mientras** se abre la base y se lee el perfil, y se
  va en cuanto eso termina, con un mínimo de 0.4 s para que no parpadee.
- **Respeta «reducir movimiento»**: sin la preferencia, se desvanece; con ella, desaparece.

---

## 3. Archivos que hay que crear o tocar

```
Glucy/Data/SwiftData/
  EsquemaGlucy.swift                   la V5 y su etapa ligera
  EsquemasAnteriores.swift             se congela la V4; las otras no se tocan
  PerfilSwiftData.swift                los cinco campos nuevos

Glucy/Domain/Models/
  Perfil.swift                         los cinco campos nuevos
  Datos/PerfilDato.swift               los mismos

Glucy/Domain/Rules/
  Validacion.swift                     se amplía: validarPerfil
  ReglasDePerfil.swift        NUEVO    registraInsulinaPorOmision, edad, año

Glucy/Domain/UseCases/
  CompletarAlta.swift         NUEVO    la única puerta que escribe el consentimiento
  GuardarAjustes.swift        NUEVO
  BorrarTodo.swift            NUEVO    local + lo propio de Salud
  ConsultarCuantoHay.swift    NUEVO    las cifras que enumera el borrado

Glucy/Data/HealthKit/
  ServicioHealthKit.swift              + eliminarTodoLoPropio()
  HealthKitReal.swift                  su implementación, por HKSource.default()

Glucy/Data/Seguridad/
  CandadoBiometrico.swift     NUEVO    LocalAuthentication detrás de un protocolo

Glucy/Features/Splash/
  SplashView.swift            NUEVO    pantalla 1

Glucy/Features/Alta/
  AltaView.swift              NUEVO    pantalla 2
  AltaViewModel.swift         NUEVO

Glucy/Features/Ajustes/
  AjustesView.swift           NUEVO    pantalla 9
  AjustesViewModel.swift      NUEVO
  BorrarCuentaView.swift      NUEVO    la barrera

Glucy/Features/Candado/
  CandadoView.swift           NUEVO

Glucy/
  GlucyApp.swift                       la raíz decide: splash → alta o candado → pestañas
Glucy/Features/Pestanas/
  PestanasView.swift                   el último PendienteView se va

GlucyTests/
  MigracionEsquemaV5Tests.swift   NUEVO
  CompletarAltaTests.swift        NUEVO
  ReglasDePerfilTests.swift       NUEVO
  BorrarTodoTests.swift           NUEVO
  GuardarAjustesTests.swift       NUEVO
  Dobles/CandadoFalso.swift       NUEVO

GlucyUITests/
  AltaUITests.swift               NUEVO
```

**No aparece `Theme.swift`.** El splash es el único sitio con fondo azul lleno, y ese azul es
`azulPrimario` con la letra en `textoSobreColor`; no hace falta ningún color nuevo. Recuerda
que `superficie` solo va en `.background`.

---

## 4. Las firmas

```swift
/// La única puerta que escribe el consentimiento. Vive en un caso de uso y no en el
/// ViewModel porque es la base legal para guardar datos de salud, no un campo más.
nonisolated struct CompletarAlta: Sendable {
    let perfil: any RepositorioPerfil
    let salud: any ServicioHealthKit

    /// - Parameter aceptaConsentimiento: si llega `false`, **no se guarda nada** y se
    ///   devuelve el rechazo. No hay forma de crear un perfil sin consentimiento.
    /// - Parameter anioNacimiento: solo el año (F-1). El `Date` que se guarda es el 1 de
    ///   enero de ese año: así el día exacto no entra nunca a la base.
    /// - Parameter ahora: se pasa, no se toma de `Date()` dentro, para poder probarlo.
    func ejecutar(
        nombre: String,
        apellidos: String,
        tipoUsuario: TipoUsuario,
        anioNacimiento: Int,
        pesoKg: Double?,
        unidadPreferida: UnidadGlucosa,
        usaSensor: Bool,
        aceptaConsentimiento: Bool,
        ahora: Date = Date()
    ) async throws -> PerfilDato

    /// Pide el permiso de lectura de Salud con su explicación ya mostrada. **Nunca lanza
    /// hacia la vista**: un permiso negado no es un error, es el modo sin sensor.
    func pedirPermisoDeSalud() async -> Bool
}

nonisolated enum ReglasDePerfil {
    /// `nil` si el año sirve. Se valida antes de dejar continuar, no al guardar.
    static func validarAnio(_ anio: Int, ahora: Date) -> Rechazo?
    static func edad(anioNacimiento: Int, ahora: Date) -> Int
    /// El 1 de enero del año, en UTC. Es lo que se guarda (apartado 2.2).
    static func fechaDeAnio(_ anio: Int) -> Date
    static func registraInsulinaPorOmision(para tipo: TipoUsuario) -> Bool
}

nonisolated struct CuantoHay: Sendable, Equatable {
    let lecturas: Int
    let comidas: Int
    let dosis: Int
}

nonisolated struct BorrarTodo: Sendable {
    let perfil: any RepositorioPerfil
    let lecturas: any RepositorioLecturas
    let comidas: any RepositorioComidas
    let dosis: any RepositorioDosis
    let cola: any RepositorioCola
    let salud: any ServicioHealthKit

    /// Borra todo lo local y, después, lo que Glucy escribió en Salud. Devuelve `false` en
    /// `saludLimpia` si Salud falló: **el borrado local se hace igual** y la pantalla lo
    /// dice. Un borrado a medias en silencio es peor que uno que se explica.
    @discardableResult
    func ejecutar() async throws -> (saludLimpia: Bool)
}

/// `LocalAuthentication` detrás de un protocolo, como HealthKit y Vision: así las pruebas
/// no necesitan un teléfono con Face ID.
nonisolated protocol Candado: Sendable {
    /// `true` si se puede entrar. **Devuelve `true` si la política no se puede evaluar**
    /// (sin hardware, sin código, el servicio no responde): ver el apartado 2.6.
    func pedirEntrada(motivo: String) async -> Bool
}
```

---

## 5. El alta, paso por paso

Cinco pantallas en un `NavigationStack`, con el progreso visible y **ninguna que no se pueda
dejar a medias**. Al reabrir la app, el alta vuelve donde iba.

| # | Qué pide | Se puede saltar |
| --- | --- | --- |
| 1 | Nombre y apellidos | **sí**, los dos son opcionales (F-1) |
| 2 | Tipo de usuario (las cuatro opciones) y año de nacimiento | no |
| 3 | Las dos tarjetas de sensor, del mismo tamaño | no, pero «Sin sensor» no pide nada |
| 4 | Umbrales, unidad, peso, y si se aplica insulina: tipo y duración de acción | **sí**, todos tienen omisión salvo la unidad |
| 5 | El consentimiento, con el texto completo y su fecha | **no, y es la única que no** |

La pantalla 5 no es una casilla al pie de un párrafo que nadie lee. Lleva el texto completo
—qué datos se guardan, dónde, que nada identificable sube, que es revocable y que se puede
borrar todo—, la fecha visible, y el botón dice **«Acepto»**, no «Continuar». Debajo, en
`textoSecundario`, la línea que ya está en el README y en el aviso de la app:

> Glucy no es un dispositivo médico certificado y no sustituye la indicación de tu médico.
> Informa; no prescribe ni administra.

---

## 6. Lo que este paso NO construye, y no es por falta de tiempo

Es trabajo, no una advertencia. Si algo de esta lista aparece en el diff, el paso está mal.

1. **Ningún campo de relación insulina/carbohidratos, factor de sensibilidad o dosis basal**,
   ni editable ni de solo consulta ni «para que la persona lo tenga apuntado». Apartado 2.3.
   La CI lo rechaza sola.
2. **Ninguna función que devuelva unidades de insulina** ni ninguna frase que diga cuánto
   aplicarse, ni envuelta en condicional. Es la regla 7.
3. **Ninguna altura.** C-1.
4. **Ninguna sincronización de verdad.** No hay servidor hasta la fase 2. El interruptor se
   guarda, la cola cuenta, y la pantalla dice que todavía nada sale del teléfono.
5. **Ninguna exportación del informe.** RF-16 la pide y el plan la pone en el paso 10, aunque
   el nombre y el peso se capturen aquí «para el informe».
6. **Ningún inicio de sesión, cuenta, correo ni contraseña.** No hay servidor y no hay cuenta:
   «borrar mi cuenta» borra lo que hay en el teléfono. La palabra «cuenta» se usa porque es la
   que la persona entiende, no porque exista una.
7. **Ningún token ni llave en `UserDefaults`.** No hay ninguno que guardar todavía; cuando lo
   haya, va al Keychain.
8. **Ninguna etapa de migración personalizada.** Apartado 2.2.
9. **Nada de Face ID obligatorio**, ni de una app que se queda cerrada si la biometría falla.
   Apartado 2.6.
10. **Ningún permiso pedido sin explicarlo antes.** La hoja del sistema sale después de una
    pantalla que dice para qué, nunca de golpe.

---

## 7. Textos, palabra por palabra

**La tarjeta «Sin sensor» del alta** (RF-10b, en el onboarding):

> **Me mido con glucómetro**
> Registras tus mediciones a mano o con una foto. Sin sensor no puedo anticipar
> hipoglucemias: te enseño lo que has medido, no lo que va a pasar.

**La tarjeta «Con sensor»:**

> **Tengo un sensor**
> Dexcom o FreeStyle Libre, con su app escribiendo en Salud. Glucy lee de ahí; no necesitas
> emparejar nada.

**Antes de la hoja de permisos de Salud:**

> Glucy va a pedirte permiso para **leer** tu glucosa de la app Salud. Nada más: no escribe
> encima de lo de tu sensor y no sale de tu teléfono. Si dices que no, la app funciona igual
> en modo sin sensor.

**Si el permiso se niega:**

> Listo, seguimos sin sensor. Puedes activarlo cuando quieras desde Ajustes.

**La línea fija de la sección de Insulina en Ajustes** (apartado 2.3):

> Glucy no calcula dosis. Guarda estos dos datos porque con ellos estima cuánta insulina sigue
> trabajando, no cuánta deberías aplicarte.

**El interruptor de Face ID:**

> **Pedir Face ID al abrir**
> Esto no cifra nada: tu iPhone ya cifra tus datos. Solo evita que alguien que tome tu teléfono
> desbloqueado vea tu historial.

**El apagado de la lectura de Salud:**

> Si lo apagas, Glucy deja de leer tu sensor y vuelve al modo sin sensor. **No pierdes nada**:
> tu historial se queda completo.

**La barrera de borrar:**

> **Borrar mi cuenta**
> Vas a borrar 412 lecturas, 96 comidas y 140 dosis, tu perfil y tus ajustes. También quito de
> Salud lo que Glucy escribió; lo que escribió la app de tu sensor se queda.
> Esto no se puede deshacer y no hay copia en ningún servidor.
> Escribe **borrar** para confirmar.

**Si Salud falla al borrar:**

> Borré todo lo de Glucy. No pude borrar lo que había escrito en Salud; puedes quitarlo desde
> la app Salud.

**El splash:**

> Glucy
> Tu glucosa, media hora antes

---

## 8. Las pruebas que tienen que pasar

Veintiséis. Las de la migración corren **en serie** con las de la V3 y la V4: abren varios
esquemas en un mismo proceso.

| # | Qué prueba | Por qué |
| --- | --- | --- |
| 1 | la V5 abre una base V4 con un perfil dentro y conserva sus valores | la etapa ligera no borra nada |
| 2 | tras migrar, `consentimientoTsUtc` es `nil` y los otros cuatro traen su omisión | un perfil viejo no queda «consentido» por accidente |
| 3 | las etapas de la V2, V3 y V4 siguen exactamente igual | se agrega una etapa, no se reescriben |
| 4 | `CompletarAlta` con `aceptaConsentimiento: false` **no guarda nada** y devuelve rechazo | no hay forma de crear un perfil sin consentimiento |
| 5 | con `true`, guarda y `consentimientoTsUtc` es el `ahora` que se le pasó | la fecha es la de verdad, no una aproximada |
| 6 | el `Date` guardado tiene **mes 1 y día 1** | apartado 2.2: el día exacto no entra nunca |
| 7 | `validarAnio` con una edad de 14 rechaza; con 15, pasa | `edadMinima`, criterio de inclusión |
| 8 | `validarAnio` con un año futuro rechaza | lo mismo que la marca de tiempo futura |
| 9 | `registraInsulinaPorOmision` da `true` en tipo 1 y tipo 2 insulinodependiente | RF-14 |
| 10 | y `false` en prediabetes y resistencia a la insulina | RF-14, C-3 |
| 11 | el alta acepta **las cuatro** opciones de `TipoUsuario` | C-3 |
| 12 | el alta se completa con nombre y apellidos vacíos | F-1: los dos son opcionales |
| 13 | el alta se completa con `usaSensor: false` **sin llamar a `pedirPermisos`** | el criterio de «hecho» del plan |
| 14 | `pedirPermisoDeSalud` con un doble que lanza devuelve `false` y **no propaga** | un permiso negado no es un error |
| 15 | y el alta se completa igual después de ese `false` | RF-06: tener sensor es opcional |
| 16 | `GuardarAjustes` con umbral hipo 95 rechaza; con 85 pasa | `umbralHipoConfigurable` 50–90 |
| 17 | con duración de acción de 9 h rechaza; con 8, pasa | `duracionAccionConfigurableH` 2–8 |
| 18 | con peso de 10 kg rechaza; con 70, pasa | 25–300 kg |
| 19 | apagar `registraInsulina` se guarda y se vuelve a leer | RF-14 |
| 20 | `BorrarTodo` deja los cinco repositorios en cero | que borre de verdad |
| 21 | `BorrarTodo` llama a `eliminarTodoLoPropio` **una vez** | el otro lado de RF-15b |
| 22 | con Salud lanzando, el borrado local se hace igual y devuelve `saludLimpia: false` | apartado 2.7 |
| 23 | `ConsultarCuantoHay` devuelve las tres cifras que la pantalla enumera | un «¿estás seguro?» sin cifras no informa |
| 24 | el `Candado` falso que no puede evaluar la política devuelve `true` | apartado 2.6: la app se abre |
| 25 | **el `grep` de la regla 7**: `./scripts/regla-7.sh` sale en verde con Ajustes dentro | C-2, y es la prueba de que los tres números no entraron |
| 26 | el alta completa de punta a punta en `XCUITest`, eligiendo «Sin sensor», sin tocar ningún permiso, y llega a las pestañas | el criterio de «hecho», comprobado como lo vive la persona |

### 8 bis. En el iPhone físico

- [ ] **El alta completa eligiendo «Sin sensor»**, sin conceder ningún permiso, y la app queda
  usable: se registra una lectura y se ve en Inicio.
- [ ] **El alta eligiendo «Con sensor» y diciendo NO** en la hoja de Salud: el alta termina, la
  app entra en modo sin sensor y el aviso de RF-10b está en Inicio.
- [ ] **Face ID real**: encender el interruptor, cerrar la app, volver. Y taparse la cara tres
  veces: tiene que ofrecer el código, no quedarse fuera.
- [ ] **Face ID con la app ya abierta**: cambiar de pestaña no vuelve a pedirlo.
- [ ] **Borrar la cuenta** con datos de verdad dentro: la app vuelve al splash y al alta, y en
  la app **Salud** ya no están las muestras de Glucy y **sí** siguen las del sensor, si hay.
- [ ] **Letra de accesibilidad más grande** en el alta y en Ajustes: nada cortado, y las dos
  tarjetas de sensor siguen siendo del mismo tamaño aunque se apilen (P-15).
- [ ] **Arranque en frío** con el perfil ya creado: el splash no se siente como una espera.

---

## 9. Cómo se sabe que el paso 9 está hecho

- Las 26 pruebas pasan, más las 208 que ya pasaban.
- La integración continua está verde **antes** de fusionar.
- `./scripts/regla-7.sh` en verde. Es lo que cierra C-2.
- `grep -c "INFOPLIST_KEY_NSFaceIDUsageDescription" Glucy.xcodeproj/project.pbxproj` → **2**.
- `grep -rniwE "ratio|sensibilidad|altura|estatura" Glucy/` no devuelve nada.
- `grep -rn "UserDefaults" Glucy/` no devuelve nada.
- `git diff --stat origin/develop -- Glucy/App/Theme/` está **vacío**.
- `grep -rn "PendienteView" Glucy/Features/` solo aparece en su propio archivo: ya no queda
  ninguna pestaña pendiente.
- En el simulador, borrando la app y volviéndola a instalar, lo primero que sale es el splash y
  después el alta, no las pestañas.

---

## 10. Lo que NO entra en el paso 9

- **La exportación del informe** (RF-16). Paso 10.
- **El repaso de accesibilidad de las diez pantallas** y los nueve estados. Paso 10, aunque
  estas tres pantallas nazcan ya con su Dynamic Type.
- **La pantalla de contexto** (F-6: ejercicio, sueño, estrés, enfermedad). No está en los diez
  pasos de la fase 1.
- **El cambio de unidad aplicado a toda la app.** En este paso la unidad **se guarda** y se usa
  en el alta y en Ajustes; recorrer las diez pantallas convirtiendo cada cifra es parte del
  repaso del paso 10, y hacerlo a medias dejaría pantallas en mg/dL y otras en mmol/L.
- **Revocar el consentimiento sin borrar los datos.** El Documento 3 dice que es revocable; con
  la app sin servidor, revocar y borrar son lo mismo, y tener dos botones que hacen lo mismo
  confunde. Cuando haya backend (fase 2) se separan.

---

## 11. Git

```bash
git switch -c feature/alta-y-ajustes origin/develop
# …trabajo…
git add -A
git commit -m "feat: alta del perfil con consentimiento expreso, ajustes y candado biométrico"
git push -u origin feature/alta-y-ajustes
gh pr create --base develop --head feature/alta-y-ajustes
```

El pull request va contra **`develop`**, no contra `main`. Y **no se fusiona con la integración
continua en rojo ni corriendo**: se espera a que el run termine y se lee su resultado, porque
«cancelado» no es verde.

---

## 11 bis. El cuerpo del pull request, ya escrito

```markdown
## Antes

La app arrancaba directo en las cuatro pestañas. No preguntaba nada: ni el tipo de diabetes,
ni los umbrales, ni la duración de acción de la insulina, así que todo el mundo usaba los
valores por omisión sin saber que existían. Pedía el permiso de HealthKit sola al arrancar,
de golpe y sin explicar para qué. La pestaña de Ajustes mostraba el estado vacío del paso 3.

Y no existía el consentimiento. La LFPDPPP exige consentimiento expreso para datos de salud,
y la app guardaba glucosa, comidas y dosis sin haberlo pedido nunca.

## Después

Al instalar, la app abre el **splash** con el eslogan, que se retira solo, y lleva al **alta
del perfil** en cinco pasos: nombre y apellidos (opcionales), tipo de usuario y año de
nacimiento, la elección de sensor, los umbrales y parámetros, y el **consentimiento expreso
con su fecha**. Mientras no se acepte, la app no entra: la puerta es el consentimiento, no
que exista un perfil a medias.

Las dos tarjetas de sensor son **del mismo tamaño**, una al lado de la otra. «Sin sensor» no
pide ningún permiso y advierte, antes de elegir, que en ese modo la app no puede anticipar
hipoglucemias. «Con sensor» explica para qué sirve el permiso **antes** de la hoja del
sistema, y si la persona dice que no, el alta termina igual en modo sin sensor: un permiso
negado no es un error.

**Ajustes** edita lo que el cálculo de verdad usa: umbrales, unidad preferida, tiempo de
absorción por omisión, tipo de insulina rápida, duración de acción y el interruptor de
registrar insulina. Dice con todas sus letras que la sincronización es solo por wifi y que
todavía no hay servidor, cuenta cuántos registros esperan en la cola, **enumera** lo que
nunca sale del teléfono, y al final, en rojo, deja borrar la cuenta.

Borrar la cuenta enumera cuántas lecturas, comidas y dosis se pierden, obliga a escribir la
palabra «borrar», y quita de Salud **lo que Glucy escribió y solo eso**: lo que escribió la
app del sensor se queda. Si Salud falla, el borrado local se hace igual y la pantalla lo dice
en lugar de fingir que terminó.

Y se puede pedir **Face ID o Touch ID** para abrir la app, apagado por omisión, con la letra
pequeña que aclara que eso no cifra nada porque el iPhone ya lo cifra.

## Cómo

Cuarta migración versionada, `EsquemaGlucyV5`, con una etapa ligera que agrega los cinco
campos que el formulario F-1 del Documento 3 pide y el perfil no tenía: el consentimiento con
su fecha, la unidad preferida, el tipo de insulina rápida, el interruptor de sincronización y
el del candado. Las etapas de la V2, la V3 y la V4 no se tocan.

El año de nacimiento se pide **solo como año** y se guarda como el 1 de enero de ese año, así
que ninguna fecha de nacimiento precisa entra a la base. Una prueba lo fija. Cambiar el campo
a un entero habría pedido la primera etapa de migración personalizada del proyecto, que es
justo donde las bases se borran, y el dato minimizado es el que no se captura.

`CompletarAlta` es la única puerta que escribe el consentimiento, y con `false` no guarda
nada. `BorrarTodo` borra los cinco repositorios y después llama al método nuevo
`eliminarTodoLoPropio`, que distingue por `HKSource.default()`. El candado es
`LocalAuthentication` detrás de un protocolo, con `deviceOwnerAuthentication` para que el
código del teléfono sirva cuando la biometría falla, y **si la política no se puede evaluar,
la app se abre**: a las tres de la mañana, con una hipoglucemia encima, una app que no abre es
peor que una app que alguien podría espiar.

## Tres contradicciones cerradas

- **C-2** — La ficha de la pantalla 9 pedía relación insulina/carbohidratos, factor de
  sensibilidad y dosis basal. **No entran.** La insulina activa no las necesita —necesita el
  tipo de insulina y la duración de acción, que sí entran—, y esas tres cifras son exactamente
  las entradas de un calculador de bolo, que es la frontera con un dispositivo médico
  regulado. Ya no depende de que alguien se acuerde: `scripts/regla-7.sh` corre en cada push y
  busca `ratio` y `sensibilidad`, así que el campo pondría la CI en rojo antes de compilar.
- **C-1** — La altura no se captura. Manda F-1, que la nombra entre lo que el formulario no
  pide a propósito.
- **C-3** — Las cuatro opciones de tipo de usuario, no tres. Y `registraInsulina` nace
  calculado del tipo: encendido en tipo 1 y tipo 2 insulinodependiente, apagado en prediabetes
  y resistencia a la insulina, editable después.

## Requisitos que cubre

- **RF-06** — el onboarding pide el permiso con su explicación y **permite saltárselo**.
- **RF-07** — la lectura de Salud se enciende y se apaga desde Ajustes, sin perder historial.
- **RF-10b** — la declaración de que sin sensor no se anticipan hipoglucemias, ahora también
  en el onboarding.
- **RF-14** — el interruptor de ocultar insulina, editable desde Ajustes.
- **Autenticación** — Face ID o Touch ID para abrir la app.
- **Normatividad** — consentimiento expreso con su fecha (LFPDPPP).
- **Privacidad del nombre** — el nombre, los apellidos y el peso enumerados como lo que nunca
  sale del teléfono.
- **Seguridad clínica** — los tres números de un calculador de dosis no existen en el código.

## Comprobado

- [x] Las 26 pruebas nuevas pasan, más las 208 anteriores
- [x] `./scripts/regla-7.sh` en verde
- [x] `INFOPLIST_KEY_NSFaceIDUsageDescription` aparece **2** veces, una por configuración
- [x] `grep -rniwE "ratio|sensibilidad|altura|estatura" Glucy/` no devuelve nada
- [x] `grep -rn "UserDefaults" Glucy/` no devuelve nada
- [x] Sin colores nuevos: el diff de `App/Theme/` está vacío
- [x] El alta se completa con «Sin sensor» sin conceder un solo permiso, en el iPhone
- [x] Diciendo NO en la hoja de Salud, el alta termina igual y entra en modo sin sensor
- [x] Face ID real: tapándose la cara tres veces ofrece el código, no deja fuera
- [x] Borrar la cuenta quita de Salud lo de Glucy y deja lo del sensor
- [x] Letra de accesibilidad más grande en el alta y en Ajustes, sin texto cortado (P-15)
```

---

## 12. El texto para pegarle a Claude Code

> Lee `CLAUDE.md` y `docs/paso-9-alta-y-ajustes.md`. Trabaja en una rama
> `feature/alta-y-ajustes` que sale de `develop`
> (`git switch -c feature/alta-y-ajustes origin/develop`); **no trabajes en `main` ni en
> `develop`**. Construye el paso completo: la migración `EsquemaGlucyV5` con los cinco campos
> nuevos del perfil, `ReglasDePerfil`, los casos de uso `CompletarAlta`, `GuardarAjustes`,
> `BorrarTodo` y `ConsultarCuantoHay`, el `eliminarTodoLoPropio` del servicio de Salud, el
> `CandadoBiometrico` detrás de su protocolo, las pantallas de splash, alta, ajustes, borrado
> y candado con sus ViewModels, la raíz de `GlucyApp` que decide entre alta y pestañas, y las
> 26 pruebas del apartado 8.
>
> **Antes de escribir código, agrega en Xcode la llave de Face ID con el PROYECTO
> seleccionado, no el target**, y comprueba que
> `grep -c "INFOPLIST_KEY_NSFaceIDUsageDescription" Glucy.xcodeproj/project.pbxproj` dice
> **2**. Si dice 1 quedó solo en una configuración, como pasó con HealthKit.
>
> **No agregues ningún campo de relación insulina/carbohidratos, factor de sensibilidad ni
> dosis basal**, ni editable ni de solo consulta ni «para que la persona lo tenga apuntado».
> Son las tres entradas de un calculador de bolo y es la frontera con un dispositivo médico
> regulado; `scripts/regla-7.sh` corre en cada push y pondría la CI en rojo. Tampoco ninguna
> función que devuelva unidades de insulina, ni ninguna frase que diga cuánto aplicarse. Y
> **no captures la altura**. El apartado 6 tiene la lista completa de lo que no entra y es
> parte del trabajo, no una advertencia.
>
> **La puerta de la app es el consentimiento, no que exista un perfil.** La raíz decide con
> `consentimientoTsUtc != nil`. `CompletarAlta` con `aceptaConsentimiento: false` no guarda
> nada y devuelve rechazo: no puede existir un perfil sin consentimiento.
>
> **El alta se tiene que poder terminar eligiendo «Sin sensor» y sin conceder un solo
> permiso**, y también diciendo NO en la hoja de Salud. Un permiso negado no es un error y no
> lleva a ninguna pantalla de error: lleva al modo sin sensor, que es un modo completo. Las
> dos tarjetas van **del mismo tamaño**, y la de «Sin sensor» advierte antes de elegir.
>
> **El año de nacimiento se pide solo como año** y se guarda como el 1 de enero de ese año:
> ninguna fecha de nacimiento precisa entra a la base. **No escribas una etapa de migración
> personalizada** para cambiar el tipo del campo; la etapa ligera de la V5 solo agrega los
> cinco campos nuevos y las etapas de la V2, V3 y V4 no se tocan. Una migración de más borra la
> base al arrancar.
>
> **El candado nunca deja a nadie fuera**: `deviceOwnerAuthentication` para que el código del
> teléfono sirva cuando la biometría falla, apagado por omisión, y si la política no se puede
> evaluar **la app se abre**. Es lo contrario de una app de banco y es a propósito.
>
> El borrado enumera las cifras de verdad, obliga a escribir «borrar», y quita de Salud **solo
> lo que Glucy escribió**, distinguido por `HKSource.default()`. Si Salud falla, el borrado
> local se hace igual y la pantalla lo dice.
>
> **No toques `Theme.swift`**: el azul del splash es `azulPrimario` con la letra en
> `textoSobreColor`. `superficie` solo va en `.background`. Y **nada en `UserDefaults`**.
>
> Los textos del apartado 7 van tal cual, no se parafrasean: son los que marcan la frontera
> clínica y los que enumeran la privacidad.
>
> Corre las pruebas y dime cuántas pasaron. Corre también `./scripts/regla-7.sh` y los siete
> `grep` del apartado 9, y confirma qué devolvieron. Después sube la rama y **abre el pull
> request contra `develop`** con el cuerpo del apartado 11 bis
> (`gh pr create --base develop --head feature/alta-y-ajustes`); no basta con subir la rama,
> porque sin pull request la integración continua no corre. **Espera a que el run termine y
> dime su resultado antes de que yo lo fusione**: «cancelado» no es verde. No lo fusiones tú.
