# Paso 11 — la predicción con Core ML en el teléfono

Lo que hace este paso es lo que el proyecto promete en su eslogan: Inicio enseña la glucosa de
media hora adelante. Resuelve la mitad de C-16 que le toca a la app, la del **número**, y deja
para el siguiente paso los factores y la explicación, que vienen del servidor.

El plan es `docs/fase3-prediccion-en-la-app.md`; esto es el acta de lo que quedó hecho, lo que
se encontró por el camino y lo que falta.

---

## 1. Qué cambia para quien usa la app

**Antes:** Inicio enseñaba la glucosa de ahora, su antigüedad y las últimas tres horas medidas.
El pie de la gráfica decía «Aún no puedo proyectar: eso llega cuando el modelo esté entrenado».

**Después:** debajo del valor de ahora sale una segunda cifra, «Estimado: 142 mg/dL a las
2:35 p.m.», con una flecha; la gráfica dibuja la línea punteada que ya sabía dibujar, saliendo
del punto medido con el que se predijo; y si la estimación cruza el umbral del perfil aparece
una franja que dice «Baja prevista a las 2:35 p.m.: alrededor de 64 mg/dL. Mídete para
confirmarlo.»

En **modo sin sensor no sale nada de esto** y el aviso de RF-10b sigue arriba, fijo y sin poder
descartarse. No es un caso degradado: es la regla 8.

## 2. La hora, y por qué no dice «dentro de media hora»

Esta es la decisión que más se nota en la pantalla y la que menos se nota en el código.

El horizonte se cuenta **desde la lectura con la que se predijo**, no desde el reloj. La regla
de frescura admite una lectura de hasta quince minutos, así que una predicción «a 30 minutos»
alcanza entre quince y treinta minutos hacia adelante. Decir «dentro de media hora» movería la
cifra hasta quince minutos sin avisar, y la pantalla la enseña con su hora por eso.

### Por qué la fila se arma en la lectura y no en el reloj

Lo que motivó todo lo demás. `caracteristicas_densas` de glucy-ml arma cada fila sobre
`historia[-1]` —el instante de una lectura— y toma `mg_dl` de ahí directo: **nunca falta**. Si
la fila se arma con el reloj de pared, en cuanto pasan 2.5 minutos —media muestra— desde la
última lectura, `mg_dl` queda en `NaN` y los rezagos resuelven a la lectura de cinco minutos
después de la que les toca.

Medido con `m1-v0.2.0-simulador` sobre 1 200 filas de dos sujetos del simulador:

| | fila en la lectura | fila con el reloj |
| --- | --- | --- |
| RMSE, todas las filas | 11.97 mg/dL | 86.57 mg/dL |
| RMSE cuando el reloj va a más de 2.5 min | 11.85 mg/dL | **125.19 mg/dL** |
| predicción en esas filas | 116 ±21 | **237 ±17** |

El reloj cae a más de 2.5 minutos de la última lectura el **47 % de las veces**: con una serie
cada cinco minutos, la distancia a la última lectura es uniforme entre 0 y 5. En esas filas el
modelo contesta su propia media con una dispersión de 17 mg/dL. **No falla nada: sale un número
plausible y equivocado.**

`GET /predict` del backend tenía ese error, y se arregló en el pull request #18 de
glucy-backend, con tres pruebas. La respuesta lleva ahora `ts_base`, `valor_base` y un
`ts_objetivo` por horizonte, que es lo que la app necesitará en el paso siguiente para
comprobar que los dos caminos dan el mismo número.

## 3. Lo que se construyó

```
Glucy/Domain/Rules/VectorDeCaracteristicas.swift   las quince columnas, copiadas del contrato
Glucy/Data/Repositories/RepositorioModelo.swift    el protocolo y lo que el artefacto declara
Glucy/Data/CoreML/ModeloCoreML.swift               Core ML detrás de ese protocolo
Glucy/Domain/UseCases/CalcularPrediccion.swift     modo, frescura, la base y el aviso
Glucy/Resources/Modelos/GlucyM1.mlmodel            30 minutos, v0.2.0-simulador
Glucy/Resources/Modelos/GlucyM2.mlmodel            60 minutos, v0.2.0-simulador
```

Dos cosas se apartaron del plan, y conviene que esté dicho:

- **El vector vive en `Domain/Rules/`, no en `Data/CoreML/`.** No tiene nada específico de
  ninguna fuente: es la regla del contrato, y las reglas van en el dominio. Que esté ahí es
  también lo que permite que `GlucyTests` lo pruebe sin Core ML.
- El archivo se llama `ModeloCoreML.swift` y no `ModeloGlucosa.swift`, para seguir la
  convención del resto: el protocolo describe lo que hace (`RepositorioModelo`) y la
  implementación, con qué (`HealthKitReal`, `VisionOCR`, `OpenFoodFactsHTTP`).

### El nombre del archivo del modelo no lleva la versión

`GlucyM1.mlmodel`, no `m1-v0.2.0-simulador.mlmodel`. La versión, el horizonte, la lista de
características y si sus métricas se pueden reportar vienen en los **metadatos del propio
artefacto**, y de ahí los lee `ModeloCoreML`. Así, adoptar un modelo reentrenado es copiar el
archivo encima y nada más (RF-29), sin tocar Swift y sin que la app reporte una versión que no
es la que calculó el número (RF-25).

### Lo que se comprueba al cargar, que es la razón de que la clase exista

Predecir son tres líneas. `ModeloCoreML.init` existe para lo otro:

1. Que las entradas del artefacto se llamen **exactamente** como las de
   `VectorDeCaracteristicas.densas`. Si `mg_dl` se llamara `glucosa`, Core ML no se queja:
   recibe una llave que no conoce, usa el valor faltante para la que sí espera, y devuelve un
   número.
2. Que cada entrada sea un número de doble precisión.
3. Que la salida se llame `target`.
4. Que los metadatos traigan versión y horizonte. Sin horizonte, el modelo de 60 minutos puede
   cargarse donde va el de 30: predice bien y contesta otra pregunta.

Un artefacto que no cumpla **no llega a la pantalla**, y el motivo queda en
`ContenedorDependencias.modelosQueFallaron` en lugar de perderse.

### Las tres cosas del vector que se copian y no se derivan

Todo sale de `app/services/pipeline/caracteristicas.py` del backend, que se declara autoridad,
y su COB y su IOB de `referencia/reglas_clinicas.py`:

- los rezagos se buscan **por tiempo**, a media muestra de tolerancia, y un empate se queda con
  la lectura más antigua;
- los promedios móviles van sobre **`(desde, ahora]`**, abierto por abajo;
- la hora del día cuenta **los segundos**, en la zona del dato, y `dia_semana` va con **lunes =
  0** porque así lo numera Python, mientras `Calendar` de Foundation numera domingo = 1.

Lo que falta llega como `NaN`, **nunca como cero**: un rezago de 60 minutos que no existe porque
la serie empieza ahí no es una glucosa de cero.

## 4. Las dos cosas que el teléfono tiene que respetar, medidas

Las dos salieron de comprobar la conversión contra XGBoost, y las dos producen un número
equivocado sin que nada falle:

1. **Cuantizar a 32 bits.** Los umbrales de los árboles son `float32` y XGBoost compara contra
   ellos con esa precisión, mientras la interfaz de Core ML pide `double`. `paraCoreML` hace
   `Double(Float(v))`. Mandar la doble precisión sin redondear desvía la predicción hasta
   **1.57 mg/dL en 450 de 2 000 filas** en M-1, y hasta 2.78 en 621 en M-2.
2. **Mandar el `NaN` tal cual.** El artefacto trae 498 nodos con `missingValueTracksTrueChild`:
   Core ML sabe para qué lado mandar una fila con un hueco. Rellenarlo desvía hasta
   **19.8 mg/dL** en M-1 y 35.9 en M-2.

`ModeloCoreMLTests` fija las dos contra el XGBoost original: la misma fila da **160.78 mg/dL**
en M-1 y **139.96** en M-2, y con los huecos de una serie de dos lecturas, 158.90 y 154.95. Si
alguien reemplaza los artefactos, estas cifras cambian y la prueba falla; **es lo que se
quiere**, porque adoptar un modelo nuevo tiene que ser una decisión visible.

## 5. Lo que no hace, y por qué

- **Sin artefacto cargado no hay número de respaldo.** Una línea base de persistencia —«dentro
  de 30 minutos será igual que ahora»— es una herramienta de evaluación; enseñarla como
  predicción sería una cifra que nadie validó, en el sitio donde la gente la leería como una
  predicción.
- **Un número imposible no se recorta al límite del rango**, se dice que no hay predicción y se
  dice el valor: recortarlo a 600 lo haría pasar por una predicción, y es un síntoma que quien
  lo vea en una prueba de campo tiene que poder reportar.
- **Ninguna dosis ni gramos, ni calculados ni sugeridos** (regla 7). El aviso dice qué va a
  pasar; lo único que pide es medirse, que es una medición y no un tratamiento.
- **En modo sin sensor no se oculta el número: se declara que no se puede anticipar** (RF-10b).
- **No se tocó ningún `@Model` ni ninguna etapa de migración.** `PrediccionCache` sigue como
  estaba, y todavía no se escribe nada en ella: con Core ML corriendo en milisegundos, una caché
  no ahorra nada hasta que haya explicación que guardar. Ahí entra en el paso siguiente.

## 6. Lo que falta, que es el resto del plan

1. `GET /predict` y `POST /explain` desde la app, en segundo plano y sin bloquear la pantalla.
2. La comparación de los dos caminos: la app manda el **mismo instante** que usó —ahora
   `ts_base`— y si los números difieren en más de 1 mg/dL se queda con el suyo y **deja el
   desacuerdo registrado**.
3. La pantalla de factores con las cinco contribuciones, con el nombre en palabras que el
   servidor ya devuelve. La app no traduce nombres de características.
4. La frase de la explicación debajo de la cifra, y `PrediccionCache` guardando lo que llegó.
5. Las alertas de verdad (RF-10): notificación, vibración, y el aviso no descartable. Lo de
   ahora es la franja en pantalla, que se deriva del número y nada más.

## 7. Lo que sigue sin poder comprobarse aquí

El `.mlmodel` se compila y se ejecuta en el simulador, así que la fidelidad contra XGBoost
—incluido el trato del valor faltante— **sí queda comprobada en la integración continua**. Lo
que sigue pendiente del iPhone físico es lo de siempre: HealthKit en segundo plano, las
notificaciones, la cámara y Vision.
