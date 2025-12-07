#!/bin/bash

# ===========================================================
#  ROLLBACK PATCH FOR SHOT (revierte un archivo .patch)
#  autor: ChatGPT + Felipe Tabares
# ===========================================================

PATCH_FILE="$1"
TARGET_FILE="dev/dev.html"
VERSION_FILE="version.json"

if [[ -z "$PATCH_FILE" ]]; then
  echo "❌ Debes especificar el patch:"
  echo "   ./scripts/rollback_patch.sh patches/patch-dev-0003.patch"
  exit 1
fi

if [[ ! -f "$PATCH_FILE" ]]; then
  echo "❌ No existe el patch: $PATCH_FILE"
  exit 1
fi

echo "=== 🔄 Revirtiendo patch: $PATCH_FILE ==="

# Crear snapshot antes del rollback
SNAPSHOT_DIR="snapshots"
mkdir -p "$SNAPSHOT_DIR"
SNAPSHOT_FILE="${SNAPSHOT_DIR}/rollback-before-$(basename "$PATCH_FILE" .patch).html"

cp "$TARGET_FILE" "$SNAPSHOT_FILE"
echo "📸 Snapshot guardado: $SNAPSHOT_FILE"

# Aplicar reversa del parche
if git apply -R "$PATCH_FILE"; then
  echo "✔ Patch revertido correctamente"
else
  echo "❌ Hubo un conflicto al revertir el patch"
  echo "   Se restaurará el snapshot"
  cp "$SNAPSHOT_FILE" "$TARGET_FILE"
  exit 1
fi

# Actualizar version.json
jq \
  --arg reverted "$(basename "$PATCH_FILE" .patch)" \
  '
  .patching.patchCounter -= 1
  | .patching.lastPatch = ("reverted-" + $reverted)
  | .changelog += [{
      revert: $reverted,
      date: (now | strftime("%Y-%m-%d %H:%M:%S"))
    }]
  ' "$VERSION_FILE" > version.tmp && mv version.tmp "$VERSION_FILE"

echo "📄 version.json actualizado (rollback registrado)"

# Confirmación de commit
echo ""
echo "¿Deseas hacer commit del rollback? (s/n)"
read DO_COMMIT

if [[ "$DO_COMMIT" == "s" ]]; then
  git add "$TARGET_FILE" "$VERSION_FILE" "$SNAPSHOT_FILE"
  git commit -m "Rollback de patch $(basename "$PATCH_FILE")"
  echo "✔ Commit realizado"
else
  echo "ℹ Saltando commit. Recuerda hacerlo manualmente."
fi

echo ""
echo "🎉 Rollback completado correctamente"
