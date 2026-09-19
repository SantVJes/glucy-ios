# CLAUDE.md — glucy-ios

Este archivo va en la raíz del repositorio `glucy-ios`. Claude Code lo lee solo al abrir el
proyecto, así que todo lo que esté aquí se aplica sin que nadie tenga que repetirlo.

---

## Qué es este repositorio

App iOS nativa de **Glucy**, un sistema que registra glucosa por tres vías, la predice a 30 y
60 minutos y explica la predicción en español llano. Eslogan: «Tu glucosa, media hora antes».
Usuario principal: personas con diabetes tipo 1 y tipo 2 insulinodependiente.

Es un proyecto académico (Universidad Tecmilenio, 8.º semestre) que desarrolla **una sola
persona**, Jesús Santiago Velasco. Entrega final: **finales de noviembre de 2026**.

Este repositorio es **uno de tres**:

| Repositorio | Qué contiene | Cómo se conecta con este |
| --- | --- | --- |
| **glucy-ios** (este) | app SwiftUI, SwiftData, HealthKit, Vision, Core ML | — |
| glucy-backend | API FastAPI, pipeline de datos, PostgreSQL/TimescaleDB, servicio de explicación | la app le sube lotes y le pide predicción y explicación por HTTP |
| glucy-ml | entrenamiento, validación, artefactos del modelo | produce el `.mlmodel` que esta app ejecuta con Core ML |

**La app no depende del backend para nada crítico.** Registrar una lectura, una comida y una
dosis, ver las gráficas y los indicadores funciona sin internet, sin servidor y sin sensor.

## Idioma y comentarios (regla del proyecto)

- **Todo se escribe en español**: comentarios, mensajes de commit, nombres de ramas,
  descripciones de pull request, títulos de issues y los textos de la interfaz (español de
  México).
- **Los nombres de los tipos, propiedades y funciones también van en español** cuando
  corresponden al dominio: `LecturaGlucosa`, `mgDl`, `tiempoAbsorcionMin`,
  `calcularInsulinaActiva()`. Los nombres de los frameworks de Apple se quedan como son
  (`HKQuantityType`, `NavigationStack`).
- **Se documenta el por qué, no el qué.** Que el umbral de frescura sea de quince minutos se
  explica; que una función sume dos números, no.
  ```swift
  // Pasados 15 minutos la lectura del sensor ya no sirve para predecir: se degrada
  // a modo sin sensor en lugar de proyectar con datos viejos (RF-06c, D-13).
  static let frescuraSensorMin = 15
  ```
- **Comentarios de documentación (`///`) en los protocolos de repositorio y en los casos de
  uso.** En las vistas no: ahí el código se explica solo.
- Cuando una regla viene de un requisito o de una decisión, **se cita su identificador**
  (`RF-06c`, `D-13`, `P-11`). Así se puede rastrear hasta el reporte.
- Nada de comentarios que narran el cambio («ahora también valida…»). Eso va en el commit.

## Las ocho reglas que no se negocian

Cualquier código que rompa una de estas está mal, aunque compile y se vea bien.

1. **El teléfono es el dueño del dato.** Todo se guarda primero en el dispositivo; el backend
   es una copia para analítica y modelo, nunca la fuente.
2. **Nada entra sin que el usuario lo confirme.** Todo valor leído por OCR se muestra y se
   confirma antes de guardarse, **sin umbral de confianza** (D-11).
3. **Lo que identifica a la persona no sube.** Nombre, apellidos, peso, notas y fotografías
   nunca salen del teléfono.
4. **Todo dato guarda su origen**: `sensor`, `manual`, `fotoGlucometro`, `barcode`,
   `ocrEtiqueta`, `healthkit`.
5. **Tiempo en UTC más la zona horaria del dispositivo.** Siempre las dos cosas.
6. **Las imágenes no se guardan ni se suben.** Se procesan con Vision y se descartan.
7. **Nunca se calcula ni se sugiere una dosis de insulina** ni gramos a tomar. La app registra
   lo que la persona dice haberse aplicado. Es la frontera con un dispositivo médico regulado.
8. **En modo sin sensor la app declara que no puede anticipar hipoglucemias** (RF-10b), con un
   aviso fijo y no descartable arriba de la pantalla de inicio.

Dos más, derivadas: **no se infieren comidas** (si no hay registro, no hay dato, D-9/RF-37) y
**la app escribe en HealthKit solo lo que ella capturó** (lo del sensor no se reescribe, o la
serie se duplica al siguiente arranque, RF-15b).

## Arquitectura

MVVM con capa de casos de uso y repositorios. La dependencia va **en un solo sentido**:

```
View SwiftUI  →  ViewModel @Observable  →  Use Case  →  Repository  →  SwiftData / HealthKit /
                                                                       Open Food Facts / API
```

- **View**: dibuja y recoge gestos. No calcula, no llama a la red, no toca HealthKit ni
  SwiftData.
- **ViewModel**: estado de una pantalla, formateo y traducción de un gesto en una llamada a un
  caso de uso. **Sin reglas clínicas.**
- **Use Case**: las reglas del producto. Validar 20–600 mg/dL, calcular insulina activa y
  carbohidratos activos, decidir si el modo sensor sigue siendo válido, decidir si se
  sincroniza. **Aquí viven las reglas que pueden lastimar a alguien, y por eso aquí se
  concentran las pruebas unitarias.**
- **Repository**: un protocolo por tipo de dato con una implementación por origen. Todo lo
  específico de cada fuente vive aquí y nada más que aquí.

```
GlucyApp/
  App/          GlucyApp.swift, contenedor de dependencias, Theme/
  Domain/       Models/ (los @Model) · Enums/ · UseCases/ · Rules/ (validación, COB, IOB, indicadores)
  Data/         Repositories/ · SwiftData/ · HealthKit/ · OCR/ · Network/ · Sync/
  Features/     una carpeta por pantalla, con su View y su ViewModel
  Resources/    Assets, Localizable (es-MX), modelo Core ML
GlucyAppTests/      pruebas de Domain — las que importan
GlucyAppUITests/    XCUITest de los recorridos
```

## Configuración del proyecto

- **Swift 6 con concurrencia estricta** (`SWIFT_STRICT_CONCURRENCY = complete`). Es lo que
  detecta en compilación las carreras entre HealthKit, la cámara y la base local.
- **Deployment target iOS 17.0.** No bajarlo: SwiftData empieza ahí.
- SwiftUI en toda la interfaz; UIKit solo envuelto en `UIViewRepresentable` si una pantalla lo
  exige.
- Estado: `@Observable` en los ViewModels, `@State` para lo local de una vista,
  `@Environment` para las dependencias compartidas.
- Navegación: `NavigationStack` con rutas tipadas y `TabView` de cuatro pestañas —
  **Inicio · Registrar · Historial · Ajustes**. Profundidad máxima dos niveles.
- **Ninguna llave, token ni cadena de conexión en el código.** Lo que haya va al **Keychain**,
  nunca a `UserDefaults`.

## Órdenes de uso diario

```bash
# Compilar y correr las pruebas unitarias (ajustar el destino al simulador instalado)
xcodebuild -scheme Glucy -destination 'platform=iOS Simulator,name=iPhone 17' test

# Solo las pruebas de dominio, que son las rápidas
xcodebuild -scheme Glucy -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:GlucyAppTests test

# HealthKit en segundo plano, notificaciones, cámara y Vision: SOLO en el iPhone físico.
# El simulador no los reproduce bien.
```

## Integraciones, y cómo falla cada una

Cada integración tiene plan B, y ninguna función crítica depende de algo externo.

| Integración | Qué da | Si falla |
| --- | --- | --- |
| **HealthKit** | glucosa del sensor comercial (lectura), y escritura de glucosa, carbohidratos e insulina | modo sin sensor, declarado en pantalla |
| **Vision** (en el dispositivo) | número de la pantalla del glucómetro y texto de la etiqueta nutrimental | se avisa y se ofrece captura manual |
| **Open Food Facts** | carbohidratos por código de barras | foto de la etiqueta y, si eso falla, captura manual |
| **API de Glucy** (fase 2) | subida de lotes, predicción, explicación | la app sigue completa en local; los registros esperan en la cola |
| **Learning Record Store** (fase 6) | sentencias xAPI de autocuidado | cola local y reenvío diferido |

**HealthKit, las tres trampas que ya están documentadas:**
1. No reescribir lo que se leyó del sensor (`HKSource` distingue lo propio de lo del
   fabricante) — RF-15b, caso P-14.
2. No suponer una serie regular de cinco minutos ni rellenar lo que no llegó: HealthKit
   entrega lo que la app del fabricante escribió, cuando lo escribió, y puede llegar en
   bloques y con retraso — RF-06b.
3. No caerse cuando la persona revoca el permiso desde Salud: se vuelve a modo sin sensor y se
   dice en pantalla — RF-07, caso P-09.

Lectura continua: `HKObserverQuery` + `enableBackgroundDelivery`. Unidades: consultar
`preferredUnits(for:)`; internamente **todo en mg/dL**. Metadatos:
`HKMetadataKeyBloodGlucoseMealTime` para el contexto, `HKMetadataKeyInsulinDeliveryReason`
para bolo o basal.

**Open Food Facts:** consulta **desde el teléfono**, nunca desde el servidor en nombre de
todos, porque el límite es de 15 consultas por minuto por IP. Exige `User-Agent` propio
(`Glucy/1.0 (correo de contacto)`) o puede bloquear. Caché en `ProductoCache`. Hay que
atribuir la fuente en la app (ODbL).

## Constantes, en un solo archivo

Glucosa válida **20–600 mg/dL** · umbral hipo **70** (50–90) · umbral hiper **180** (140–300) ·
rango objetivo del TIR **70–180** · absorción de carbohidratos **180 min** (presets 30 y 300,
rango 30–300) · duración de acción de la insulina **5 h** (2–8), pico ~75 min · **frescura del
sensor 15 min** · interpolación máxima de huecos 15 min · tasa de cambio imposible
> 4 mg/dL/min (solo serie continua) · carbohidratos 0–300 g · insulina 0–50 UI (resolución
0.5) · peso 25–300 kg · edad mínima 15 años.

Estos números **no se escriben sueltos dentro de una vista ni de un caso de uso**: viven en un
solo archivo de configuración del dominio.

## Reglas clínicas: hay una referencia ejecutable

`referencia/reglas_clinicas.py` del repositorio **glucy-backend** implementa en Python
validación, COB, IOB, TIR/TBR/TAR, GMI, decisión de modo y decisión de sincronizar, con **30
pruebas pasando**. **Los mismos números tienen que dar en Swift.** Si el Swift y esa referencia
no coinciden, uno de los dos está mal.

El caso que más se cita: COB de 60 g con absorción de 180 min, a los 90 minutos, son **30 g**
(absorción lineal, caso P-11).

## Pruebas

- **Unitarias (Swift Testing / XCTest) sobre `Domain`.** Es la capa donde un error tiene
  consecuencia clínica, y se prueba sin interfaz, sin cámara y sin dispositivo.
- **XCUITest** para los recorridos: alta del perfil, las tres vías de captura, comida por
  código de barras y navegación entre pestañas.
- **XCTest en el iPhone físico** para HealthKit en segundo plano, notificaciones, cámara y
  Vision.

Casos que no pueden faltar, cada uno apuntando a su requisito: **P-01** OCR sin confirmar no
guarda nada · **P-02** 900 mg/dL no se guarda · **P-03** lectura vieja degrada y lo dice ·
**P-04** sin sensor no hay alerta y el aviso sigue visible · **P-07** modo avión: todo
funciona y queda en la cola · **P-08** con datos móviles no sincroniza salvo botón manual ·
**P-09** revocar HealthKit no tumba la app · **P-10** Open Food Facts caído → foto → manual ·
**P-11** COB 60 g/180 min a los 90 min = 30 g · **P-12** glucosa sube sin comida registrada y
no se infiere nada · **P-14** no se reescribe en HealthKit lo del sensor · **P-15** letra de
accesibilidad más grande sin cortar texto.

## Interfaz: lo que no se puede perder

- **Lo medido y lo predicho nunca se parecen**: línea continua contra línea punteada. Una
  persona medio dormida tiene que distinguirlos sin leer la leyenda.
- **El color nunca es el único portador de información**: cada estado lleva además icono,
  palabra o forma. La app se revisa en escala de grises.
- **Un dato y una acción por pantalla.** Una cifra protagonista y un botón principal.
- **Se diseña para el peor momento**, una hipoglucemia de madrugada: letra grande, contraste
  alto, botones grandes, ninguna decisión complicada.
- Accesibilidad: Dynamic Type en todo, VoiceOver leyendo cada cifra con su unidad y su
  antigüedad, gráficas con descripción y Audio Graphs, contraste mínimo 4.5:1 en texto y 3:1
  en bordes, respetar «reducir movimiento», vibración en la alerta.
- Tokens de color y tipografía: están en `Theme.swift`, copiados de `01-glucy-ios.md`. **Nunca
  un hex suelto en una vista.**

Textos: de tú y en presente («vas a bajar en la próxima hora»), sin tecnicismos en la
superficie («carbohidratos que siguen activos», no «COB»), **ninguna frase que dé una
instrucción de tratamiento**, y todo número con su unidad y su hora.

## Git

- Ramas: `main` (siempre compila y siempre pasa las pruebas, protegida), `develop`,
  `feature/lo-que-hace`, `fix/lo-que-arregla`.
- Commits con **Conventional Commits en español**: `feat: captura de glucosa por foto con
  confirmación del valor`, `fix: la cola no reintentaba tras un 401`, `test: casos de
  carbohidratos activos con absorción de 180 minutos`.
- Un pull request por funcionalidad, **con una descripción de qué se veía antes y qué se ve
  después**. No se fusiona con la integración continua en rojo.
- Un issue por requisito funcional, etiquetado con su fase. El tablero del repositorio es el
  plan: no se mantienen dos listas.
- Releases con versionado semántico: `v0.1.0` al terminar la fase 1 (app autónoma), `v0.2.0`
  con backend, `v0.3.0` con predicción en vivo.

## Dónde está el resto de la documentación

En los archivos del proyecto de Claude, carpeta `glucy-base`: `00-CONTEXTO-GLUCY.md` (el panorama),
`01-glucy-ios.md` (las diez tablas campo por campo, las diez pantallas, los tokens, los nueve
estados), `04-PLAN-FASE-1.md` (el orden de construcción) y
`05-PENDIENTES-Y-CONTRADICCIONES.md` (lo que está sin cerrar).

Reporte del Avance 1, que es la fuente: `Glucy - Reporte del Avance 1.pdf`.
Mockups: https://www.figma.com/design/TFOHJ9wm2lhsiEk1e3595A

## Aviso que va en el README y en la app

Glucy **no es un dispositivo médico certificado** y no debe usarse como única fuente para una
decisión terapéutica. Informa; no prescribe ni administra.
