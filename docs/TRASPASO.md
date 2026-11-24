# Traspaso: cómo seguir con glucy-ios sin el contexto de quien lo escribió

Este documento es para quien llegue al proyecto sin haber estado en él, sea una persona u otro
asistente de programación. Junto con `CLAUDE.md` debería bastar para continuar. Hay uno igual
en `glucy-backend` y otro en `glucy-ml-`, cada uno con lo de su repositorio.

Escrito el 20 de noviembre de 2026. Si lees esto mucho después, compara contra el historial de
`develop` antes de dar algo por cierto.

## 1. Antes de tocar nada

- **El trabajo vive en `develop`, no en `main`.** `main` se quedó en la versión 0.1.0 (fin de
  la fase 1) y nunca se le volvió a fusionar `develop`. Clona y cambia de rama:
  `git checkout develop`.
- **No hay etiquetas ni releases.** Las que tocan son `v0.1.0` en `735c508`, `v0.2.0` en
  `b0378ce` y `v0.3.0` en `bd499bf`. El cuerpo de la primera está en `docs/release-v0.1.0.md`.
- **`main` no está protegida**, aunque `CLAUDE.md` diga que sí. Es un pendiente (issue abierto).
- La carpeta `glucy-base` que cita `CLAUDE.md` está en los archivos privados del proyecto, no
  en GitHub. No hace falta: las constantes, las ocho reglas y la arquitectura están en
  `CLAUDE.md`, y los números clínicos se cotejan contra
  `glucy-backend/referencia/reglas_clinicas.py`.

## 2. Compilar sin Mac

**Swift solo compila en macOS con Xcode.** Si trabajas en Linux o en un asistente en la nube:

- La **integración continua del PR es el compilador** (`.github/workflows/ci.yml`, runner
  `macos-latest`, unos nueve minutos). Sube en rama, abre el PR contra `develop` y lee el
  resultado.
- Cuando falla, la bitácora resumida no trae archivo ni línea. Pide la bitácora completa del
  trabajo y busca `\.swift:[0-9]+:[0-9]+: error:`.
- Lo que sí se corre en Linux: `./scripts/regla-7.sh` (comprueba que ningún texto sugiera una
  dosis) y búsquedas de texto.
- Mientras no haya Mac, copia la forma de un tipo que ya compila (ver la sección 6).

## 3. Dónde está cada cosa

| Qué | Dónde |
| --- | --- |
| Reglas que no se negocian, arquitectura, constantes, casos P-xx | `CLAUDE.md` |
| Cómo se construyó cada paso, con sus trampas | `docs/paso-1-*.md` a `docs/paso-11-*.md`, en orden |
| Predicción con Core ML y explicación del servidor | `docs/paso-11-prediccion-con-core-ml.md`, `docs/fase3-prediccion-en-la-app.md` |
| Pruebas que solo valen en el iPhone físico | `docs/paso-10-pruebas-en-el-iphone.md`, `scripts/pruebas-en-el-iphone.sh` |
| Conectar el iPhone a un servidor en la red local | `docs/servidor-en-la-red-local.md` |
| Entrar en modo sensor sin sensor comercial | `docs/sensor-de-prueba-en-healthkit.md` |
| Piloto de usabilidad (fase 7) | `docs/fase7-piloto-de-usabilidad.md` |
| Paleta y modo oscuro, con contrastes medidos | `docs/modo-oscuro.md` |
| Modelos Core ML dentro de la app | `Glucy/Resources/Modelos/GlucyM1.mlmodel`, `GlucyM2.mlmodel` |
| En qué iPhone corre y cómo instalarla en el de otra persona (TestFlight, Ad Hoc) | `docs/instalar-en-cualquier-iphone.md` |

## 4. Estado al 20 de noviembre de 2026

- Fases 1 y 3 completas en la app: captura por tres vías, comidas por código de barras,
  insulina, historial, indicadores, sincronización por lotes, predicción con Core ML en el
  teléfono, pantalla de factores y frase del servidor, aviso de baja prevista con la app
  cerrada, interruptor del asistente.
- 396 pruebas en 59 suites; corren en el simulador dentro de la integración continua.
- **Los modelos que trae la app son `v0.3.0-ohiot1dm`**, los mismos que carga el servidor
  (actualizado el 24 de noviembre de 2026; antes eran `v0.2.0-simulador`).
- Solo iPhone (`TARGETED_DEVICE_FAMILY = 1`), iOS 17 o posterior, con icono y la declaración
  de cifrado exento que pide TestFlight.

## 5. Lo que falta

Cada punto tiene su issue en este repositorio.

1. **Cuando glucy-ml entrene otra versión**, se copian los `.mlmodel` y se actualizan en
   `GlucyTests/ModeloCoreMLTests.swift` la versión esperada y los cuatro valores de referencia
   contra XGBoost (hoy 175.276 54, 178.710 13, 173.567 09 y 175.855 19), que se sacan corriendo
   el `.ubj` con la misma fila en `float32`. Que la prueba falle al cambiar el modelo es a
   propósito.
2. **Avisos con prioridad de tiempo.** La cuenta de desarrollador del proyecto es personal y
   **no soporta la capacidad Time Sensitive Notifications**: si se declara, Xcode no puede
   firmar y la app no se instala. El aviso sale con prioridad normal y un Modo de
   Concentración (por ejemplo «Sueño») lo puede callar. Se arregla con la membresía de pago
   de Apple: basta agregar la capacidad, el código ya pide `.timeSensitive`. Detalle en
   `docs/limitacion-del-aviso-con-prioridad-de-tiempo.md`. **No agregues la clave a mano** con
   la cuenta actual.
3. **Pruebas que solo se pueden hacer en el iPhone físico**: P-14 (no reescribir en Salud lo
   del sensor), que iOS despierte la app en segundo plano con HealthKit, notificaciones,
   cámara y Vision. Lista en `docs/paso-10-pruebas-en-el-iphone.md`.
4. **Etiquetas, fusión de `develop` a `main` y protección de `main`.** Las etiquetas y los
   releases los tiene que crear el dueño (desde la nube GitHub contesta 403). La fusión a
   `main` se probó y es limpia.
5. Llenar `docs/architecture.md`, `docs/ai.md`, `docs/database.md`, `docs/privacy.md` y
   `docs/testing.md`, que siguen diciendo «Pendiente de llenar».

## 6. Trampas que ya costaron horas

Swift 6 con concurrencia estricta, y el target de la app con
`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`: **todo lo que no diga `nonisolated` vive en el
actor principal**.

- **`MLModel.prediction(from:)` tiene versión síncrona y asíncrona.** En contexto asíncrono el
  compilador elige la asíncrona y el `MLModel` (no `Sendable`) cruza de actor. El trabajo va
  en un método **no asíncrono** del actor.
- **No llames al `init` de un actor dentro de un `@autoclosure`** (el lado derecho de `??`) ni
  como valor por omisión de un parámetro. Construye el doble en un `let` aparte. El error
  señala el archivo del `init`, no el de la llamada.
- **Un `init` de actor con argumentos por omisión, llamado sin argumentos desde otro archivo
  del mismo lote**, da el mismo error. Pasa el doble por parámetro.
- **Dentro de `#expect` no pongas aritmética de literales**: o el comprobador de tipos se
  rinde, o los literales se vuelven enteros y la división da 0. Saca el cálculo a un `let`
  con el tipo escrito.
- **A Core ML se le manda `Float` de 32 bits**, no `Double`, y lo que falta va como `NaN`.
- **La fila se arma en el instante de la última lectura**, no con el reloj, y la pantalla
  enseña la **hora** de la estimación, nunca «dentro de media hora».
- `ISO8601DateFormatter` devuelve `nil` con los seis decimales de segundo que manda FastAPI;
  el cliente los recorta a tres.
- Cada versión del esquema de SwiftData necesita su propia clase congelada en
  `EsquemasAnteriores.swift`. Si dos versiones apuntan a la misma, la app se cae al abrir una
  base vieja («Duplicate version checksums detected»). Un campo nuevo que nazca en `false`
  puede apagarle algo a quien actualiza sin que lo note.
- En Xcode, un ajuste cambiado con un target seleccionado vale solo para ese target. Lo que
  debe valer para todo se cambia en el renglón PROJECT.
- El Xcode del dueño escribe `objectVersion = 110`, más nuevo que el del runner; la
  integración continua lo baja a 77 en su copia. No lo bajes en el repositorio.
- El proyecto usa carpetas sincronizadas: lo que aparezca en `Glucy/` entra solo, sin
  registrarlo en el `.pbxproj`.
- Precedentes que compilan y conviene copiar: `HealthKitReal` (clase `@unchecked Sendable`),
  `OpenFoodFactsHTTP` (`struct` con `URLSession`), `HealthKitFalso` (actor de prueba).

## 7. Cómo se trabaja

- Todo en español, incluidos los nombres de tipos y propiedades del dominio y los textos de la
  interfaz (español de México).
- Un PR por cosa, **siempre contra `develop`, nunca apilado sobre otro PR**.
- Antes de fusionar, la integración continua tiene que terminar en verde. «Cancelado» y
  «saltado» no son verde.
- Las ocho reglas de `CLAUDE.md` mandan sobre cualquier otra cosa, en especial la 7: la app
  nunca calcula ni sugiere una dosis.

## 8. Aviso

Glucy no es un dispositivo médico certificado y no debe usarse como única fuente para una
decisión terapéutica. Informa; no prescribe ni administra.
