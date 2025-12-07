#!/bin/bash

# ========================================
#  AUTO PATCH GENERATOR FOR SHOT
#  Generates .patch files based on changes
#  Author: ChatGPT + Felipe Tabares
# ========================================

VERSION_FILE="version.json"
TARGET_FILE="dev/dev.html"
PATCH_DIR="patches"
SNAPSHOT_DIR="snapshots"

mkdir -p "$PATCH_DIR"
mkdir -p "$SNAPSHOT_DIR"

echo "=== 🚀 Iniciando generador automático de parches (.patch) ==="

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

# -------------------------------------------------------------
# 2. Leer información del JSON
# -------------------------------------------------------------
PATCH_COUNTER=$(jq '.patching.patchCounter' "$VERSION_FILE")
PATCH_PREFIX=$(jq -r '.patching.patchPrefix' "$VERSION_FILE")

NEW_PATCH_NUM=$(printf "%04d" $((PATCH_COUNTER + 1)))
NEW_PATCH="${PATCH_PREFIX}-dev-${NEW_PATCH_NUM}"

echo "➡ Patch anterior: $PATCH_COUNTER"
echo "➡ Nuevo patch    : $NEW_PATCH"

# -------------------------------------------------------------
# 3. Crear snapshot previo
# -------------------------------------------------------------
SNAPSHOT_FILE="${SNAPSHOT_DIR}/dev-before-${NEW_PATCH}.html"
cp "$TARGET_FILE" "$SNAPSHOT_FILE"

echo "📸 Snapshot guardado: $SNAPSHOT_FILE"

# -------------------------------------------------------------
# 4. Pedir descripción del parche
# -------------------------------------------------------------
echo ""
echo "✏️  Escribe una breve descripción del parche:"
read PATCH_DESCRIPTION

# -------------------------------------------------------------
# 5. Asegurar que hay cambios sin commit (para generar diff)
# -------------------------------------------------------------
# Git solo genera diff con cambios no committeados
if git diff --quiet "$TARGET_FILE"; then
  echo "⚠ No hay cambios detectados en $TARGET_FILE"
  echo "   Debes modificar dev/dev.html antes de generar el parche."
  exit 1
fi

# -------------------------------------------------------------
# 6. Generar el archivo del parche usando git diff
# -------------------------------------------------------------
PATCH_FILE="${PATCH_DIR}/${NEW_PATCH}.patch"

git diff "$TARGET_FILE" > "$PATCH_FILE"

echo "🧩 Parche generado: $PATCH_FILE"

# -------------------------------------------------------------
# 7. Agregar encabezado del parche
# -------------------------------------------------------------
echo -e "\n# PATCH: $NEW_PATCH | $PATCH_DESCRIPTION" >> "$PATCH_FILE"

# -------------------------------------------------------------
# 8. Actualizar version.json
# -------------------------------------------------------------
jq \
  --arg newPatch "$NEW_PATCH" \
  --arg nextPatch "$(printf "%04d" $((PATCH_COUNTER + 2)))" \
  --arg desc "$PATCH_DESCRIPTION" \
  '
  .patching.patchCounter += 1
  | .patching.lastPatch = $newPatch
  | .patching.nextPatchName = "patch-" + $nextPatch
  | .changelog += [{
      patch: $newPatch,
      description: $desc,
      date: (now | strftime("%Y-%m-%d %H:%M:%S"))
    }]
  ' "$VERSION_FILE" > version.tmp && mv version.tmp "$VERSION_FILE"

echo "📄 version.json actualizado con éxito"

# -------------------------------------------------------------
# 9. Confirmar commit
# -------------------------------------------------------------
echo ""
echo "¿Deseas realizar commit automático? (s/n)"
read DO_COMMIT

if [[ "$DO_COMMIT" == "s" ]]; then
  git add "$TARGET_FILE" "$VERSION_FILE" "$PATCH_FILE" "$SNAPSHOT_FILE"
  git commit -m "Parche automático ${NEW_PATCH}: ${PATCH_DESCRIPTION}"
  echo "✔ Commit realizado"
else
  echo "ℹ Saltando commit. Recuerda hacerlo manualmente."
fi

echo ""
echo "🎉 Proceso completado. Parche creado: $PATCH_FILE"
