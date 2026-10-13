#!/bin/bash
# Las pruebas del apartado 9 de docs/paso-10-cierre.md, corridas en el iPhone conectado.
#
# No es parte de la integración continua, que sigue siendo GlucyTests en el simulador: esto
# necesita un teléfono y una persona que encienda el modo avión. Se corre a mano antes de
# etiquetar una versión. No fusiona nada, no etiqueta nada y no toca git: corre pruebas,
# saca las capturas y escribe un resumen.
#
# Uso:
#   ./scripts/pruebas-en-el-iphone.sh              todo, pidiendo cada estado a su turno
#   ./scripts/pruebas-en-el-iphone.sh <bloque>...  solo esos bloques
#
# Bloques: dominio interfaz capturas avion movimiento salud-revocada sensor-callado
#          salud-con-datos galeria resumen
#
# Variables:
#   GLUCY_DISPOSITIVO   el identificador del iPhone, si hay más de uno conectado
#   GLUCY_RESPUESTA     «si» o «saltar», para contestar sin teclado a los bloques con estado
#   GLUCY_SALIDA        dónde dejar resultados y capturas (por omisión, salida/ en el repo)
set -uo pipefail
cd "$(dirname "$0")/.."

SALIDA="${GLUCY_SALIDA:-$PWD/salida/pruebas-en-el-iphone}"
RESULTADOS="$SALIDA/resultados.tsv"
# Lo compilado va fuera del repositorio: dentro de Documentos, macOS le pone a los archivos
# atributos que hacen fallar la firma del paquete de pruebas.
DERIVADOS="$HOME/Library/Caches/glucy-pruebas-en-el-iphone/DerivedData"
mkdir -p "$SALIDA"

TODOS="dominio interfaz capturas avion movimiento salud-revocada sensor-callado salud-con-datos galeria resumen"
BLOQUES="${*:-$TODOS}"

# ---------------------------------------------------------------------------- el teléfono

# El iPhone físico conectado. Si hay más de uno o ninguno, se para y se dice: el script nunca
# elige por su cuenta en qué teléfono correr.
encontrar_iphone() {
    local lista="$SALIDA/dispositivos.json"
    xcrun devicectl list devices --json-output "$lista" >/dev/null 2>&1
    python3 - "$lista" "${GLUCY_DISPOSITIVO:-}" <<'PY'
import json, sys
try:
    equipos = json.load(open(sys.argv[1]))["result"]["devices"]
except Exception:
    sys.exit("No pude listar los dispositivos con «xcrun devicectl list devices».")
pedido = sys.argv[2]
fisicos = []
for e in equipos:
    hw, props = e.get("hardwareProperties", {}), e.get("deviceProperties", {})
    if hw.get("reality") != "physical" or hw.get("platform") != "iOS":
        continue
    if e.get("connectionProperties", {}).get("pairingState") != "paired":
        continue
    fisicos.append((hw.get("udid", ""), props.get("name", "?"), hw.get("marketingName", "?"), props.get("osVersionNumber", "?")))
if pedido:
    fisicos = [f for f in fisicos if f[0] == pedido]
if not fisicos:
    sys.exit("No encontré ningún iPhone conectado y emparejado. Conéctalo por cable y desbloquéalo.")
if len(fisicos) > 1:
    lista = "\n".join(f"  {f[1]} · {f[2]} · iOS {f[3]} · {f[0]}" for f in fisicos)
    sys.exit("Hay más de un iPhone conectado. Elige uno con GLUCY_DISPOSITIVO=<identificador>:\n" + lista)
print("\t".join(fisicos[0]))
PY
}

IPHONE="$(encontrar_iphone)" || { echo "$IPHONE"; exit 1; }
IFS=$'\t' read -r DISPOSITIVO NOMBRE MODELO VERSION <<<"$IPHONE"
echo "iPhone encontrado: «${NOMBRE}» · $MODELO · iOS $VERSION · $DISPOSITIVO"
echo "Resultados y capturas en: $SALIDA"

# ---------------------------------------------------------------------------- las corridas

anotar() {  # bloque, estado, detalle
    touch "$RESULTADOS"
    grep -v "^$1"$'\t' "$RESULTADOS" >"$RESULTADOS.tmp" 2>/dev/null || true
    mv "$RESULTADOS.tmp" "$RESULTADOS"
    printf '%s\t%s\t%s\n' "$1" "$2" "$3" >>"$RESULTADOS"
}

# Cuenta lo que pasó en un .xcresult y lista lo que falló o se saltó, con su motivo.
#
# Probado con Xcode 27.0 (27A266a), xcresulttool versión 25115:
#   xcrun xcresulttool get test-results summary --path <bundle>
#   xcrun xcresulttool get test-results tests   --path <bundle>
# Los parámetros cambian entre versiones de Xcode. Si esto deja de funcionar, la referencia
# es «xcrun xcresulttool get test-results --help», no la memoria.
leer_resultado() {  # ruta del .xcresult
    local resumen="$SALIDA/.resumen.json" pruebas="$SALIDA/.pruebas.json"
    xcrun xcresulttool get test-results summary --path "$1" >"$resumen" 2>/dev/null
    xcrun xcresulttool get test-results tests --path "$1" >"$pruebas" 2>/dev/null
    python3 - "$resumen" "$pruebas" <<'PY'
import json, sys
try:
    r = json.load(open(sys.argv[1]))
except Exception:
    print("sin-resultado\tno se generó el resultado de la corrida")
    sys.exit()
detalles = []
def recorrer(n):
    if n.get("nodeType") == "Test Case" and n.get("result") in ("Failed", "Skipped"):
        motivos = [h.get("name", "") for h in n.get("children", []) if h.get("nodeType") in ("Failure Message", "Skip Message")]
        marca = "✘" if n["result"] == "Failed" else "–"
        detalles.append(f"{marca} {n.get('name')}: {' '.join(motivos)[:300]}")
    for h in n.get("children", []):
        recorrer(h)
try:
    for n in json.load(open(sys.argv[2])).get("testNodes", []):
        recorrer(n)
except Exception:
    pass
pasaron, fallaron, saltadas = r.get("passedTests", 0), r.get("failedTests", 0), r.get("skippedTests", 0)
if pasaron + fallaron + saltadas == 0:
    # Ni una prueba: no compiló, no se pudo firmar o el teléfono estaba bloqueado.
    print("sin-resultado\tno corrió ninguna prueba: mira la bitácora")
    sys.exit()
estado = "fallo" if fallaron else ("saltada" if saltadas and not pasaron else "paso")
print(f"{estado}\t{pasaron} pasaron, {fallaron} fallaron, {saltadas} saltadas")
for d in detalles:
    print(f"\t{d}", file=sys.stderr)
PY
}

# Corre xcodebuild en el iPhone y anota el resultado del bloque. Las variables que empiezan
# por TEST_RUNNER_ llegan a las pruebas sin ese prefijo.
correr() {  # bloque, argumentos de xcodebuild...
    local bloque="$1"; shift
    local paquete="$SALIDA/$bloque.xcresult"
    rm -rf "$paquete"
    echo
    echo "── $bloque: corriendo en «${NOMBRE}» (deja el teléfono desbloqueado)…"
    xcodebuild -scheme Glucy -destination "platform=iOS,id=$DISPOSITIVO" \
        -derivedDataPath "$DERIVADOS" -parallel-testing-enabled NO \
        -resultBundlePath "$paquete" "$@" test >"$SALIDA/$bloque.log" 2>&1
    local salida=$? leido estado detalle
    leido="$(leer_resultado "$paquete")"
    estado="${leido%%$'\t'*}"; detalle="${leido#*$'\t'}"
    # Si xcodebuild terminó mal, el bloque no pasó, diga lo que diga el conteo.
    if [ "$salida" -ne 0 ] && [ "$estado" = "paso" ]; then estado="fallo"; fi
    anotar "$bloque" "$estado" "$detalle"
    echo "   $bloque: $estado · $detalle   (bitácora: $SALIDA/$bloque.log)"
}

# Anota aparte el resultado de una sola prueba de un bloque, para las casillas que comparten
# corrida pero no destino: una puede pasar y la otra saltarse.
anotar_prueba() {  # bloque nuevo, ruta del .xcresult, nombre de la prueba
    local leido
    xcrun xcresulttool get test-results tests --path "$2" >"$SALIDA/.pruebas.json" 2>/dev/null
    leido="$(python3 - "$SALIDA/.pruebas.json" "$3" <<'PY'
import json, sys
encontrada = None
def recorrer(n):
    global encontrada
    if n.get("nodeType") == "Test Case" and n.get("name", "").startswith(sys.argv[2]):
        motivos = [h.get("name", "") for h in n.get("children", []) if h.get("nodeType") in ("Failure Message", "Skip Message")]
        encontrada = (n.get("result"), " ".join(motivos)[:300])
    for h in n.get("children", []):
        recorrer(h)
try:
    for n in json.load(open(sys.argv[1])).get("testNodes", []):
        recorrer(n)
except Exception:
    pass
estado = {"Passed": "paso", "Failed": "fallo", "Skipped": "saltada"}.get(encontrada[0] if encontrada else "", "sin-resultado")
print(f"{estado}\t{encontrada[1] if encontrada and encontrada[1] else 'sin más detalle'}")
PY
)"
    anotar "$1" "${leido%%$'\t'*}" "${leido#*$'\t'}"
}

# Pide un estado del teléfono. Devuelve 1 si la persona prefiere saltarse el bloque.
pedir() {  # bloque, qué hay que poner
    local respuesta="${GLUCY_RESPUESTA:-}"
    if [ -z "$respuesta" ]; then
        echo
        printf '%s\n   Pulsa Enter cuando esté, o escribe s para saltarla: ' "$2"
        read -r respuesta </dev/tty
    fi
    case "$respuesta" in
        s|S|saltar) anotar "$1" "saltada" "la persona decidió no ponerla"; echo "   $1: saltada"; return 1 ;;
        *) return 0 ;;
    esac
}

# ---------------------------------------------------------------------------- los bloques

bloque_dominio() {
    # Las pruebas de dominio, incluidas las que leen el PDF de vuelta, en el teléfono.
    correr dominio -only-testing:GlucyTests
}

bloque_interfaz() {
    # Las de interfaz sin las de entorno ni las capturas. AccesibilidadUITests fuerza ella
    # misma la letra de accesibilidad más grande.
    correr interfaz -only-testing:GlucyUITests \
        -skip-testing:GlucyUITests/GlucyUITests \
        -skip-testing:GlucyUITests/CapturasUITests \
        -skip-testing:GlucyUITests/EntornoDelTelefonoUITests
}

bloque_capturas() {
    correr capturas-letra-normal -only-testing:GlucyUITests/CapturasUITests
    TEST_RUNNER_GLUCY_LETRA_GRANDE=1 correr capturas-letra-grande -only-testing:GlucyUITests/CapturasUITests
}

bloque_avion() {
    # No es el modo avión de verdad, y es a propósito: el modo avión corta también la
    # conexión de Xcode con el teléfono y la prueba se muere a media corrida. Se apagan el
    # wifi y los datos móviles, que para la app es lo mismo. Y no antes sino durante: para
    # abrir las pruebas iOS comprueba en línea el certificado de desarrollo. Cada prueba
    # arranca con red y espera hasta tres minutos a que se quite.
    pedir avion "Deja el teléfono CON red por ahora. Cuando la app de pruebas se abra, apaga el WIFI y los DATOS MÓVILES (no el modo avión: corta la conexión con Xcode). La prueba espera hasta 3 minutos. (La del código de barras le quita a Glucy el permiso de cámara y lo deja sin contestar.)" || return 0
    TEST_RUNNER_GLUCY_MODO_AVION=1 correr avion \
        -only-testing:GlucyUITests/EntornoDelTelefonoUITests/testEnModoAvionTodoSeGuardaYLaColaLoCuenta \
        -only-testing:GlucyUITests/EntornoDelTelefonoUITests/testEnModoAvionElCodigoDeBarrasBajaALaFotoYALoManual
    # Las dos casillas van en la misma corrida, pero cada una con su resultado.
    anotar_prueba avion "$SALIDA/avion.xcresult" testEnModoAvionTodoSeGuardaYLaColaLoCuenta
    anotar_prueba avion-codigo "$SALIDA/avion.xcresult" testEnModoAvionElCodigoDeBarrasBajaALaFotoYALoManual
    echo "   Ya puedes volver a encender el wifi y los datos móviles."
}

bloque_movimiento() {
    pedir movimiento "Enciende «Reducir movimiento» (Ajustes › Accesibilidad › Movimiento)." || return 0
    TEST_RUNNER_GLUCY_REDUCIR_MOVIMIENTO=1 correr movimiento \
        -only-testing:GlucyUITests/EntornoDelTelefonoUITests/testConReducirMovimientoElSplashSeRetira
    echo "   Ya puedes apagar «Reducir movimiento»."
}

bloque_salud_revocada() {
    pedir salud-revocada "En la app Salud › Compartir › Apps › Glucy, APAGA la lectura de glucosa." || return 0
    TEST_RUNNER_GLUCY_SALUD_REVOCADA=1 correr salud-revocada \
        -only-testing:GlucyUITests/EntornoDelTelefonoUITests/testConSaludRevocadaLaAppSigueEnModoSinSensor
}

bloque_sensor_callado() {
    pedir sensor-callado "Con la lectura de glucosa PERMITIDA en Salud, deja la app de tu sensor cerrada más de 15 minutos (o sin sensor: sin ninguna lectura suya en Salud)." || return 0
    TEST_RUNNER_GLUCY_SENSOR_CALLADO=1 correr sensor-callado \
        -only-testing:GlucyUITests/EntornoDelTelefonoUITests/testConElSensorCalladoSaleLaFranja
}

bloque_salud_con_datos() {
    pedir salud-con-datos "Hace falta tu Glucy de verdad con el alta hecha CON SENSOR, lecturas del sensor en Salud y alguna escrita por Glucy. Esta prueba abre tu base real, solo para leerla." || return 0
    TEST_RUNNER_GLUCY_SALUD_CON_DATOS=1 correr salud-con-datos \
        -only-testing:GlucyUITests/EntornoDelTelefonoUITests/testLaSerieNoSeDuplicaAlReiniciar
}

# Saca las capturas de los .xcresult a una carpeta y hace una copia en gris de cada una, para
# revisar la escala de grises sin depender de que el filtro de color del teléfono salga en la
# captura (no sale: el filtro se aplica después).
#
# Probado con Xcode 27.0 (27A266a), xcresulttool versión 25115:
#   xcrun xcresulttool export attachments --path <bundle> --output-path <carpeta>
# Deja los archivos con un nombre interno y un manifest.json que dice cómo se llamaba cada
# uno. Consultado en «xcrun xcresulttool export attachments --help».
bloque_galeria() {
    local galeria="$SALIDA/galeria"
    rm -rf "$galeria"
    for paquete in "$SALIDA"/*.xcresult; do
        [ -d "$paquete" ] || continue
        local nombre crudo destino
        nombre="$(basename "$paquete" .xcresult)"
        crudo="$SALIDA/.adjuntos-$nombre"
        destino="$galeria/$nombre"
        rm -rf "$crudo"; mkdir -p "$crudo"
        xcrun xcresulttool export attachments --path "$paquete" --output-path "$crudo" >/dev/null 2>&1 || continue
        python3 - "$crudo" "$destino" <<'PY'
import json, os, re, shutil, sys
crudo, destino = sys.argv[1], sys.argv[2]
try:
    manifiesto = json.load(open(os.path.join(crudo, "manifest.json")))
except Exception:
    sys.exit()
for prueba in manifiesto:
    for adjunto in prueba.get("attachments", []):
        archivo = adjunto.get("exportedFileName", "")
        if not archivo.lower().endswith(".png"):
            continue
        # «10-inicio_0_3F2A….png»: el nombre que le puso la prueba va antes del primer «_0_».
        legible = re.sub(r"_\d+_[0-9A-Fa-f-]{36}\.png$", "", adjunto.get("suggestedHumanReadableName", archivo))
        if legible.startswith("Screenshot"):
            continue   # las que Xcode toma solo al fallar una prueba
        os.makedirs(destino, exist_ok=True)
        shutil.copy(os.path.join(crudo, archivo), os.path.join(destino, legible + ".png"))
PY
        rm -rf "$crudo"
        [ -d "$destino" ] || continue
        mkdir -p "$destino/en-gris"
        for captura in "$destino"/*.png; do
            sips --matchTo "/System/Library/ColorSync/Profiles/Generic Gray Profile.icc" \
                "$captura" --out "$destino/en-gris/$(basename "$captura")" >/dev/null 2>&1
        done
        echo "   $(ls "$destino"/*.png | wc -l | tr -d ' ') capturas en $destino (y su copia en gris)"
    done
    [ -d "$galeria" ] && anotar galeria "paso" "$galeria" || anotar galeria "saltada" "no había capturas que sacar"
}

# Qué casillas del apartado 9 quedaron afirmadas, cuáles saltadas y cuáles siguen a ojo o a
# oído. Es lo que se pega en las notas del release.
bloque_resumen() {
    python3 - "$RESULTADOS" "$NOMBRE · $MODELO · iOS $VERSION" <<'PY'
import sys
estados = {}
try:
    for linea in open(sys.argv[1]):
        partes = linea.rstrip("\n").split("\t")
        if len(partes) == 3:
            estados[partes[0]] = (partes[1], partes[2])
except FileNotFoundError:
    pass
def de(*bloques):
    vistos = [estados.get(b, ("sin-correr", "no se corrió"))[0] for b in bloques]
    for malo in ("fallo", "sin-resultado", "sin-correr", "saltada"):
        if malo in vistos:
            return malo
    return "paso"
MARCA = {"paso": "✔ afirmada", "fallo": "✘ FALLÓ", "saltada": "– saltada", "sin-correr": "· sin correr", "sin-resultado": "✘ sin resultado"}
capturas = de("capturas-letra-normal", "capturas-letra-grande", "galeria")
REVISAR = {"paso": "◻ en la galería, por revisar"}
casillas = [
    (1, "Las diez pantallas con la letra más grande: todo se alcanza", MARCA.get(de("interfaz"))),
    (2, "Registrar una glucosa con esa letra", MARCA.get(de("interfaz"))),
    (3, "La cifra de Inicio y su unidad no se enciman", REVISAR.get(capturas, MARCA.get(capturas))),
    (4, "Nada truncado con puntos suspensivos", REVISAR.get(capturas, MARCA.get(capturas))),
    (5, "Las ocho filas del color, entendibles en gris", REVISAR.get(capturas, MARCA.get(capturas))),
    (6, "La gráfica con sensor: continua contra punteada", "◻ a ojo: hace falta un sensor escribiendo en Salud"),
    (7, "La gráfica sin sensor: los de fuera de escala son triángulos", REVISAR.get(capturas, MARCA.get(capturas))),
    (8, "Inicio lee el valor con su unidad y su antigüedad", (MARCA.get(de("interfaz")) or "") + " (el contenido); el ORDEN, a oído"),
    (9, "Historial lee las tres cifras con su unidad y su n", MARCA.get(de("interfaz"))),
    (10, "Las dos gráficas tienen descripción", MARCA.get(de("interfaz"))),
    (11, "Audio Graphs suena en las dos", "◻ a oído"),
    (12, "El alta completa con VoiceOver", (MARCA.get(de("interfaz")) or "") + " (ningún control sin etiqueta); completarla, a oído"),
    (13, "Con «reducir movimiento», el splash desaparece", (MARCA.get(de("movimiento")) or "") + " (arranca y se retira); que no se desvanezca, a ojo"),
    (14, "Modo avión: glucosa, comida y dosis se guardan y la cola las cuenta", MARCA.get(de("avion"))),
    (15, "Modo avión: el código de barras baja a la foto y a lo manual", MARCA.get(de("avion-codigo"))),
    (16, "El PDF sin el interruptor no trae nombre ni peso", MARCA.get(de("dominio"))),
    (17, "El PDF con el interruptor sí los trae", MARCA.get(de("dominio"))),
    (18, "El PDF se ve bien en Archivos y Correo", "◻ a ojo"),
    (19, "Revocar Salud no tumba la app (P-09)", MARCA.get(de("salud-revocada"))),
    (20, "La serie no se duplica tras reiniciar (P-14)", MARCA.get(de("salud-con-datos"))),
    (21, "Con el sensor callado sale la franja", MARCA.get(de("sensor-callado"))),
]
print()
print("══ Las casillas del apartado 9 ══  " + sys.argv[2])
for numero, texto, estado in casillas:
    print(f"{numero:>3}. {estado:<28} {texto}" if len(estado) <= 28 else f"{numero:>3}. {texto}\n       {estado}")
print()
print("══ Los bloques ══")
for bloque, (estado, detalle) in estados.items():
    print(f"  {bloque:<24} {estado:<10} {detalle}")
PY
}

# ---------------------------------------------------------------------------- en marcha

if [ -z "${GLUCY_RESPUESTA:-}" ] && [ "$BLOQUES" = "$TODOS" ]; then
    echo
    echo "VoiceOver tiene que estar APAGADO: con él encendido las pruebas no pueden tocar nada."
    printf 'Pulsa Enter para empezar: '
    read -r _ </dev/tty
fi

for bloque in $BLOQUES; do
    case "$bloque" in
        dominio) bloque_dominio ;;
        interfaz) bloque_interfaz ;;
        capturas) bloque_capturas ;;
        avion) bloque_avion ;;
        movimiento) bloque_movimiento ;;
        salud-revocada) bloque_salud_revocada ;;
        sensor-callado) bloque_sensor_callado ;;
        salud-con-datos) bloque_salud_con_datos ;;
        galeria) bloque_galeria ;;
        resumen) bloque_resumen ;;
        *) echo "No conozco el bloque «${bloque}». Los que hay: $TODOS"; exit 2 ;;
    esac
done
