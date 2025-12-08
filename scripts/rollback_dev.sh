#!/bin/bash

# ========================================
#  ROLLBACK DEV PATCH FOR SHOT (dev.html)
#  Revierte el último parche aplicado en dev
#  Autor: ChatGPT + Felipe Tabares
# ========================================

VERSION_FILE="version.json"
TARGET_FILE="dev/dev.html"
SNAPSHOT_DIR="snapshots"

echo "=== 🔄 Iniciando rollback de parche en DEV ==="
echo ""

# -------------------------------------------------------------
# 1. Validar archivos requeridos
# -------------------------------------------------------------
if [[ ! -f "$VERSION_FILE" ]]; then
  echo "❌ ERROR: No existe version.json"
  exit 1
fi

if [[ ! -f "$TARGET_FILE" ]]; then
  echo "❌ ERROR: No existe dev/dev.html"
  exit 1
fi

if [[ ! -d "$SNAPSHOT_DIR" ]]; then
  echo "❌ ERROR: No existe el directorio snapshots/"
  exit 1
fi

# -------------------------------------------------------------
# 2. Leer patchCounter y último parche
# -------------------------------------------------------------
PATCH_COUNTER=$(jq '.patching.patchCounter' "$VERSION_FILE")
LAST_PATCH=$(jq -r '.patching.lastPatch' "$VERSION_FILE")

if (( PATCH_COUNTER == 0 )); then
  echo "⚠ No hay parches aplicados para revertir."
  exit 0
fi

echo "➡ PatchCounter actual : $PATCH_COUNTER"
echo "➡ Último parche aplicado : $LAST_PATCH"
echo ""

# -------------------------------------------------------------
# 3. Determinar snapshot para rollback
# -------------------------------------------------------------
SNAPSHOT_FILE="${SNAPSHOT_DIR}/dev-before-${LAST_PATCH}.html"

if [[ ! -f "$SNAPSHOT_FILE" ]]; then
  echo "❌ ERROR: Snapshot no encontrado:"
  echo "   $SNAPSHOT_FILE"
  exit 1
fi

echo "📸 Snapshot encontrado: $SNAPSHOT_FILE"
echo ""

# -------------------------------------------------------------
# 4. Restaurar dev.html desde snapshot
# -------------------------------------------------------------
cp "$SNAPSHOT_FILE" "$TARGET_FILE"

echo "✔ dev.html restaurado correctamente desde snapshot"
echo ""

# -------------------------------------------------------------
# 5. Actualizar version.json
# -------------------------------------------------------------
NEW_COUNTER=$((PATCH_COUNTER - 1))

jq \
  --arg lastPatch "$LAST_PATCH" \
  --argjson newCounter "$NEW_COUNTER" \
  '
  .patching.patchCounter = $newCounter
  | .patching.lastPatch = (
        if $newCounter == 0 then "none"
        else .changelog[] | select(.patch != $lastPatch) | .patch
        end
    )
  | .patching.nextPatchName = "patch-" + ( ($newCounter + 1 | tostring | tonumber | 10000 + .) | tostring | .[1:] )
  | .changelog |= map(select(.patch != $lastPatch))
  ' "$VERSION_FILE" > version.tmp && mv version.tmp "$VERSION_FILE"

echo "📄 version.json actualizado:"
echo "   - patchCounter = $NEW_COUNTER"
echo "   - lastPatch revertido"
echo "   - entrada borrada del changelog"
echo ""

# -------------------------------------------------------------
# 6. Commit automático
# -------------------------------------------------------------
echo "¿Deseas hacer commit automático del rollback? (s/n)"
read DO_COMMIT

if [[ "$DO_COMMIT" == "s" ]]; then
  git add "$TARGET_FILE" "$VERSION_FILE"
  git commit -m "Rollback de parche ${LAST_PATCH}"
  echo "✔ Commit realizado"
else
  echo "ℹ No se realizó commit."
fi

echo ""
echo "🎉 Rollback completado correctamente."
