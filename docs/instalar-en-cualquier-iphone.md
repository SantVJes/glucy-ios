# Glucy en cualquier iPhone: en cuáles corre y cómo se instala en uno que no es el tuyo

Escrito el 24 de noviembre de 2026.

## En qué iPhone corre

**iOS 17.0 o posterior.** Eso es el iPhone XS, XS Max y XR (2018) en adelante, más el iPhone SE
de segunda y tercera generación. Quedan fuera el iPhone X, el 8 y anteriores, porque no pasan
de iOS 16.

No se puede bajar más: SwiftData y la macro `@Observable`, que son la base local y el estado
de todas las pantallas, existen desde iOS 17. Bajar el mínimo obligaría a reescribir la capa
de datos con Core Data y cada ViewModel con `ObservableObject`, para ganar dos modelos de
teléfono de 2017.

| Ajuste | Valor | Por qué |
| --- | --- | --- |
| `IPHONEOS_DEPLOYMENT_TARGET` | 17.0 | SwiftData y `@Observable` |
| `TARGETED_DEVICE_FAMILY` | 1 (solo iPhone) | la app se diseñó para una mano y una cifra por pantalla. Un iPad la abre igual, en modo compatibilidad, pero no se ofrece una interfaz de iPad que nadie diseñó ni revisó. Con «1,2» App Store Connect exigiría capturas de iPad y la revisión probaría la app en uno |
| Arquitecturas | las estándar (`arm64`) | todos los iPhone con iOS 17 son de 64 bits; no hay nada que ajustar |
| Orientación | vertical y horizontal | se deja horizontal porque hay quien fija el teléfono de lado por accesibilidad; las pantallas usan `ScrollView` y se acomodan |
| `ITSAppUsesNonExemptEncryption` | NO | Glucy solo cifra con lo que trae iOS (HTTPS y el Keychain), que está exento. Sin esta clave TestFlight hace la pregunta de exportación en cada compilación que subes |
| Icono | `Assets.xcassets/AppIcon` | claro, oscuro y tintado. Sin icono, App Store Connect rechaza la compilación al subirla |

**Pantallas chicas y letra grande.** Las cifras grandes escalan con `@ScaledMetric`, todo el
texto usa estilos relativos o `fixedSize(horizontal: false, vertical: true)` para crecer hacia
abajo en lugar de cortarse, y con tamaños de accesibilidad la cifra y su unidad pasan a dos
renglones (P-15). Antes de una demostración conviene abrir el simulador más chico que traiga
tu Xcode (iPhone SE o 16e) con *Ajustes → Accesibilidad → Pantalla y tamaño del texto → Texto
más grande* al máximo y recorrer las cuatro pestañas.

## Lo que depende de la cuenta de Apple

Tu cuenta es **personal (gratuita)**, equipo `428L48JNT7`. Con ella:

- Instalas desde Xcode **en tus propios dispositivos**, hasta tres a la vez.
- **La instalación caduca a los 7 días**: la app deja de abrir y hay que volver a correrla
  desde Xcode. Los datos se conservan si no la borras.
- **No hay avisos con prioridad de tiempo**: un Modo de Concentración, por ejemplo «Sueño»,
  puede callar el aviso de baja prevista. Está en
  `docs/limitacion-del-aviso-con-prioridad-de-tiempo.md`.
- **No puedes instalarla en el iPhone de otra persona** salvo conectándolo a tu Mac y que
  cuente como uno de tus tres dispositivos, con la misma caducidad de 7 días.

Para que otras personas la tengan hace falta el **Apple Developer Program** (99 USD al año).
Con él hay dos caminos; los dos son tuyos de hacer, porque piden tu cuenta y tu firma.

### Opción 1: TestFlight (la recomendada para el curso)

1. Inscríbete en el programa y espera la aprobación (de horas a un par de días).
2. En Xcode, *Signing & Capabilities*, cambia el equipo al de pago. **Si Xcode dice que
   `Freelancer.Glucy` ya está registrado**, cámbialo por un identificador de dominio invertido
   tuyo (por ejemplo `com.<tu-usuario>.glucy`) en el target Glucy y, con el mismo prefijo, en
   los dos de pruebas.
3. Ahí mismo puedes agregar **Time Sensitive Notifications**: el código ya pide
   `.timeSensitive`, no hay que tocar Swift.
4. En App Store Connect crea la app con ese identificador.
5. En Xcode: destino *Any iOS Device (arm64)* → *Product → Archive* → *Distribute App →
   App Store Connect → Upload*.
6. En App Store Connect, pestaña TestFlight:
   - **Probadores internos** (hasta 100, deben estar en tu equipo de App Store Connect): la
     ven en minutos, sin revisión.
   - **Probadores externos** (hasta 10 000, solo con su correo o un enlace público): la
     primera compilación pasa una **revisión beta de Apple** de uno a dos días. Pide una
     descripción, un correo de contacto y notas para el revisor. Di ahí que es un proyecto
     académico, que no calcula dosis y que el modo sensor se prueba metiendo glucosa a mano en
     la app Salud.
7. Cada persona instala **TestFlight** desde el App Store y acepta la invitación. La
   compilación dura **90 días**.

Es lo más cómodo para el profesor y los compañeros: no te piden nada de su teléfono y se
actualiza sola cuando subes otra compilación.

### Opción 2: Ad Hoc

1. Pide a cada persona el **UDID** de su iPhone (se ve conectándolo al Mac, en Finder).
2. Regístralo en *Certificates, Identifiers & Profiles → Devices* (hasta 100 iPhone al año).
3. *Product → Archive → Distribute App → Release Testing* (antes «Ad Hoc») y exporta el `.ipa`.
4. Instálalo conectando el teléfono a tu Mac (Finder o *Devices and Simulators* en Xcode), o
   súbelo a un servicio de distribución.

Sirve sin revisión de Apple, pero cada teléfono nuevo es una compilación nueva. Para un grupo
de clase TestFlight da menos trabajo.

### Lo que no sirve

- Mandar el `.ipa` sin más: iOS no instala nada que no esté firmado para ese teléfono.
- El programa **Enterprise**: es para empleados de una empresa, no para un curso.

## Antes de dárselo a alguien

- **El servidor**: si la persona no está en tu red, la explicación y los factores no llegan y
  la app lo dice; registrar, ver la curva y la estimación con Core ML funcionan igual, porque
  el número se calcula en el teléfono (C-16). Ver `docs/servidor-en-la-red-local.md`.
- **Sus datos**: en el piloto de usabilidad nadie teclea sus cifras reales (C-17, en
  `docs/fase7-piloto-de-usabilidad.md`).
- **El aviso**: Glucy no es un dispositivo médico certificado y no debe usarse como única
  fuente para una decisión terapéutica. Informa; no prescribe ni administra.
