#!/usr/bin/env bash
# Comprobacion rapida: el servidor responde en / con HTTP 200.
# Sirve para las dos versiones (salto de pagina y fetch), ya que
# ambas deben exponer GET / con ese comportamiento.
#
# Uso: ./smoke.sh [URL_BASE]
#   URL_BASE por defecto: http://localhost:7070

BASE_URL="${1:-http://localhost:7070}"
PASS=0
FAIL=0

check() {
  local label="$1" expected="$2" actual="$3"
  if [ "$actual" = "$expected" ]; then
    echo "PASS  $label"
    PASS=$((PASS + 1))
  else
    echo "FAIL  $label (esperado $expected, obtenido $actual)"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== Smoke test: $BASE_URL ==="

status=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/")
check "GET / devuelve 200" "200" "$status"

echo ""
echo "Resultado: $PASS ok, $FAIL fallos"
[ "$FAIL" -eq 0 ]
