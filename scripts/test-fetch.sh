#!/usr/bin/env bash
# Verifica el contrato de la API JSON de la version con fetch:
#
#   GET  /api/tasks                           200  array JSON
#   POST /api/tasks        text=...           201  (400 si text falta/vacio)
#   POST /api/toggle_task    id=...           200  (404 si id no existe)
#   POST /api/delete_task    id=...           204  (404 si id no existe)
#   POST /api/move_task  id=...&position=...  200  (404 si id no existe)
#
# No comprueba el JavaScript del cliente (eso solo se ve en el navegador);
# comprueba que la API que ese JavaScript consume es correcta.
#
# Uso: ./test-fetch.sh [URL_BASE]
#   URL_BASE por defecto: http://localhost:7070

set -u
BASE_URL="${1:-http://localhost:7070}"
PASS=0
FAIL=0
TMPFILE=$(mktemp)
trap 'rm -f "$TMPFILE"' EXIT

if ! command -v jq &>/dev/null; then
  echo "ERROR: hace falta jq. Instalalo con: apt-get install jq  (o brew install jq)"
  exit 1
fi

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

check_eq() {
  local label="$1" expected="$2" actual="$3"
  if [ "$actual" = "$expected" ]; then
    echo "PASS  $label"
    PASS=$((PASS + 1))
  else
    echo "FAIL  $label (esperado '$expected', obtenido '$actual')"
    FAIL=$((FAIL + 1))
    echo ""
    echo "Resultado: $PASS ok, $FAIL fallos"
    exit 1
  fi
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

echo "=== Test API version fetch: $BASE_URL ==="
echo ""

# ── 1. GET /api/tasks – lista vacia ──────────────────────────────────────
STATUS=$(get /api/tasks)
check_status "GET /api/tasks (vacia) -> 200" "200" "$STATUS"
check_eq "GET /api/tasks devuelve []" "[]" "$(body | jq -c .)"

# Según vayas avanzando en el desarrollo, puedes mover
# esta línea hacia abajo para incluir más tests.
goto end

# ── 2. POST /api/tasks – crear Tarea A ───────────────────────────────────
STATUS=$(post /api/tasks 'text=Tarea A')
check_status "POST /api/tasks (crear Tarea A) -> 201" "201" "$STATUS"
ID_A=$(body | jq -r '.id')
check_eq "Tarea A tiene el texto correcto" "Tarea A" "$(body | jq -r '.text')"
check_eq "Tarea A tiene done=false al crearla" "false" "$(body | jq -r '.done')"

# ── 3. POST /api/tasks – crear Tarea B ───────────────────────────────────
STATUS=$(post /api/tasks 'text=Tarea B')
check_status "POST /api/tasks (crear Tarea B) -> 201" "201" "$STATUS"
ID_B=$(body | jq -r '.id')

# ── 4. POST /api/tasks – text vacio o ausente -> 400 ─────────────────────
STATUS=$(post /api/tasks '')
check_status "POST /api/tasks (sin text) -> 400" "400" "$STATUS"

STATUS=$(post /api/tasks 'text=')
check_status "POST /api/tasks (text vacio) -> 400" "400" "$STATUS"

# ── 5. GET /api/tasks – las dos tareas, en orden ──────────────────────────
STATUS=$(get /api/tasks)
check_status "GET /api/tasks (2 tareas) -> 200" "200" "$STATUS"
check_eq "GET /api/tasks devuelve 2 tareas" "2" "$(body | jq 'length')"
check_eq "La primera tarea es Tarea A" "Tarea A" "$(body | jq -r '.[0].text')"

# ── 6. POST /api/toggle_task – marcar Tarea A ─────────────────────────────
STATUS=$(post /api/toggle_task "id=$ID_A")
check_status "POST /api/toggle_task Tarea A -> 200" "200" "$STATUS"
check_eq "Tarea A tiene done=true tras marcarla" "true" "$(body | jq -r '.done')"

# ── 7. POST /api/toggle_task – desmarcar Tarea A ──────────────────────────
STATUS=$(post /api/toggle_task "id=$ID_A")
check_status "POST /api/toggle_task Tarea A otra vez -> 200" "200" "$STATUS"
check_eq "Tarea A tiene done=false tras desmarcarla" "false" "$(body | jq -r '.done')"

# ── 8. POST /api/toggle_task – id desconocido -> 404 ─────────────────────
STATUS=$(post /api/toggle_task "id=00000000-0000-0000-0000-000000000000")
check_status "POST /api/toggle_task id desconocido -> 404" "404" "$STATUS"

# ── 9. POST /api/move_task – mover Tarea B a posicion 0 ──────────────────
STATUS=$(post /api/move_task "id=$ID_B&position=0")
check_status "POST /api/move_task Tarea B a posicion 0 -> 200" "200" "$STATUS"
check_eq "Tarea B es la primera tras moverla" "$ID_B" "$(body | jq -r '.[0].id')"

# ── 10. POST /api/move_task – id desconocido -> 404 ──────────────────────
STATUS=$(post /api/move_task "id=00000000-0000-0000-0000-000000000000&position=0")
check_status "POST /api/move_task id desconocido -> 404" "404" "$STATUS"

# ── 11. POST /api/delete_task ─────────────────────────────────────────────
STATUS=$(post /api/delete_task "id=$ID_A")
check_status "POST /api/delete_task Tarea A -> 204" "204" "$STATUS"

STATUS=$(post /api/delete_task "id=$ID_B")
check_status "POST /api/delete_task Tarea B -> 204" "204" "$STATUS"

# ── 12. POST /api/delete_task otra vez -> 404 ─────────────────────────────
STATUS=$(post /api/delete_task "id=$ID_A")
check_status "POST /api/delete_task Tarea A otra vez -> 404" "404" "$STATUS"

# ── 13. GET /api/tasks – vacia de nuevo ───────────────────────────────────
STATUS=$(get /api/tasks)
check_status "GET /api/tasks (vacia tras borrar) -> 200" "200" "$STATUS"
check_eq "GET /api/tasks devuelve [] tras borrar" "[]" "$(body | jq -c .)"

:end

echo ""
echo "Resultado: $PASS ok, $FAIL fallos"
[ "$FAIL" -eq 0 ]
