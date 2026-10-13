# Notas del release v0.1.0

Este archivo es el cuerpo de la etiqueta `v0.1.0` y del release en GitHub. Se escribe aquí para
que no haya que pegar un texto largo en la terminal: las órdenes lo leen con `-F`.

```bash
git checkout main && git pull origin main
git tag -a v0.1.0 -F docs/release-v0.1.0.md 735c508
git push origin v0.1.0
gh release create v0.1.0 --title "v0.1.0 — la app autónoma de la fase 1" -F docs/release-v0.1.0.md
```

---

Primera versión de Glucy: la app de iOS funcionando sola, sin servidor, sin red y sin sensor.
Cierra la fase 1 de siete.

## Qué hace ya

- **Glucosa por tres vías**: del sensor comercial leído de HealthKit, a mano, y por foto de la
  pantalla del glucómetro con Vision en el propio teléfono. Todo valor leído por OCR se muestra
  y se confirma antes de guardarse.
- **Comidas** por código de barras contra Open Food Facts, por foto de la etiqueta nutrimental
  o a mano, con carbohidratos activos.
- **Insulina** registrada por la persona, con su insulina activa.
- **Inicio e historial** con gráficas de Swift Charts, tiempo en rango, promedio y GMI.
- **Alta con consentimiento expreso**, ajustes, candado biométrico y modo oscuro.
- **Informe en PDF para el médico**, con los datos personales detrás de un interruptor apagado
  por omisión.

## Qué no hace, y es a propósito

- **No predice todavía.** El modelo es la fase 3; no hay ningún hueco que insinúe lo contrario.
- **No hay servidor.** La sincronización es la fase 2. Hoy el teléfono es el único dueño del
  dato y no sale nada de él.
- **Nunca calcula ni sugiere una dosis de insulina** ni gramos a tomar, y `scripts/regla-7.sh`
  lo comprueba como primer paso de la integración continua.
- **En modo sin sensor declara en pantalla que no puede anticipar hipoglucemias** (RF-10b).

## Cómo se comprobó

255 pruebas en 47 suites sobre `Domain`, en verde en la integración continua.

**Las pruebas de interfaz no corren en la integración continua**: se queda en
`-only-testing:GlucyTests` sobre el simulador, porque un simulador en un runner compartido ya
costó una tarde de corridas colgadas. Se corrieron **a mano contra un iPhone 17 el 13 de
octubre de 2026** con `scripts/pruebas-en-el-iphone.sh`: 17 pruebas de interfaz, 33 capturas con
la letra normal y 65 con la de accesibilidad más grande. Arranque en frío medido: **1.11 s** de
promedio en tres corridas, contra un presupuesto de 2 s.

De la lista de comprobación del apartado 9 de `docs/paso-10-cierre.md` quedaron **12 casillas
marcadas de 24**.

## Lo que NO quedó comprobado

Se dice en lugar de dejarlo en blanco:

- **P-14, que la serie del sensor no se duplique al reiniciar.** Es la que tiene la peor
  consecuencia si falla y **no se pudo comprobar porque no hay sensor**. La protección existe en
  el código (`HKSource` distingue lo propio de lo del fabricante y la lectura se guarda con el
  UUID que le dio HealthKit), pero no está vista en el teléfono.
- El permiso de Salud se negó **antes** de abrir la app, no revocándolo con la app ya abierta.
- De la franja del sensor se vio «todavía no llegan datos», no la variante que dice desde qué
  hora dejó de escribir.
- **Audio Graphs** y el **orden de lectura de VoiceOver** se quedaron sin comprobar: son de
  oído.
- El texto truncado con la letra más grande, la revisión en escala de grises y el PDF visto en
  Archivos y en Correo se quedaron a ojo, en la galería de capturas.

## Aviso

Glucy **no es un dispositivo médico certificado** y no debe usarse como única fuente para una
decisión terapéutica. Informa; no prescribe ni administra.
