# Ver los factores y la explicación en el iPhone, con el servidor en la Mac

El número de la predicción lo calcula el teléfono con Core ML y no necesita nada más (C-16).
**Los cinco factores y la frase vienen del servidor**, así que para verlos en un teléfono de
verdad hacen falta tres cosas: el backend corriendo en la Mac, el iPhone en la misma wifi, y
la app sabiendo a qué dirección hablarle.

Esto no es el despliegue de la entrega. Es el camino corto para probar en casa.

---

## 1. El servidor, en la Mac

```bash
cd ~/glucy-backend
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt

cat > .env <<'EOF'
GLUCY_DATABASE_URL=sqlite:///./glucy.db
GLUCY_JWT_SECRET=una-cadena-larga-cualquiera-solo-para-esta-prueba
GLUCY_JWT_MINUTOS_VIGENCIA=1440
GLUCY_RUTA_ARTEFACTO_MODELO=../glucy-ml/artifacts
EOF

alembic upgrade head
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

Tres cosas de ese bloque que importan:

- **SQLite basta** (D-4). PostgreSQL con TimescaleDB es para cuando haya volumen, y levantarlo
  con Docker para una prueba de tarde no aporta nada.
- `--host 0.0.0.0` es lo que hace que el servidor conteste a **otros** aparatos de la wifi. Sin
  eso solo contesta a la propia Mac y el teléfono recibe «connection refused».
- **La vigencia del token a 1440 minutos.** Por omisión son 15, que es lo correcto en
  producción y una molestia aquí: el token se vencería antes de que acabes de teclear glucosas
  en Salud. Es un valor para esta prueba y no para el servidor de la entrega.
- `GLUCY_RUTA_ARTEFACTO_MODELO` apunta a los artefactos de `glucy-ml`. **Sin modelo cargado no
  hay factores ni explicación**: el servidor contesta que no tiene con qué predecir. Ajusta la
  ruta a donde tengas clonado ese repositorio.

Comprueba que el servidor está de pie desde la propia Mac:

```bash
curl -s http://localhost:8000/docs -o /dev/null -w '%{http_code}\n'   # 200
```

## 2. La dirección, en Xcode

En Xcode: **TARGETS → Glucy → Build Settings**, busca `GlucyBackendURL` y pon la dirección de
la Mac en la configuración **Debug**:

```
http://<el-nombre-de-tu-Mac>.local:8000
```

El nombre lo da `scutil --get LocalHostName` en la terminal; suele ser algo como
`MacBook-Air-de-Jesus`, y entonces la dirección es `http://MacBook-Air-de-Jesus.local:8000`.

**Usa el nombre `.local` y no la dirección numérica.** La numérica cambia cada vez que el
router reparte direcciones, y el día que cambie la app dejará de hablar con el servidor sin
decir por qué. Si de todos modos quieres la numérica, está en Ajustes del sistema → Wi-Fi →
Detalles.

La app acepta `http://` **solo en Debug**: `Glucy/InfoDebug.plist` abre App Transport Security
para la red local y nada más. En Release sigue exigiendo TLS, que es lo que dice el documento
de seguridad.

## 3. El token, en la app

El backend **no tiene ningún endpoint que emita tokens**: eso es de la fase 2. Mientras tanto
se firma uno a mano y se pega en la app.

En la Mac, con el entorno activado:

```bash
python scripts/token-de-prueba.py $(python -c "import uuid; print(uuid.uuid4())")
```

Guarda el UUID que salga de ahí si quieres volver a firmar un token para el mismo usuario; el
servidor identifica a la persona por ese UUID y nada más. Copia el token que imprime.

En el iPhone: **Ajustes → Sincronizar mis registros → Token del servidor**, pegas, «Guardar el
token». El token va al Keychain y la app no lo vuelve a enseñar: solo dice que lo hay.

## 4. El orden en que aparecen las cosas

1. Teclea glucosa en la app **Salud** (no en Glucy) a 25, 20, 15, 10, 5 y 2 minutos hacia
   atrás. Eso deja la app en modo sensor por quince minutos y es lo único que hace que aparezca
   el número estimado.
2. En Glucy, **Ajustes → Sincronizar ahora**. Ahí suben las lecturas, y hasta que suben el
   servidor no tiene con qué predecir.
3. Vuelve a **Inicio**. El número estimado ya estaba; la frase aparece debajo cuando llega la
   respuesta del servidor, uno a tres segundos después. Toca la estimación para ver la pantalla
   de factores con los cinco.

Si la frase no aparece, la pantalla de factores dice en una línea por qué, y «Sincronizar
ahora» dice si el servidor contestó y con qué. Un 401 es el token vencido o mal pegado.

## 5. Ollama con Qwen3 no hace falta

Sin el modelo de lenguaje encendido, el servidor arma la frase con **la plantilla
determinista**, con los mismos valores SHAP. Es una frase completa y es, además, la que el
reporte promete que funciona con todo lo demás apagado (P-13). La pantalla de factores dice
cuál de las dos estás leyendo, porque no valen lo mismo.

## 6. Lo que esto no es

Una copia local con SQLite, un token firmado a mano y `http://` en la red de tu casa sirven
para ver la función con tus propios datos. **No es el despliegue de la entrega**, que lleva
PostgreSQL con TimescaleDB, TLS 1.3, tokens de corta vigencia con rotación y el panel detrás de
autenticación.
