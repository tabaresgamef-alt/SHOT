#!/bin/bash

# ========================================
#   ROLLBACK PATCH FOR SHOT (dev.html)
#   Revierte un parche previamente aplicado
#   Autor: ChatGPT + Felipe Tabares
# ========================================

VERSION_FILE="version.json"
TARGET_FILE="dev/dev.html"
SNAPSHOT_DIR="snapshots"

echo "=== 🔄 Iniciando proceso de rollback ==="
echo ""

# -------------------------------------------------------------
# 1. Validar archivos base
# -------------------------------------------------------------
if [[ ! -f "$VERSION_FILE" ]]; then
  echo "❌ ERROR: No existe version.json"
  exit 1
fi

if [[ ! -f "$TARGET_FILE" ]]; then
  echo "❌ ERROR: No existe dev/dev.html"
  exit 1
fi

# -------------------------------------------------------------
# 2. Leer versión actual
# -------------------------------------------------------------
PATCH_COUNTER=$(jq '.patching.patchCounter' "$VERSION_FILE")
LAST_PATCH=$(jq -r '.patching.lastPatch' "$VERSION_FILE")

if [[ "$PATCH_COUNTER" -le 0 ]]; then
  echo "⚠ No hay parches que revertir."
  exit 0
fi

echo "➡ PatchCounter actual : $PATCH_COUNTER"
echo "➡ Último parche aplicado : $LAST_PATCH"
echo ""

# -------------------------------------------------------------
# 3. Determinar snapshot
# -------------------------------------------------------------
SNAPSHOT_FILE="${SNAPSHOT_DIR}/dev-before-${LAST_PATCH}.html"

if [[ ! -f "$SNAPSHOT_FILE" ]]; then
  echo "❌ ERROR: No existe el snapshot requerido:"
  echo "   $SNAPSHOT_FILE"
  exit 1
fi

echo "📸 Snapshot encontrado: $SNAPSHOT_FILE"
echo ""

# -------------------------------------------------------------
# 4. Restaurar snapshot
# -------------------------------------------------------------
cp "$SNAPSHOT_FILE" "$TARGET_FILE"

echo "✔ dev.html restaurado desde snapshot"
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
        else .changelog[-2].patch
        end
    )
  | .patching.nextPatchName = "patch-" + ( ($newCounter + 1 | tostring | tonumber | 10000 + .) | tostring | .[1:] )
  | .changelog |= map(select(.patch != $lastPatch))
  ' "$VERSION_FILE" > version.tmp && mv version.tmp "$VERSION_FILE"

echo "📄 version.json actualizado:"
echo "   - patchCounter = $NEW_COUNTER"
echo "   - lastPatch revertido"
echo "   - se eliminó entrada en changelog"
echo ""

# -------------------------------------------------------------
# 6. Preguntar por commit automático
# -------------------------------------------------------------
echo "¿Deseas hacer commit automático del rollback? (s/n)"
read DO_COMMIT

if [[ "$DO_COMMIT" == "s" ]]; then
  git add "$TARGET_FILE" "$VERSION_FILE"
  git commit -m "Rollback de parche ${LAST_PATCH}"
  echo "✔ Commit realizado"
else
  echo "ℹ Commit no realizado. Recuerda hacerlo manualmente."
fi

echo ""
echo "🎉 Rollback completado correctamente."
