# Paso 7 de la fase 2 — la cola se vacía

Este es el paso que cierra la fase 2 del lado del teléfono. El backend ya tiene sus ocho
endpoints; aquí la app empieza a hablarle, **sin dejar de funcionar completa si no hay nadie
del otro lado**.

Es el único paso de la fase 2 que vive en `glucy-ios`.

---

## 1. Qué cambia para quien usa la app

**Antes:** la cola se llenaba y no se vaciaba nunca. La pantalla de Ajustes decía «Todavía no
hay servidor», con el interruptor de sincronización encendiéndose sin efecto y un contador que
solo subía.

**Después:** si la app trae una dirección de backend, la cola se vacía con wifi, por lotes y lo
más antiguo primero. En Ajustes hay un botón «Sincronizar ahora», el contador baja, y lo que el
servidor no aceptó se queda con su motivo a la vista en lugar de desaparecer.

Si la app **no** trae dirección —que es como se compila hoy— todo sigue igual que antes, el
botón no aparece y el pie lo dice. Eso no es un caso degradado: es la regla 1.

## 2. Las decisiones

### 2.1 Lo que sube se escribe campo por campo, en estructuras aparte

`LecturaSubida`, `ComidaSubida`, `DosisSubida` y `PerfilSubido` no son los `…Dato` del dominio
con un codificador en snake_case. Son estructuras **separadas** con su propia lista de campos.

Si subiera el `Dato` completo, cualquier campo nuevo del dominio empezaría a viajar sin que
nadie lo decidiera, y entre esos campos están `nota`, `nombre`, `apellidos` y `pesoKg`, que
nunca salen del teléfono (regla 3). Escribirlas aparte hace que **agregar un campo al contrato
sea un cambio visible en el diff** y no un efecto secundario.

De los dieciséis campos de `LecturaGlucosaDato` suben cinco o seis. `confianzaOcr` y
`valorLeidoOcr` se quedan porque no deciden nada (D-11) y `origen` ya dice que la lectura vino
de una foto; `atipica` se queda porque el pipeline la recalcula.

### 2.2 `contexto` → `contexto_comida`, y es el único campo con dos nombres

En Swift la propiedad se llama `contexto` y la columna del servidor es `contexto_comida`. Con
`extra="forbid"` del otro lado, un renglón con la clave equivocada **no falla visiblemente**:
va a cuarentena con su motivo, la app lo marca en rojo y nadie entiende por qué.

Por eso `LecturaSubida` lleva `CodingKeys` explícitas y hay una prueba que comprueba el JSON
exacto. Es la clase de error que se encuentra tarde, y aquí se encuentra en segundos.

### 2.3 El perfil sube primero, y solo seis valores

Los umbrales y la duración de acción de la insulina son lo que el pipeline necesita para el IOB
y para derivar la alerta (C-7). Si no llegan, el servidor calcula con los valores por omisión en
lugar de con los de esta persona, y nada falla.

`POST /perfil` es un `upsert`, así que se manda en cada ventana sin llevar la cuenta. De la
fecha de nacimiento sube **solo el año**: para la edad sobra, y el día exacto es un dato
identificador de más.

### 2.4 Aceptado y duplicado terminan igual de bien

El servidor contesta tres listas. `aceptados` y `duplicados` se tratan idénticamente: en los dos
casos el dato ya está del otro lado.

Un uuid repetido **no es un conflicto**, es un duplicado, y la app reintenta lotes a propósito
—en una ventana de wifi que se corta, el mismo lote sale dos veces—. Si un duplicado contara
como error, un reintento normal dejaría media cola marcada en rojo.

### 2.5 La fila resuelta se borra de la cola; la rechazada se queda

La cola es una cola, no una bitácora. Ocho semanas de sensor son miles de filas, y dejarlas en
`confirmado` haría cada vez más lento leer las pendientes. El rastro durable es el `syncEstado`
del registro mismo, que es lo que sobrevive y lo que se ve en el informe.

Lo que **no** se borra es la fila rechazada: se queda con su motivo y su contador de intentos
(RF-22). Un dato rechazado sin rastro es una falla invisible.

### 2.6 La tabla de códigos, en los términos del teléfono

`ErrorBackend` no es una traducción del código HTTP: es **qué hace la app con él**.

| Código | Caso | Qué hace la app |
| --- | --- | --- |
| `200` | las tres listas | reparte: resueltos fuera de la cola, cuarentena con su motivo |
| `400` | el sobre no sirve | **no se reintenta**: mandarlo otra vez daría el mismo 400 |
| `401` | el token venció | se detiene la ventana; las filas se quedan pendientes |
| `409` | no lo usan los lotes | si llegara, se trata como duplicado |
| `5xx` o sin red | el servidor o la red | las filas esperan la siguiente ventana, sin marcar nada |

El contrato del paso 1 del backend dice que con un `401` la app «renueva y reintenta una vez».
**Eso todavía no se puede hacer: en la fase 2 el servidor verifica el token pero no lo emite.**
Así que la ventana se detiene y Ajustes dice que la sesión caducó. Escribir el reintento ahora
sería código que nunca corre; entra cuando exista el endpoint que entrega tokens.

### 2.7 El token va al Keychain, con `ThisDeviceOnly`

`UserDefaults` es un archivo de texto dentro del contenedor de la app: en un teléfono con
jailbreak, o en un respaldo sin cifrar, el token se lee a simple vista.

Con `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` el token **no viaja en el respaldo ni a otro
teléfono**. Tiene un costo que conviene decir: al restaurar el teléfono el token no está y hay
que volver a obtenerlo. Es el costo correcto; una credencial que sobrevive a la restauración es
una credencial que también sobrevive a una copia.

Y **borrar la cuenta ahora borra el token**. Era lo que faltaba: la serie sigue existiendo en el
servidor, y dejar la credencial en un teléfono que ya no tiene la cuenta es dejar la llave
puesta.

### 2.8 Una fila cuyo registro ya no existe sale de la cola

El «Deshacer» de la pantalla de registro borra el registro y su fila. Pero si la fila quedara
huérfana por cualquier camino, subirla mandaría al servidor un dato que en el teléfono ya no
existe —y el teléfono es el dueño del dato—. Se saca de la cola y el resumen lo cuenta.

### 2.9 Un tipo sin endpoint se marca, no se deja pendiente

`evento_contexto` y `alerta` no tienen a dónde ir: el servidor no ofrece endpoint para el
contexto (C-10, C-11) y de las alertas la autoridad es él, no el teléfono. Hoy **nadie encola
esos tipos**, así que esto es una red por si mañana alguien lo hace.

La fila se marca con su motivo en lugar de dejarla pendiente, aunque el dato no tenga nada malo.
Una fila que nadie puede subir y que se queda al frente de la cola **la tapa**:
`pendientes(limite:)` devuelve lo más antiguo primero, y con el tope lleno de filas intocables
las lecturas de hoy no subirían nunca y nada fallaría. Hay una prueba de eso.

### 2.10 La ventana está acotada

Veinte rondas por ventana. Con una cola de ocho semanas de sensor son miles de filas y subirlas
de un tirón tendría la app ocupada mucho tiempo; la ventana siguiente continúa donde quedó la
anterior, y el resumen dice cuántas faltan.

### 2.11 La dirección del backend vive en el `Info.plist`, no en el código

`INFOPLIST_KEY_GlucyBackendURL`, vacía por omisión. Cambia entre el servidor de casa y el de la
entrega, y una dirección no es un secreto. Vacía o inválida, la sincronización se queda apagada
en lugar de adivinar.

```
INFOPLIST_KEY_GlucyBackendURL = "https://…";   // en los dos esquemas del proyecto
```

El token se guarda aparte, en el Keychain, y **no hay ninguna llave en el repositorio**.

## 3. Lo que se agregó

```
Glucy/Data/Network/ConfiguracionBackend.swift   dirección y topes; sin dirección, apagado
Glucy/Data/Network/CargasDeSubida.swift         las cuatro cargas, el sobre y las tres listas
Glucy/Data/Network/ClienteBackend.swift         el protocolo y ErrorBackend
Glucy/Data/Network/GlucyHTTP.swift              el cliente de verdad y la tabla de códigos
Glucy/Data/Seguridad/Llavero.swift              el token en el Keychain
Glucy/Data/Sync/EstadoDeRed.swift               NWPathMonitor detrás de su protocolo
Glucy/Domain/UseCases/SincronizarConBackend.swift   la ventana completa
```

Y se tocaron: `RepositorioCola` (+`confirmar`, +`contarConError`), los tres repositorios de
registros (+`marcarSync`), `ConsultarColaPendiente` (+`conError`), `BorrarTodo` (+el token),
`ContenedorDependencias`, `AjustesViewModel` y `AjustesView`.

## 4. Lo que no entra en este paso

- **`GET /predict` y `POST /explain` desde la app.** Suben datos; todavía no piden predicción.
  La pantalla de inicio sigue enseñando lo que calcula el teléfono. Entra cuando haya artefacto
  del modelo, en la fase 3.
- **El reintento tras un `401`**, por lo dicho en 2.6.
- **Certificate pinning.** El `CLAUDE.md` lo pide y va a entrar, pero fijar un certificado
  requiere el certificado del servidor de la entrega, que todavía no existe. Un pinning que no
  compara nada es peor que no tenerlo: da la impresión de que está.
- **Sincronización en segundo plano** (`BGAppRefreshTask`). Hoy la ventana se abre cuando la
  persona entra a Ajustes y toca el botón. Que se abra sola con wifi es un paso aparte y se
  prueba en el teléfono, no en el simulador.
- **La cola de xAPI** (`ColaXapi`), que es de la fase 6 y tiene su propio destino.

## 5. Las pruebas

Treinta y cuatro nuevas, en dos archivos:

- **`ContratoDeSubidaTests`** — el contrato campo por campo, sobre el JSON exacto que sale del
  teléfono: la clave `contexto_comida`, las claves de cada carga y que no viaje ninguna más, los
  valores de los enums contra los del servidor, la fecha con offset, que la nota y el peso no
  estén, los gramos totales de una comida, las tres listas, un renglón en cuarentena sin uuid
  legible y la tabla de códigos.
- **`SincronizarConBackendTests`** — la ventana completa con un backend de mentira: P-08 (datos
  móviles solo con el botón), P-07 (sin red nada se marca), la sincronización apagada, las tres
  listas repartidas, RF-22 (el motivo queda en la cola), los códigos uno por uno, el orden y el
  tamaño de los lotes, los tres tipos en una ventana, la fila huérfana, el tipo sin endpoint que
  no tapa la cola, la ventana acotada, y que ningún mensaje de la pantalla dé una instrucción ni
  enseñe jerga.

Más una en `BorrarTodoTests`: borrar la cuenta borra el token.

**Lo que no se puede probar sin servidor** —que una petición de verdad salga, que el `401` de un
servidor real se vea como `401`— se comprueba a mano contra el backend corriendo en local, con
el token de prueba que genera `scripts/token-de-prueba.py` del repositorio del backend.
