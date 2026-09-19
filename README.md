# glucy-ios

> **Glucy — «Tu glucosa, media hora antes».**
> Sistema que registra glucosa por tres vías intercambiables, la predice a 30 y 60 minutos con
> un modelo de aprendizaje automático y explica cada predicción en español llano.
> Proyecto académico de la Universidad Tecmilenio, 8.º semestre, materia Desarrollo de
> Proyectos de Aplicaciones Móviles. Autor: Jesús Santiago Velasco.

**Qué hace este repositorio:** la aplicación iOS nativa. SwiftUI, SwiftData, HealthKit, Vision y Core ML. Es un producto completo por sí sola: registra, grafica y calcula indicadores **sin backend, sin servidor y sin sensor**.

Los otros dos: [glucy-ios](https://github.com/SantVJes/glucy-ios) ·
[glucy-backend](https://github.com/SantVJes/glucy-backend) ·
[glucy-ml](https://github.com/SantVJes/glucy-ml-)


## Cómo levantarlo

**Requisitos:** macOS con **Xcode 16**, un iPhone con **iOS 17.0** o superior, y una cuenta de
desarrollador de Apple para instalar en dispositivo físico.

```bash
git clone https://github.com/SantVJes/glucy-ios.git
cd glucy-ios
open Glucy.xcodeproj    # a partir de la fase 1
```

HealthKit en segundo plano, las notificaciones, la cámara y Vision **solo se validan en el
iPhone físico**: el simulador no los reproduce bien.

## Variables de entorno

Esta aplicación no usa archivo de configuración con secretos. **Ninguna llave ni token vive en
el código**: lo que haya va al **Keychain** del dispositivo, nunca a `UserDefaults`.

## Cómo correr las pruebas

```bash
xcodebuild -scheme Glucy -destination 'platform=iOS Simulator,name=iPhone 17' test
xcodebuild -scheme Glucy -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:GlucyAppTests test     # solo dominio, que son las rápidas
```

## Estructura de carpetas

| Carpeta | Qué contiene |
| --- | --- |
| `GlucyApp/App/` | punto de entrada, contenedor de dependencias y `Theme` |
| `GlucyApp/Domain/` | modelos, enums, casos de uso y **las reglas clínicas** |
| `GlucyApp/Data/` | repositorios, SwiftData, HealthKit, OCR, red y sincronización |
| `GlucyApp/Features/` | una carpeta por pantalla, con su vista y su modelo de vista |
| `GlucyApp/Resources/` | recursos, textos en es-MX y el modelo Core ML |
| `GlucyAppTests/` | pruebas de dominio, las que importan |
| `GlucyAppUITests/` | recorridos con XCUITest |
| `docs/` | arquitectura, base de datos, modelos, pruebas y privacidad |
| [`docs/paso-1-dominio-y-reglas.md`](docs/paso-1-dominio-y-reglas.md) | instrucciones concretas del primer paso de la fase 1: crear el proyecto en Xcode, los enums, los diez modelos, las reglas clínicas y sus pruebas |

La API está documentada en [glucy-backend/docs/api.md](https://github.com/SantVJes/glucy-backend/blob/main/docs/api.md).

## Estado

Fase 0 terminada: repositorio con su estructura, su `CLAUDE.md`, su integración continua y su
documentación base. **La construcción empieza en la fase 1.** El plan completo, con las siete
fases repartidas hasta finales de noviembre de 2026, está en la base de documentación del
proyecto.

## Aviso

**Glucy no es un dispositivo médico certificado.** El sistema informa; nunca prescribe ni
administra, y **jamás calcula ni sugiere una dosis de insulina**. No debe usarse como única
fuente para una decisión terapéutica. Ante cualquier síntoma hay que medir, prediga lo que
prediga la aplicación.

## Licencia y cómo citar

Licencia MIT, ver [LICENSE](LICENSE). Todo el stack del proyecto es software libre y gratuito.

> Santiago Velasco, J. (2026). *Glucy: aplicación iOS de monitoreo y predicción de glucosa con
> aprendizaje automático e inteligencia artificial generativa* [software]. Universidad
> Tecmilenio.
