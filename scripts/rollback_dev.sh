#!/bin/bash

# ========================================
#  ROLLBACK DEV PATCH FOR SHOT (dev.html)
#  Revierte el último parche de DEV de forma segura
#  Autor: ChatGPT + Felipe Tabares
# ========================================

VERSION_FILE="version.json"
TARGET_FILE="dev/dev.html"
SNAPSHOT_DIR="snapshots"

echo "=== 🔄 Iniciando rollback de parche en DEV ==="
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

if [[ ! -d "$SNAPSHOT_DIR" ]]; then
  echo "❌ ERROR: No existe snapshots/"
  exit 1
fi

# -------------------------------------------------------------
# 2. Extraer únicamente los patches del changelog
# -------------------------------------------------------------
PATCHES=($(jq -r '.changelog[] | select(has("patch")) | .patch' "$VERSION_FILE"))

if (( ${#PATCHES[@]} == 0 )); then
  echo "⚠ No hay parches aplicados para revertir."
  exit 0
fi

LAST_PATCH="${PATCHES[-1]}"

echo "➡ Último parche aplicado: $LAST_PATCH"
echo ""

# -------------------------------------------------------------
# 3. Determinar snapshot asociado
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
# 4. Restaurar dev/dev.html
# -------------------------------------------------------------
cp "$SNAPSHOT_FILE" "$TARGET_FILE"

echo "✔ dev.html restaurado desde snapshot"
echo ""

# -------------------------------------------------------------
# 5. Recalcular contador y lastPatch REAL
# -------------------------------------------------------------
NEW_PATCH_LIST=("${PATCHES[@]::${#PATCHES[@]}-1}")  # quitar último
NEW_COUNTER=${#NEW_PATCH_LIST[@]}

if (( NEW_COUNTER == 0 )); then
  NEW_LAST_PATCH="none"
else
  NEW_LAST_PATCH="${NEW_PATCH_LIST[-1]}"
fi

# Determinar el nextPatchName real
NEXT_PATCH_NUM=$((NEW_COUNTER + 1))
NEXT_PATCH_NAME=$(printf "patch-%04d" "$NEXT_PATCH_NUM")

echo "➡ Nuevo patchCounter : $NEW_COUNTER"
echo "➡ Nuevo lastPatch    : $NEW_LAST_PATCH"
echo "➡ nextPatchName      : $NEXT_PATCH_NAME"
echo ""

# -------------------------------------------------------------
# 6. Actualizar version.json correctamente
# -------------------------------------------------------------
jq \
  --arg last "$NEW_LAST_PATCH" \
  --arg next "$NEXT_PATCH_NAME" \
  --arg patchToRemove "$LAST_PATCH" \
  --argjson newCount "$NEW_COUNTER" \
  '
  .patching.patchCounter = $newCount
  | .patching.lastPatch = $last
  | .patching.nextPatchName = $next
  | .changelog |= map(select(.patch != $patchToRemove))
  ' "$VERSION_FILE" > version.tmp && mv version.tmp "$VERSION_FILE"

echo "✔ version.json actualizado:"
echo "   - patchCounter = $NEW_COUNTER"
echo "   - lastPatch    = $NEW_LAST_PATCH"
echo "   - nextPatch    = $NEXT_PATCH_NAME"
echo "   - changelog    entrada eliminada"
echo ""

# -------------------------------------------------------------
# 7. Commit automático (opcional)
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
echo "🎉 Rollback de parche completado correctamente."
