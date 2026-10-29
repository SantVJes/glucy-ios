# Fase 7 — El piloto de usabilidad

La fase 7 es «piloto de usabilidad y documentación final». Este documento cubre la primera
mitad: a quién se le pone la app enfrente, qué se le pide hacer, qué se mide, qué se firma antes
y qué de todo eso acaba en el reporte.

No lleva código. La app de la fase 1 está completa y el piloto no se construye: **se corre**. Por
eso aquí no hay texto para pegarle al Claude Code del Mac; lo que hay es un guion para una tarde
con cinco personas y una libreta.

Se escribe ahora, a finales de octubre, y no en la semana del piloto, por una razón práctica: un
protocolo improvisado el mismo día produce cinco sesiones distintas, y cinco sesiones distintas
no se pueden comparar ni resumir en una tabla.

---

## 0. Qué prueba este piloto, y qué no

Prueba **la interfaz**: si una persona con diabetes puede registrar lo que hizo, entender lo que
ve y salir de la pantalla sabiendo algo que no sabía al entrar.

No prueba si la app sirve clínicamente, no prueba la predicción y no prueba la adherencia a
largo plazo. La exactitud de la predicción se mide con la rejilla de Clarke en la fase 3, sobre
datos, no sobre opiniones; y nadie puede decir en una sesión de cuarenta minutos si usaría esto
durante seis meses.

La distinción importa porque es la que mantiene al piloto del lado correcto de la frontera del
proyecto: **Glucy no es un dispositivo médico certificado** y jamás calcula ni sugiere una dosis
(regla 7). Un piloto que midiera «¿te ayudó a decidir qué hacer?» estaría evaluando justo lo que
la app tiene prohibido hacer.

---

## 1. C-17 — ¿con los datos reales de la persona, o con un perfil de demostración?

**La contradicción.** El proyecto quiere probar la app con usuarios de verdad. El proyecto
también dice que lo que identifica a la persona no sale del teléfono (regla 3) y que el teléfono
es el dueño del dato (regla 1). Y la app enseña una cifra de glucosa a alguien que toma
decisiones de tratamiento con cifras de glucosa. Las tres cosas chocan en cuanto alguien abre
Glucy con sus propias lecturas delante de quien está tomando notas.

Las tres salidas posibles:

| Opción | Qué pasa | Por qué se descarta o se elige |
| --- | --- | --- |
| **A.** La persona instala Glucy en su iPhone y registra sus datos reales durante la sesión | Lo más realista | Pone datos de salud de un tercero delante del investigador, sin comité de ética y sin resguardo. Y deja una cifra predicha enfrente de alguien que podría actuar sobre ella. **No.** |
| **B.** La sesión corre en **el iPhone del proyecto**, con un perfil de demostración y datos sintéticos | La persona registra «su» glucosa de hoy, pero sobre un perfil que no es suyo y en un teléfono que no se lleva | El investigador nunca toma custodia de datos de salud ajenos, y ninguna cifra que se vea es de esa persona. **Sí.** |
| **C.** Solo se enseñan capturas de pantalla y se pregunta | Cero riesgo | Deja de ser usabilidad: nadie toca nada, y lo que falla en una app falla al tocarla |

**Queda la B.** El piloto se corre en el iPhone 17 del proyecto, con el perfil de demostración y
la sincronización apagada. La persona teclea cifras que se le dan en una tarjeta («tu glucómetro
marcó 243»), no las suyas.

Dos consecuencias que hay que escribir en el reporte, no esconder:

1. **Pierde realismo.** Teclear una cifra que te dieron no es lo mismo que teclear la tuya
   después de pincharte. Lo que el piloto mide bien es si la pantalla se entiende y si el
   recorrido se completa; lo que mide peor es la carga emocional del momento real.
2. **Si alguien quiere instalarla de todas formas**, se puede: es su teléfono y su decisión. Pero
   entonces se le entrega por escrito el aviso de que la app informa y no prescribe, se le dice
   que siga midiendo como siempre, y **sus datos no entran al piloto**: lo que haga en su casa no
   se recoge, no se anota y no se reporta.

---

## 2. Quiénes, y por qué cinco

**Cinco personas.** No es un número redondeado al azar: con cinco participantes una prueba de
usabilidad encuentra la mayor parte de los problemas de interfaz, porque los problemas graves los
tropieza casi cualquiera y a partir del quinto empiezan a repetirse los mismos.

Y hay que decir el otro lado con el número en la mano, igual que se hace con los doce sujetos de
OhioT1DM (riesgo R-2): **cinco personas no dan poder estadístico.** El SUS que salga de aquí es
indicativo, con un margen amplio, y el reporte lo dice así en lugar de presentar un promedio con
un decimal como si fuera una medición.

Los cinco perfiles, elegidos para cubrir a quién se diseñó la app:

| # | Perfil | Por qué está |
| --- | --- | --- |
| P-1 | diabetes tipo 1, **con** sensor comercial | el usuario principal en su mejor caso: modo sensor |
| P-2 | diabetes tipo 1 o tipo 2 insulinodependiente, **sin** sensor | el usuario principal en su caso más común, y el que más depende del aviso de la regla 8 |
| P-3 | diabetes tipo 2 insulinodependiente | el que el modelo de la fase 3 peor cubre; su lectura de la pantalla vale doble |
| P-4 | prediabetes o resistencia a la insulina | el usuario secundario: registra comidas, no dosis |
| P-5 | **más de 60 años, o con vista cansada** | el peor caso de accesibilidad con una persona de verdad, que es lo que `AccesibilidadUITests` no puede hacer |

**Edad mínima 15 años**, la misma del perfil de la app. Nadie menor de edad sin que su madre,
padre o tutor firme también.

De dónde salen: una persona sola en una universidad recluta por conveniencia, entre familia,
conocidos y la comunidad del campus, o pidiéndolo en una asociación de diabetes. **Eso es un
muestreo por conveniencia y así se nombra en el reporte**, porque llamarlo de otra manera sería
presentar como representativo lo que no lo es.

---

## 3. El consentimiento, por escrito

Se imprime, se lee en voz alta, se firma, y la persona se queda con una copia. Sin firma no hay
sesión. Texto palabra por palabra:

> **Consentimiento para participar en una prueba de uso de la app Glucy**
>
> Glucy es un proyecto académico de la Universidad Tecmilenio. No es un producto comercial y
> **no es un dispositivo médico certificado**: informa, no prescribe ni administra, y nunca
> calcula ni sugiere una dosis de insulina.
>
> Te vamos a pedir que uses la app durante unos 40 minutos en un iPhone del proyecto, siguiendo
> unas tareas, y que digas en voz alta lo que piensas mientras lo haces. No es un examen: lo
> que se está probando es la app, no tú. Si algo no se entiende, el problema es de la app.
>
> **Qué datos se recogen:** notas escritas sobre qué tareas se completaron, cuánto tardaron y
> qué comentaste, más un cuestionario de diez preguntas al final. Nada de eso lleva tu nombre:
> en las notas apareces como «P-1», «P-2», y así.
>
> **Qué datos NO se recogen:** no se te piden tus cifras de glucosa, ni tus dosis, ni tu
> historial. Las cifras que vas a teclear en la app te las vamos a dar escritas en una tarjeta y
> no son tuyas. No se graba video ni audio, no se toman fotos y no se captura la pantalla.
>
> **Dónde acaban:** en el reporte final del proyecto, en forma de resumen, sin nombres. Las
> notas en papel se destruyen cuando el reporte se entrega.
>
> **Puedes parar cuando quieras**, sin dar explicaciones y sin consecuencias, y puedes pedir que
> tus notas se descarten incluso después de terminar.
>
> No uses nada de lo que veas hoy para tomar una decisión sobre tu tratamiento. Sigue midiéndote
> como siempre y sigue las indicaciones de tu médico.
>
> Nombre: ______________________  Firma: ______________________  Fecha: ____________

Si la persona se hace la pregunta obvia («¿y entonces para qué sirve?»), la respuesta honesta es
la que ya está en el reporte: para avisar media hora antes, cuando el modelo exista y cuando haya
un sensor detrás, y siempre pidiendo confirmar con una medición.

---

## 4. Las seis tareas, palabra por palabra

Se leen tal cual. **No se explica cómo hacerlas**: en el momento en que el investigador dice
«dale ahí», la tarea deja de medir nada.

El teléfono arranca con la app **recién instalada y sin perfil** para la tarea 1, y con el perfil
de demostración ya cargado de la 2 en adelante.

| # | Lo que se dice | Se completa cuando | Requisito |
| --- | --- | --- | --- |
| 1 | «Acabas de instalar la app. Déjala lista para usarla.» | hay un perfil guardado **con su consentimiento** y se ve la pantalla de inicio | el alta del paso 9, y la LFPDPPP |
| 2 | «Te acabas de medir y el glucómetro marcó **243**. Regístralo.» | hay una lectura de 243 mg/dL con origen manual | RF-01 |
| 3 | «Ahora en vez de teclearlo, usa la cámara con esta pantalla de glucómetro.» (marca **87**) | hay una lectura de 87 **confirmada por la persona** | RF-02, D-11, caso P-01 |
| 4 | «Te vas a comer esto. Regístralo.» (se le da un producto real de la cocina, con su código de barras) | hay una comida con sus carbohidratos | RF-12 |
| 5 | «Te aplicaste **6 unidades** de tu insulina rápida. Regístralo.» | hay una dosis de 6 UI marcada como bolo | RF-14 |
| 6 | «Mira la pantalla de inicio y dime, con tus palabras, qué te está diciendo.» | la persona termina de hablar | RF-10b (RF-08 a RF-10 son de la fase 3) |

Dos notas sobre la tarea 1 y la tarea 3:

- **La tarea 1 hace que la persona acepte el consentimiento de la app**, que es el de la LFPDPPP
  y no tiene nada que ver con el papel que firmó al entrar. Son dos consentimientos distintos y
  conviene decírselo, o va a pensar que está firmando dos veces lo mismo.
- **La tarea 3 necesita un número que el OCR pueda leer de verdad.** Lo primero que se intenta es
  una foto impresa de la pantalla de un glucómetro; si Vision no la lee bien sobre papel, se usa
  un glucómetro real enseñando una lectura de su memoria. Eso se resuelve **en la sesión de
  ensayo**, no con P-1 delante.

Y al final la pregunta que más vale de las siete, antes del cuestionario:

> «Son las tres de la mañana, te despiertas sintiéndote mal y ves esta pantalla. ¿Qué harías?»

La respuesta correcta es «me mido». Cualquier respuesta que empiece por «me tomaría» o «me
inyectaría» **es un hallazgo grave de la app**, no del participante: significa que la pantalla
se lee como una indicación de tratamiento, y eso es exactamente lo que la regla 7 prohíbe.

---

## 5. Qué se mide en cada tarea

Cuatro cosas, en la libreta, una fila por tarea y por persona:

1. **¿Se completó?** Sola / con una pista / no. «Con una pista» cuenta como fallo de la app.
2. **Cuánto tardó**, en segundos, del final de la frase al criterio de la tabla.
3. **Dónde dudó**: la pantalla y lo que dijo. Esto es lo que después se arregla; los segundos
   solo dicen dónde mirar.
4. **Qué entendió** en la tarea 6, copiado lo más literal que se pueda.

De la tarea 6 salen las dos comprobaciones que ninguna prueba automatizada puede hacer:

- **¿Distinguió lo medido de lo predicho?** La regla de interfaz del proyecto es que la línea
  continua y la punteada se tienen que distinguir sin leer la leyenda. Si una persona despierta y
  tranquila no las distingue, una persona en hipoglucemia de madrugada tampoco.
- **¿Entendió que sin sensor la app no puede avisarle de una bajada?** El aviso fijo y no
  descartable de arriba de la pantalla existe para eso (RF-10b, regla 8). Si no lo leyó, o lo
  leyó y no lo entendió, el aviso no está haciendo su trabajo, y eso es el hallazgo más
  importante que este piloto puede producir.

---

## 6. El cuestionario SUS, en español

Diez afirmaciones, se responden de **1 (muy en desacuerdo) a 5 (muy de acuerdo)**. Se contestan
en papel, sin el investigador mirando, al terminar las tareas.

Esta redacción es una **adaptación al español de México** del cuestionario original de Brooke
(1996). Hay traducciones validadas al español; si se consigue una, se usa esa y se cita en lugar
de esta. Mientras tanto se usa la de abajo y **el reporte dice que es una adaptación propia**,
porque una traducción casera cambia un poco lo que se mide y eso se declara en lugar de
presentarse como el instrumento estándar.

| # | Afirmación |
| --- | --- |
| 1 | Creo que usaría esta app seguido. |
| 2 | La app me pareció más complicada de lo necesario. |
| 3 | La app me pareció fácil de usar. |
| 4 | Creo que necesitaría que alguien me ayudara para poder usar esta app. |
| 5 | Las distintas partes de la app funcionan bien juntas. |
| 6 | Me pareció que la app se contradice en algunas cosas. |
| 7 | Creo que la mayoría de la gente aprendería a usar esta app rápido. |
| 8 | La app me pareció incómoda de usar. |
| 9 | Me sentí seguro usando la app. |
| 10 | Tuve que aprender muchas cosas antes de poder usar la app. |

**Cómo se calcula**, que es donde se equivoca todo el mundo:

- En las impares (1, 3, 5, 7, 9) se le resta 1 a la respuesta.
- En las pares (2, 4, 6, 8, 10) se resta la respuesta de 5.
- Se suman los diez resultados y se multiplica por 2.5. Sale un número de 0 a 100.

Ese número **no es un porcentaje**. La referencia habitual es que alrededor de 68 es el promedio
de los sistemas medidos, así que por encima está mejor que la media y por debajo, peor. Con cinco
respuestas el reporte da el número **junto con las cinco respuestas individuales y la n**, para
que quien lo lea vea de dónde sale.

---

## 7. Cómo se registra la sesión sin romper las reglas del proyecto

- **Nada de video, audio ni fotos**, ni de la persona ni de la pantalla. La regla 6 dice que las
  imágenes no se guardan; grabar la pantalla de una app de salud en una sesión de usabilidad es
  la misma idea con otra ropa.
- **Notas en papel o en un archivo de texto**, con la persona nombrada P-1 a P-5 y sin ningún
  dato que la identifique.
- **La sincronización apagada** en Ajustes durante todo el piloto. Es lo que está por omisión
  (`sincronizacion_activa` arranca en falso), pero se comprueba antes de cada sesión.
- **El perfil de demostración se borra** del iPhone del proyecto al terminar las cinco sesiones.
- La foto del glucómetro de la tarea 3 es **una foto impresa de un glucómetro**, no de la persona
  ni de su aparato.

---

## 8. Qué se arregla después, y qué no

El piloto va a producir más hallazgos que días para arreglarlos. La regla de corte, decidida
antes de ver los resultados para no decidirla a conveniencia:

| Hallazgo | Qué se hace |
| --- | --- |
| Impidió completar una tarea, o alguien contestó la pregunta de las tres de la mañana con una acción de tratamiento | **se arregla**, con su pull request y su prueba |
| Un texto que se malentendió | **se arregla** si es cambiar palabras; es lo más barato que hay |
| Una pantalla que costó pero se completó | se anota y va a «trabajo futuro» del reporte |
| «Estaría bonito que…» | va a «trabajo futuro», sin excepción |

Lo que se arregle va con su caso de prueba, igual que todo lo demás. Un arreglo de usabilidad
sin prueba se vuelve a romper en el siguiente cambio de pantalla.

---

## 9. Qué va al reporte

Cinco cosas, y nada más:

1. **Quiénes participaron**, por perfil y sin nombres, y que el muestreo fue por conveniencia.
2. **La tabla de las seis tareas**: completadas solas, con pista y no completadas, de 5.
3. **El SUS**: el número, las cinco respuestas y la n, más la nota de que es una adaptación
   propia del cuestionario.
4. **Los tres hallazgos peores**, con lo que se dijo, lo que se cambió y el pull request donde se
   cambió.
5. **Lo que el piloto no valida**, que es el apartado siguiente.

---

## 10. Lo que este piloto no valida

Se escribe en el reporte con esta claridad, porque es la parte que un lector exigente va a
buscar:

- **Cinco personas, muestreo por conveniencia.** Sin poder estadístico y sin representatividad.
- **Datos sintéticos en un teléfono ajeno** (decisión C-17). No se midió el momento real, con la
  cifra propia y el susto propio.
- **Una sola sesión por persona.** No dice nada de qué pasa al tercer día ni al tercer mes.
- **No se midió utilidad clínica**, y no se podía: haría falta un protocolo con comité de ética,
  que está fuera del alcance de un proyecto de octavo semestre, y además rozaría la frontera que
  la regla 7 pone.
- **No se probó el modo sensor con un sensor comercial.** Eso es la fase 5, y su plan B está en
  [`sensor-de-prueba-en-healthkit.md`](sensor-de-prueba-en-healthkit.md).

---

## 11. Cuándo se corre

El piloto tiene que acabar antes de que el reporte se escriba, porque sus resultados van dentro.
Con la entrega final a finales de noviembre de 2026, el reparto que deja margen:

| Cuándo | Qué |
| --- | --- |
| **antes del 18 de noviembre** | conseguir a las cinco personas y agendar; es lo que más tarda y no depende de código |
| **19–21 de noviembre** | imprimir consentimientos y tarjetas de cifras, cargar el perfil de demostración, correr una sesión de ensayo con alguien que no cuente como participante |
| **22–25 de noviembre** | las cinco sesiones, una por día o dos por tarde |
| **26–27 de noviembre** | los arreglos que entren en la regla de corte del apartado 8 |
| **28–30 de noviembre** | el apartado del reporte, con la tabla y el SUS |

La sesión de ensayo no es opcional. La primera vez que se corre un guion se descubre que una
tarea estaba mal redactada, y descubrirlo con P-1 significa tirar una de las cinco sesiones.

---

## 12. Git y el pull request

```bash
git checkout develop && git pull origin develop
git checkout -b feature/piloto-de-usabilidad
# …el documento…
git add docs/fase7-piloto-de-usabilidad.md
git commit -m "docs: el protocolo del piloto de usabilidad y la decisión C-17"
git push -u origin feature/piloto-de-usabilidad
```

Un pull request contra `develop`, con el cuerpo de abajo.

---

## 13. El cuerpo del pull request, ya escrito

## Antes

La fase 7 era un renglón en la tabla de fases: «piloto de usabilidad y documentación final, al
final». No había a quién invitar, ni qué pedirle hacer, ni qué firmar antes, ni qué se iba a
medir. Y había una contradicción sin ver: probar la app con usuarios reales choca con la regla 3
del proyecto, porque pone datos de salud de un tercero delante de quien toma las notas.

## Después

`docs/fase7-piloto-de-usabilidad.md` tiene el piloto completo: cinco perfiles de participante y
por qué cinco, el consentimiento palabra por palabra, las seis tareas con su criterio de éxito y
su requisito, el cuestionario SUS en español con la fórmula de calificación, qué se arregla y qué
no, y el calendario hasta el 30 de noviembre.

Resuelve **C-17**: el piloto corre en el iPhone del proyecto con datos sintéticos, no con las
lecturas reales de la persona. Así el investigador nunca toma custodia de datos de salud ajenos y
ninguna cifra predicha queda delante de alguien que pudiera actuar sobre ella. Lo que se pierde
de realismo queda escrito en el documento y va al reporte.

La pregunta que más vale del guion no es una tarea, es esta: «son las tres de la mañana, te
sientes mal y ves esta pantalla, ¿qué harías?». Si alguien contesta «me inyectaría», el hallazgo
es de la app.

## Cómo

Solo documentación, ningún archivo de `Glucy/` tocado. El piloto no se construye, se corre, así
que este documento no lleva texto para pegar en Claude Code: lleva un guion para una tarde con
cinco personas y una libreta.

## Comprobado

- Las seis tareas apuntan a requisitos que ya están construidos y fusionados en `develop`.
- Las dos comprobaciones de la tarea 6 son las que `AccesibilidadUITests` y `P-15` no pueden
  hacer: distinguir la línea continua de la punteada, y entender el aviso de RF-10b.
- El calendario cabe antes de la entrega final de finales de noviembre de 2026.
