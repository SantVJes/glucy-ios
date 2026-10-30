# El aviso de hipoglucemia y el Modo de Concentración

Limitación encontrada el **30 de octubre de 2026** al compilar en el iPhone. Va al reporte tal
como está escrita aquí: es del entorno de desarrollo, no del diseño, y se puede quitar con
dinero.

## Qué pasa

`AvisosDelSistema` entrega el aviso de una baja prevista con
`interruptionLevel = .timeSensitive`. Para que iOS respete ese nivel —y el aviso atraviese un
«No molestar» o un Modo de Concentración— el objetivo tiene que declarar la capacidad **Time
Sensitive Notifications**.

**Una cuenta de desarrollador personal no la soporta.** Al declararla, Xcode no puede crear el
perfil de aprovisionamiento y la app **no se instala**:

```
Cannot create a iOS App Development provisioning profile for "Freelancer.Glucy".
Personal development teams, including "Jesus Santiago", do not support the
Time Sensitive Notifications capability.
```

Comprobado el 30/10/2026 con Xcode y SDK de iOS 27.0. La capacidad exige la membresía de pago
del Apple Developer Program, 99 dólares al año, que este proyecto académico no tiene.

## Qué consecuencia tiene, sin suavizarla

El aviso se entrega con **prioridad normal**. Eso significa que:

- Sale, vibra y aparece en la pantalla de bloqueo con el teléfono en uso normal. **Lo que la
  app promete, lo cumple**, siempre que el teléfono no esté silenciado por el sistema.
- **Un Modo de Concentración lo calla.** Y el modo que la gente usa de madrugada es
  precisamente «Sueño», así que el caso para el que existe este aviso —una hipoglucemia
  prevista a las tres de la mañana— es el caso en el que puede no sonar.

No hay forma de sortearlo por programa, y no se intentó ninguna. `.critical`, el otro nivel que
atraviesa un Modo de Concentración, necesita un permiso que Apple concede caso por caso a
software médico certificado, y **Glucy no es un dispositivo médico certificado**: pedirlo sería
afirmar lo contrario.

## Qué se hizo

La línea `.timeSensitive` **se queda** en el código. No estorba —iOS la ignora sin fallar— y el
día que haya cuenta de pago basta con agregar la capacidad en Xcode, sin tocar una línea de
Swift.

La clave del entitlement **no se queda** en el repositorio, porque con la cuenta de hoy impide
compilar. Vivió unos minutos en `develop` (PR #27) y se quitó en cuanto se vio el error
(PR #28).

## Qué decir en el reporte

Esto no se resuelve en el apartado de pruebas, se declara en el de limitaciones, junto a las
otras tres del mismo tipo: el modelo entrenado con el simulador fisiológico y no con OhioT1DM,
la validación del modo sensor sin un sensor comercial (riesgo R-8), y el piloto corrido con
datos sintéticos (C-17).

Y conviene decirlo con la frase que de verdad importa: **la app avisa, pero en el escenario de
madrugada el sistema operativo puede silenciar ese aviso, y eso no depende de Glucy.** Una
versión distribuida con una cuenta de pago no tendría la limitación.
