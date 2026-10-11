#!/bin/bash
# La regla 7 comprobada sobre el código: Glucy registra la insulina que la persona dice
# haberse aplicado y nunca calcula ni sugiere una dosis.
#
# Es la prueba 23 del paso 7 y el `grep` de su apartado 9. No vive en GlucyTests porque no
# ejecuta nada: lee el código fuente, y una prueba que corre dentro del simulador no tiene
# por qué poder leer la carpeta del repositorio.
#
# Uso: ./scripts/regla-7.sh   (desde cualquier carpeta; sale con 1 si algo no cuadra)
set -uo pipefail
cd "$(dirname "$0")/.."

fallo=0

reportar() {
    echo "✘ $1"
    echo "$2" | sed 's/^/    /'
    fallo=1
}

# 1. La fila de una dosis solo la crea el repositorio, a partir del valor que le entregan.
fuera=$(grep -rnE --include='*.swift' '(^|[^A-Za-z0-9_])DosisInsulina\(' Glucy \
    | grep -v '^Glucy/Data/SwiftData/DosisSwiftData.swift:')
[ -n "$fuera" ] && reportar "Se crea una DosisInsulina fuera de DosisSwiftData:" "$fuera"

# 2. Y ese valor solo lo arma RegistrarDosis. El otro sitio es la conversión de vuelta, de
#    una fila que ya existe.
fuera=$(grep -rnE --include='*.swift' '(^|[^A-Za-z0-9_])DosisInsulinaDato\(' Glucy \
    | grep -v -e '^Glucy/Domain/UseCases/RegistrarDosis.swift:' \
              -e '^Glucy/Domain/Models/DosisInsulina.swift:')
[ -n "$fuera" ] && reportar "Se arma una DosisInsulinaDato fuera de RegistrarDosis:" "$fuera"

# 3. Ni las dos entradas de un calculador de bolo ni una función que devuelva unidades. Las
#    dos primeras se buscan como palabra entera porque «ratio» también está dentro de
#    «Configuration» y de «aspectRatio», que no tienen nada que ver.
prohibido=$(
    grep -rnwiE --include='*.swift' 'ratio|sensibilidad' Glucy
    grep -rnE --include='*.swift' \
        'ratio(De|Carb|Insul)|[Ss]ensibilidad|[Ff]actor(De)?(Correccion|Sensibilidad)|(calcular|sugerir|recomendar)(Dosis|Bolo|Unidades)' \
        Glucy
)
[ -n "$prohibido" ] && reportar "Hay nombres de un calculador de bolo en el código:" "$prohibido"

if [ "$fallo" -eq 0 ]; then
    echo "✔ Regla 7: la única puerta a una dosis es RegistrarDosis, y nada calcula ni sugiere unidades."
fi
exit "$fallo"
