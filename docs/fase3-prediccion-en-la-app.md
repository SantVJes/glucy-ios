# Fase 3 en el teléfono — la predicción en la app

Documento de trabajo para Claude Code. Es el paso de `glucy-ios` de la fase 3: la app enseña
por fin lo que el proyecto promete en su eslogan, «tu glucosa, media hora antes».

Depende de que exista un modelo entrenado, y eso depende de OhioT1DM. **Lo que no depende de
nada es la decisión de dónde corre la predicción**, y esa es la mitad de este documento.

---

## 1. Qué cambia para quien usa la app

**Antes:** Inicio enseña la glucosa de ahora, su antigüedad y las últimas horas medidas. Nada
mira hacia adelante.

**Después:** debajo de la cifra de ahora, **a 30 minutos**, con la línea punteada que la gráfica
ya sabe dibujar y una frase en español llano debajo: «Vas a bajar. Lo que más pesa en la
estimación: tu glucosa de ahora (−25 mg/dL) y la insulina que sigue activa (−12 mg/dL). Es una
estimación: conviene confirmar con una medición antes de actuar.»

Y una pantalla de factores a un toque, con las cinco contribuciones, cada una con su nombre en
palabras y su cifra con signo.

**En modo sin sensor no aparece nada de esto**, y el aviso de RF-10b sigue arriba, fijo y sin
poder descartarse. No es un caso degradado: es la regla 8.

## 2. C-16 — ¿dónde corre la predicción?

Es una contradicción que lleva meses escrita en dos sitios y nadie había enfrentado.

- `CLAUDE.md` de **glucy-ml** dice: «la inferencia corre en el dispositivo, sin red, en
  milisegundos, y ningún dato de glucosa sale del teléfono para predecir».
- `CLAUDE.md` de **glucy-backend** lista `GET /predict` entre los siete endpoints, y el backend
  lo tiene construido y probado desde el paso 5.

Las dos cosas están hechas. La pregunta es cuál usa la app.

### Los tres hechos que deciden

1. **Core ML no produce SHAP.** El artefacto convertido devuelve un número y nada más. Las cinco
   contribuciones salen de TreeSHAP sobre el XGBoost original, que vive en el backend.
2. **La app tiene que funcionar sin red** (regla 1, caso P-07). Una predicción que necesite
   servidor desaparece en el modo avión, y la pantalla de inicio es justo la que no puede
   quedarse en blanco.
3. **La explicación en lenguaje natural no puede correr en el teléfono.** Qwen3 vive en el
   servidor y no va a caber en un iPhone; por eso existe `POST /explain`.

### La decisión

**Las dos, y cada una para lo suyo:**

| Qué | Dónde | Si no hay red |
| --- | --- | --- |
| **El número predicho** que se enseña | **Core ML, en el teléfono** | sigue saliendo |
| Las cinco contribuciones y la explicación | backend: `GET /predict` y `POST /explain` | no salen, y la pantalla lo dice en una línea |

No es un apaño: es la misma forma del resto de la app. Lo crítico es local, lo que enriquece es
remoto, y lo remoto nunca bloquea una pantalla.

### Lo que esto obliga, y es lo que hay que cuidar

**El número de Core ML y el número de `/predict` tienen que ser el mismo.** Si la pantalla
enseña 113 y la explicación habla de una bajada calculada sobre 108, la app se contradice sola
delante de alguien que está decidiendo si come algo.

Ya hay media solución: el paso 3 de glucy-ml comprueba la conversión **fila por fila contra
XGBoost**, y ahí se encontró que Core ML perdía el `base_score` —el teléfono habría predicho
143 mg/dL por debajo del valor real—. Lo que falta es del lado de la app:

- La app manda a `/predict` **el mismo instante** que usó para predecir, y compara. Si difieren
  en más de **1 mg/dL**, se queda con el suyo —que es el que ya enseñó— y **deja el desacuerdo
  registrado**. Un desacuerdo silencioso entre los dos caminos es el peor resultado posible:
  nadie lo ve hasta que alguien compara dos pantallas.
- La explicación que se enseña dice de qué valor habla. Si el backend respondió sobre otro, no
  se enseña.

## 3. Lo que la app le pide al backend, y qué hace sin él

`GET /predict` devuelve, desde el pull request #16 del backend, **dos listas**:

- `shap`, con los nombres crudos (`rezago_30`, `hora_sin`), que es lo que hay que reenviar tal
  cual a `POST /explain`;
- `factores`, ya con nombre en palabras, sumados y recortados a cinco, que es **lo que la
  pantalla dibuja**.

**La app no traduce nombres de características.** Repetir ese diccionario en Swift lo deja viejo
el día que el pipeline agrega una columna, y nadie se entera hasta que alguien lee «rezago_45»
en la pantalla. Si llega un factor con guion bajo, es un error del servidor: no se enseña.

Las dos llamadas van **en segundo plano y nunca bloquean**. `GET /predict` responde en menos de
200 ms, pero `POST /explain` tarda de uno a tres segundos, y la pantalla de inicio tiene que
estar pintada mucho antes.

`PrediccionCache` ya existe y ya tiene todo lo que hace falta: `valorMgDl`, `horizonteMin`,
`modo`, `versionModelo`, `explicacion` y `shapJson`. **No se toca el modelo**, así que este paso
no lleva migración. Lo que se guarda ahí es lo que se repinta al instante en el siguiente
arranque, sin red y sin recalcular.

## 4. Las tres cosas que no pueden pasar

1. **Nunca una dosis ni unos gramos.** Ni calculados, ni sugeridos, ni insinuados. Es la regla 7
   y es la frontera con un dispositivo médico regulado. El backend ya bloquea la respuesta del
   modelo de lenguaje si aparece un patrón de dosificación; **la app no vuelve a validar el
   texto**, porque duplicar esa regla en dos sitios es garantizar que un día digan cosas
   distintas. Lo que sí hace es no inventar texto propio: enseña el que llegó o no enseña nada.
2. **En modo sin sensor no hay predicción de hipoglucemia** (RF-10b). No es que se oculte el
   número: es que la app **declara** que no puede anticiparla, arriba y sin poder descartarse.
3. **Lo predicho nunca se parece a lo medido.** Línea punteada contra continua. `GraficaGlucosa`
   ya tiene el estilo `.proyectada` con `dash: [5, 4]`; úsalo y no inventes otro. Una persona
   medio dormida tiene que distinguirlas sin leer la leyenda.

Y una cuarta, de redacción: la frase va **en presente y de tú** —«vas a bajar en la próxima
hora»—, con su cifra, su unidad y su hora, y sin tecnicismos. «Carbohidratos que siguen
activos», nunca «COB».

## 5. Qué se construye

```
Glucy/Data/CoreML/
  ModeloGlucosa.swift        carga el .mlmodel y predice; detrás de un protocolo, como HealthKit
  VectorDeCaracteristicas.swift   arma las columnas en el MISMO orden que el pipeline
Glucy/Data/Network/
  ClienteBackend.swift       + predecir() y + explicar()
  CargasDeDescarga.swift     las estructuras de respuesta, campo por campo
Glucy/Domain/UseCases/
  CalcularPrediccion.swift   decide el modo, predice en local, pide factores y explicación
Glucy/Features/Inicio/       la cifra a 30 min y la frase
Glucy/Features/Factores/     la pantalla de las cinco contribuciones
Glucy/Resources/             el .mlmodel versionado
```

**El orden de las columnas es el contrato que más barato es romper y más caro es encontrar.**
`CARACTERISTICAS_DENSAS` del pipeline y las entradas del `.mlmodel` tienen que coincidir una a
una; si se desplazan, la predicción sale con apariencia de normal y está mal. Una prueba de
dominio que fije la lista entera, en orden, vale más que diez de interfaz.

## 6. Lo que no hay que hacer

- **No pongas la decisión del modo en la vista ni en el ViewModel.** `modoActual` es una regla
  del dominio y ya existe; se usa, no se reimplementa.
- **No guardes la predicción del backend como si fuera propia.** `PrediccionCache` nace `local`
  y no viaja: subir de vuelta la predicción del servidor es un viaje redondo sin valor.
- **No mandes nada de quién es la persona.** `/predict` y `/explain` reciben glucosa, COB, IOB y
  hora; nunca nombre, apellidos, peso ni notas (regla 3).
- **No inventes un número cuando no haya modelo.** Sin `.mlmodel` cargado, Inicio se queda como
  está hoy y lo dice. Una línea base de respaldo en la app sería una cifra sobre la que alguien
  actuaría creyendo que es una predicción.
- **No toques `Theme.swift`, ningún `@Model` ni ninguna etapa de migración.**

## 7. Cuerpo del pull request

```
feat: la predicción a 30 minutos en Inicio, con sus factores y su explicación

Antes: Inicio enseñaba la glucosa de ahora y las últimas horas medidas. Nada
miraba hacia adelante, que es lo que el proyecto promete en su eslogan.

Después: debajo de la cifra de ahora sale la de dentro de media hora, con la
línea punteada que la gráfica ya sabía dibujar, una frase en español llano y una
pantalla de factores a un toque. En modo sin sensor no sale nada de esto y el
aviso de RF-10b sigue arriba (regla 8).

Resuelve C-16, que llevaba meses escrito en dos sitios: el número predicho lo
calcula Core ML en el teléfono, así que sigue saliendo sin red; las cinco
contribuciones y la explicación vienen del backend, y cuando no hay nadie del
otro lado la pantalla lo dice en una línea en vez de quedarse en blanco.

Los dos caminos tienen que dar el mismo número. La app manda a /predict el mismo
instante que usó para predecir y, si difieren en más de 1 mg/dL, se queda con el
suyo y deja el desacuerdo registrado. Un desacuerdo silencioso entre los dos
caminos no lo ve nadie hasta que alguien compara dos pantallas.

Sin migración: PrediccionCache ya tenía todo lo que hacía falta.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01U7KrWasYkZhWRhqUnQcJ86
```

---

## 8. El texto para pegarle a Claude Code

> Lee `CLAUDE.md`, `docs/fase3-prediccion-en-la-app.md`, `docs/paso-7-sincronizacion.md` y
> `Glucy/Features/Comun/GraficaGlucosa.swift`. Trabaja en una rama
> `feature/prediccion-en-la-app` que sale de `develop`
> (`git switch -c feature/prediccion-en-la-app origin/develop`); **no trabajes en `main` ni en
> `develop`**.
>
> **Antes de escribir nada, dime si el `.mlmodel` ya está en `Glucy/Resources/`.** Si no está,
> construye todo lo demás contra el protocolo y deja la app como está hoy cuando no haya modelo;
> no inventes un número de respaldo.
>
> Construye lo del apartado 5. La predicción en local con Core ML, detrás de un protocolo como
> HealthKit; los factores y la explicación desde el backend, en segundo plano y sin bloquear
> nunca la pantalla.
>
> **El orden de las columnas del vector tiene que coincidir una a una con
> `CARACTERISTICAS_DENSAS` del pipeline**, y eso lo fija una prueba de dominio con la lista
> entera escrita en orden. Si se desplazan, la predicción sale con apariencia de normal y está
> mal.
>
> **La app no traduce nombres de características.** El backend devuelve `factores` con el nombre
> ya en palabras; si llega uno con guion bajo, no se enseña.
>
> **No vuelvas a validar el texto de la explicación.** El backend ya bloquea los patrones de
> dosificación; duplicar esa regla en dos sitios es garantizar que un día digan cosas distintas.
> Lo que sí: no inventes texto propio.
>
> **No toques `Theme.swift`, ningún `@Model` ni ninguna etapa de migración.** Este paso no lleva
> migración; si crees que la necesita, dímelo antes de escribirla.
>
> Corre las pruebas antes de decir que está. Sube la rama y **abre el pull request contra
> `develop`** con el cuerpo del apartado 7
> (`gh pr create --base develop --head feature/prediccion-en-la-app`); sin pull request la
> integración continua no corre. **Espera a que el run termine y dime su resultado antes de que
> yo lo fusione**: «cancelado» no es verde. No lo fusiones tú.
