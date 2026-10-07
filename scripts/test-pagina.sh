#!/usr/bin/env bash
# Verifica el contrato HTTP de la version de salto de pagina (sin JS):
#
#   GET  /                                    200
#   POST /tasks           text=...            302 (400 si text falta/vacio)
#   POST /toggle_task      id=...             302 (404 si id no existe)
#   POST /delete_task      id=...             302 (404 si id no existe)
#   POST /move_task    id=...&position=...    302 (404 si id no existe)
#
# Y las convenciones minimas de HTML exigidas en el enunciado:
#   - cada formulario de accion lleva <input type="hidden" name="id" value="...">
#   - el contenedor de cada tarea lleva data-id="..." data-done="true|false"
#     (en ese orden, como atributos contiguos del mismo elemento).
#
# Uso: ./test-pagina.sh [URL_BASE]
#   URL_BASE por defecto: http://localhost:7070

set -u
BASE_URL="${1:-http://localhost:7070}"
PASS=0
FAIL=0
TMPFILE=$(mktemp)
trap 'rm -f "$TMPFILE"' EXIT

get() { curl -s -o "$TMPFILE" -w "%{http_code}" "$BASE_URL$1"; }
post() { curl -s -o "$TMPFILE" -w "%{http_code}" -X POST -d "$2" "$BASE_URL$1"; }
body() { cat "$TMPFILE"; }

check_status() {
  local label="$1" expected="$2" actual="$3"
  if [ "$actual" = "$expected" ]; then
    echo "PASS  $label"
    PASS=$((PASS + 1))
  else
    echo "FAIL  $label (esperado HTTP $expected, obtenido $actual)"
    FAIL=$((FAIL + 1))
    echo ""
    echo "Resultado: $PASS ok, $FAIL fallos"
    exit 1
  fi
}

check_contains() {
  local label="$1" pattern="$2" text="$3"
  if echo "$text" | grep -qF "$pattern"; then
    echo "PASS  $label"
    PASS=$((PASS + 1))
  else
    echo "FAIL  $label (no se encontro: $pattern)"
    FAIL=$((FAIL + 1))
    echo ""
    echo "Resultado: $PASS ok, $FAIL fallos"
    exit 1
  fi
}

check_not_contains() {
  local label="$1" pattern="$2" text="$3"
  if ! echo "$text" | grep -qF "$pattern"; then
    echo "PASS  $label"
    PASS=$((PASS + 1))
  else
    echo "FAIL  $label (se encontro '$pattern' y no deberia estar)"
    FAIL=$((FAIL + 1))
    echo ""
    echo "Resultado: $PASS ok, $FAIL fallos"
    exit 1
  fi
}

# Extrae los ids de tarea leyendo el atributo data-id del contenedor de
# cada tarea. El enunciado exige que ese contenedor lleve data-id="...",
# asi que sirve para cualquier implementacion.
get_ids() {
  curl -s "$BASE_URL/" |
    grep -o 'data-id="[^"]*"' |
    sed 's/data-id="\([^"]*\)"/\1/' |
    awk '!seen[$0]++'
}

# Comprueba que el contenedor de la tarea $1 tiene data-done="$2".
check_done() {
  local id="$1" expected="$2" label="$3"
  local page="$4"
  check_contains "$label" "data-id=\"$id\" data-done=\"$expected\"" "$page"
}

# Permite escribir "goto etiqueta" para saltar directamente a la marca
# ":etiqueta" de este mismo fichero (por ejemplo ":end"), ejecutando solo
# lo que hay a partir de ahi, incluido el resumen final. Sirve para poder
# lanzar el script aunque todavia no hayas implementado el resto de los
# pasos: mueve la linea "goto end" hacia abajo segun vayas avanzando.
goto() {
  local rest
  rest=$(sed -n "/^:$1\$/,\$p" "$0" | tail -n +2)
  eval "$rest"
  exit
}

echo "=== Test version de salto de pagina: $BASE_URL ==="
echo ""

# ── 1. GET / ──────────────────────────────────────────────────────────────
STATUS=$(get /)
check_status "GET / devuelve 200" "200" "$STATUS"

# Según vayas avanzando en el desarrollo, puedes mover
# esta línea hacia abajo para incluir más tests.
goto end

# ── 2. POST /tasks – crear Tarea A ───────────────────────────────────────
STATUS=$(post /tasks 'text=Tarea A')
check_status "POST /tasks (crear Tarea A) -> 302" "302" "$STATUS"
PAGE=$(curl -s "$BASE_URL/")
check_contains "Tarea A aparece en la pagina tras crearla" "Tarea A" "$PAGE"

ID_A=$(get_ids | sed -n '1p')
if [ -z "$ID_A" ]; then
  echo "FAIL  No se pudo extraer el id de Tarea A (revisa que el contenedor"
  echo "      de cada tarea lleve data-id=\"...\" data-done=\"true|false\")"
  echo ""
  echo "Resultado: $PASS ok, $((FAIL + 1)) fallos"
  exit 1
fi
check_done "$ID_A" "false" "Tarea A tiene data-done=\"false\" al crearla" "$PAGE"

# ── 3. POST /tasks – crear Tarea B ───────────────────────────────────────
STATUS=$(post /tasks 'text=Tarea B')
check_status "POST /tasks (crear Tarea B) -> 302" "302" "$STATUS"
PAGE=$(curl -s "$BASE_URL/")
check_contains "Tarea B aparece en la pagina" "Tarea B" "$PAGE"

# Primer id creado = Tarea A, segundo = Tarea B
ID_B=$(get_ids | sed -n '2p')

if [ -z "$ID_B" ]; then
  echo "FAIL  No se pudo extraer el id de Tarea B"
  echo ""
  echo "Resultado: $PASS ok, $((FAIL + 1)) fallos"
  exit 1
fi

# ── 4. POST /tasks – text vacio o ausente -> 400 ─────────────────────────
STATUS=$(post /tasks '')
check_status "POST /tasks (sin text) -> 400" "400" "$STATUS"

STATUS=$(post /tasks 'text=')
check_status "POST /tasks (text vacio) -> 400" "400" "$STATUS"

# ── 5. POST /toggle_task – marcar Tarea A como hecha ─────────────────────
STATUS=$(post /toggle_task "id=$ID_A")
check_status "POST /toggle_task Tarea A -> 302" "302" "$STATUS"
PAGE=$(curl -s "$BASE_URL/")
check_done "$ID_A" "true" "Tarea A tiene data-done=\"true\" tras marcarla" "$PAGE"

# ── 6. POST /toggle_task – desmarcar Tarea A ──────────────────────────────
STATUS=$(post /toggle_task "id=$ID_A")
check_status "POST /toggle_task Tarea A otra vez -> 302" "302" "$STATUS"
PAGE=$(curl -s "$BASE_URL/")
check_done "$ID_A" "false" "Tarea A tiene data-done=\"false\" tras desmarcarla" "$PAGE"
check_contains "Tarea A sigue en la pagina" "Tarea A" "$PAGE"

# ── 7. POST /toggle_task – id desconocido -> 404 ─────────────────────────
STATUS=$(post /toggle_task "id=00000000-0000-0000-0000-000000000000")
check_status "POST /toggle_task id desconocido -> 404" "404" "$STATUS"

# ── 8. POST /move_task – mover Tarea B a la posicion 0 ────────────────────
STATUS=$(post /move_task "id=$ID_B&position=0")
check_status "POST /move_task Tarea B a posicion 0 -> 302" "302" "$STATUS"
PAGE=$(curl -s "$BASE_URL/")
POS_B=$(echo "$PAGE" | grep -n "Tarea B" | head -1 | cut -d: -f1)
POS_A=$(echo "$PAGE" | grep -n "Tarea A" | head -1 | cut -d: -f1)
if [ -n "$POS_B" ] && [ -n "$POS_A" ] && [ "$POS_B" -lt "$POS_A" ]; then
  echo "PASS  Tarea B aparece antes que Tarea A tras moverla"
  PASS=$((PASS + 1))
else
  echo "FAIL  Tarea B deberia aparecer antes que Tarea A tras moverla"
  FAIL=$((FAIL + 1))
  echo ""
  echo "Resultado: $PASS ok, $FAIL fallos"
  exit 1
fi

# ── 9. POST /move_task – id desconocido -> 404 ───────────────────────────
STATUS=$(post /move_task "id=00000000-0000-0000-0000-000000000000&position=0")
check_status "POST /move_task id desconocido -> 404" "404" "$STATUS"

# ── 10. POST /delete_task ─────────────────────────────────────────────────
STATUS=$(post /delete_task "id=$ID_A")
check_status "POST /delete_task Tarea A -> 302" "302" "$STATUS"
PAGE=$(curl -s "$BASE_URL/")
check_not_contains "Tarea A desaparece tras eliminarla" "Tarea A" "$PAGE"

STATUS=$(post /delete_task "id=$ID_B")
check_status "POST /delete_task Tarea B -> 302" "302" "$STATUS"
PAGE=$(curl -s "$BASE_URL/")
check_not_contains "Tarea B desaparece tras eliminarla" "Tarea B" "$PAGE"

# ── 11. POST /delete_task otra vez -> 404 ─────────────────────────────────
STATUS=$(post /delete_task "id=$ID_A")
check_status "POST /delete_task Tarea A otra vez -> 404" "404" "$STATUS"

# ── 12. GET /?vista=agrupado y GET /?vista=natural ────────────────────────
# La lista deberia estar vacia a estas alturas: creamos tres tareas nuevas,
# marcamos la del medio como hecha, y comprobamos las dos vistas.
post /tasks 'text=Tarea P' > /dev/null
post /tasks 'text=Tarea Q' > /dev/null
post /tasks 'text=Tarea R' > /dev/null
ID_P=$(get_ids | sed -n '1p')
ID_Q=$(get_ids | sed -n '2p')
ID_R=$(get_ids | sed -n '3p')
post /toggle_task "id=$ID_Q" > /dev/null

STATUS=$(get '/?vista=agrupado')
check_status "GET /?vista=agrupado -> 200" "200" "$STATUS"
PAGE=$(curl -s "$BASE_URL/?vista=agrupado")
POS_P=$(echo "$PAGE" | grep -n "Tarea P" | head -1 | cut -d: -f1)
POS_Q=$(echo "$PAGE" | grep -n "Tarea Q" | head -1 | cut -d: -f1)
POS_R=$(echo "$PAGE" | grep -n "Tarea R" | head -1 | cut -d: -f1)
if [ -n "$POS_P" ] && [ -n "$POS_Q" ] && [ -n "$POS_R" ] \
   && [ "$POS_P" -lt "$POS_Q" ] && [ "$POS_R" -lt "$POS_Q" ]; then
  echo "PASS  vista=agrupado: pendientes (P, R) antes que la hecha (Q)"
  PASS=$((PASS + 1))
else
  echo "FAIL  vista=agrupado deberia mostrar P y R antes que Q"
  FAIL=$((FAIL + 1))
  echo ""
  echo "Resultado: $PASS ok, $FAIL fallos"
  exit 1
fi

STATUS=$(get '/?vista=natural')
check_status "GET /?vista=natural -> 200" "200" "$STATUS"
PAGE=$(curl -s "$BASE_URL/?vista=natural")
POS_P=$(echo "$PAGE" | grep -n "Tarea P" | head -1 | cut -d: -f1)
POS_Q=$(echo "$PAGE" | grep -n "Tarea Q" | head -1 | cut -d: -f1)
POS_R=$(echo "$PAGE" | grep -n "Tarea R" | head -1 | cut -d: -f1)
if [ -n "$POS_P" ] && [ -n "$POS_Q" ] && [ -n "$POS_R" ] \
   && [ "$POS_P" -lt "$POS_Q" ] && [ "$POS_Q" -lt "$POS_R" ]; then
  echo "PASS  vista=natural: orden de creacion P, Q, R"
  PASS=$((PASS + 1))
else
  echo "FAIL  vista=natural deberia mostrar P, Q, R en orden de creacion"
  FAIL=$((FAIL + 1))
  echo ""
  echo "Resultado: $PASS ok, $FAIL fallos"
  exit 1
fi

# Limpieza: deja la lista vacia de nuevo
post /delete_task "id=$ID_P" > /dev/null
post /delete_task "id=$ID_Q" > /dev/null
post /delete_task "id=$ID_R" > /dev/null

:end

echo ""
echo "Resultado: $PASS ok, $FAIL fallos"
[ "$FAIL" -eq 0 ]
