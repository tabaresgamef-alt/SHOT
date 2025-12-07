#!/bin/bash

# ========================================
#  APPLY PATCH FOR SHOT (dev.html)
#  Aplica un .patch existente a dev/dev.html
#  Autor: ChatGPT + Felipe Tabares
# ========================================

VERSION_FILE="version.json"
TARGET_FILE="dev/dev.html"
PATCH_DIR="dev/patches"
SNAPSHOT_DIR="snapshots"

# 1) Patch a aplicar (argumento o por defecto cambios.patch)
PATCH_FILE="${1:-$PATCH_DIR/cambios.patch}"

echo "=== 🚀 Aplicando parche sobre $TARGET_FILE ==="
echo "Patch a usar: $PATCH_FILE"
echo ""

# -------------------------------------------------------------
# 2. Validar archivos requeridos
# -------------------------------------------------------------
if [[ ! -f "$VERSION_FILE" ]]; then
  echo "❌ ERROR: No existe $VERSION_FILE"
  exit 1
fi

if [[ ! -f "$TARGET_FILE" ]]; then
  echo "❌ ERROR: No existe $TARGET_FILE"
  exit 1
fi

if [[ ! -f "$PATCH_FILE" ]]; then
  echo "❌ ERROR: No existe el patch: $PATCH_FILE"
  exit 1
fi

mkdir -p "$SNAPSHOT_DIR"

# -------------------------------------------------------------
# 3. Leer información de version.json
# -------------------------------------------------------------
PATCH_COUNTER=$(jq '.patching.patchCounter' "$VERSION_FILE")
PATCH_PREFIX=$(jq -r '.patching.patchPrefix' "$VERSION_FILE")

PATCH_BASENAME=$(basename "$PATCH_FILE" .patch)
NEW_PATCH_NAME="${PATCH_PREFIX}-dev-$(printf "%04d" $((PATCH_COUNTER + 1)))"

echo "➡ PatchCounter actual : $PATCH_COUNTER"
echo "➡ Nuevo identificador : $NEW_PATCH_NAME"
echo ""

# -------------------------------------------------------------
# 4. Crear snapshot antes de aplicar
# -------------------------------------------------------------
SNAPSHOT_FILE="${SNAPSHOT_DIR}/dev-before-${NEW_PATCH_NAME}.html"
cp "$TARGET_FILE" "$SNAPSHOT_FILE"

echo "📸 Snapshot guardado: $SNAPSHOT_FILE"

# -------------------------------------------------------------
# 5. Aplicar el patch
# -------------------------------------------------------------
echo "🧩 Aplicando patch con git apply..."
if ! git apply "$PATCH_FILE"; then
  echo "❌ ERROR: Falló git apply. Revisa conflictos o el contenido del patch."
  cp "$SNAPSHOT_FILE" "$TARGET_FILE"
  echo "ℹ Se restauró $TARGET_FILE desde el snapshot."
  exit 1
fi

echo "✔ Patch aplicado correctamente sobre $TARGET_FILE"
echo ""

# -------------------------------------------------------------
# 6. Pedir descripción del parche
# -------------------------------------------------------------
echo "✏️  Escribe una breve descripción para version.json:"
read PATCH_DESCRIPTION

# -------------------------------------------------------------
# 7. Actualizar version.json
# -------------------------------------------------------------
jq \
  --arg newPatch "$NEW_PATCH_NAME" \
  --arg nextPatch "$(printf "%04d" $((PATCH_COUNTER + 2)))" \
  --arg desc "$PATCH_DESCRIPTION" \
  '
  .patching.patchCounter += 1
  | .patching.lastPatch = $newPatch
  | .patching.nextPatchName = "patch-" + $nextPatch
  | .changelog += [{
      patch: $newPatch,
      file: $ENV_PATCH_FILE,
      description: $desc,
      date: (now | strftime("%Y-%m-%d %H:%M:%S"))
    }]
  ' "$VERSION_FILE" > version.tmp && mv version.tmp "$VERSION_FILE"

echo "📄 version.json actualizado:"
echo "   - patchCounter  += 1"
echo "   - lastPatch       = $NEW_PATCH_NAME"
echo "   - nextPatchName   = patch-$(printf '%04d' $((PATCH_COUNTER + 2)))"
echo ""

# -------------------------------------------------------------
# 8. Commit automático
# -------------------------------------------------------------
echo "¿Deseas hacer commit automático? (s/n)"
read DO_COMMIT

if [[ "$DO_COMMIT" == "s" ]]; then
  git add "$TARGET_FILE" "$VERSION_FILE" "$PATCH_FILE" "$SNAPSHOT_FILE"
  git commit -m "Aplicado parche ${NEW_PATCH_NAME}: ${PATCH_DESCRIPTION}"
  echo "✔ Commit realizado"
else
  echo "ℹ Saltando commit. Recuerda hacerlo manualmente."
fi

echo ""
echo "🎉 Proceso completado. Parche aplicado: $PATCH_FILE"
