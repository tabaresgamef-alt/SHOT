#!/bin/bash

# ========================================
#  AUTO-PATCH SCRIPT FOR SHOT (dev.html)
#  Author: ChatGPT + Felipe Tabares
#  =======================================

VERSION_FILE="version.json"
TARGET_FILE="dev/dev.html"
SNAPSHOT_DIR="snapshots"

# Ensure snapshot directory exists
mkdir -p "$SNAPSHOT_DIR"

echo "=== 🚀 Iniciando proceso automático de parcheo ==="

# -------------------------------------------------------
# 1. Validate required files
# -------------------------------------------------------
if [[ ! -f "$VERSION_FILE" ]]; then
  echo "❌ ERROR: No se encontró version.json"
  exit 1
fi

if [[ ! -f "$TARGET_FILE" ]]; then
  echo "❌ ERROR: No se encontró dev/dev.html"
  exit 1
fi

# -------------------------------------------------------
# 2. Read patchCounter
# -------------------------------------------------------
PATCH_COUNTER=$(jq '.patching.patchCounter' "$VERSION_FILE")
PATCH_PREFIX=$(jq -r '.patching.patchPrefix' "$VERSION_FILE")

NEW_PATCH_NUMBER=$(printf "%04d" $((PATCH_COUNTER + 1)))
NEW_PATCH="${PATCH_PREFIX}-dev-${NEW_PATCH_NUMBER}"

echo "➡ Patch actual: $PATCH_COUNTER"
echo "➡ Nuevo patch: $NEW_PATCH"

# -------------------------------------------------------
# 3. Create snapshot of dev.html
# -------------------------------------------------------
SNAPSHOT_FILE="${SNAPSHOT_DIR}/dev-${NEW_PATCH}.html"

cp "$TARGET_FILE" "$SNAPSHOT_FILE"

echo "📸 Snapshot creado: $SNAPSHOT_FILE"

# -------------------------------------------------------
# 4. Apply patch (Insert code modification automatically)
# -------------------------------------------------------
echo ""
echo "✏️ Escribe una breve descripción del cambio:"
read PATCH_DESCRIPTION

# Example automatic modification:
# (Aquí puedes colocar lo que sea: insertar badge, modificar script, etc.)
# El ejemplo agrega un comentario al final indicando que fue parchado.

echo "<!-- PATCH: $NEW_PATCH | $PATCH_DESCRIPTION -->" >> "$TARGET_FILE"

echo "🛠 Modificación aplicada a dev/dev.html"

# -------------------------------------------------------
# 5. Update version.json
# -------------------------------------------------------
jq \
    --arg newPatch "$NEW_PATCH" \
    --arg nextPatch "$(printf "%04d" $((PATCH_COUNTER + 2)) )" \
    --arg description "$PATCH_DESCRIPTION" \
    '
    .patching.patchCounter += 1
    | .patching.lastPatch = $newPatch
    | .patching.nextPatchName = "patch-" + $nextPatch
    | .changelog += [{
        patch: $newPatch,
        description: $description,
        date: (now | strftime("%Y-%m-%d %H:%M:%S"))
      }]
    ' "$VERSION_FILE" > version.tmp.json && mv version.tmp.json "$VERSION_FILE"

echo "📄 version.json actualizado correctamente"

# -------------------------------------------------------
# 6. Git add + commit (optional)
# -------------------------------------------------------
echo ""
echo "¿Deseas hacer commit automático? (s/n)"
read DO_COMMIT

if [[ "$DO_COMMIT" == "s" ]]; then
    git add "$TARGET_FILE" "$VERSION_FILE" "$SNAPSHOT_FILE"
    git commit -m "Parche automático: $NEW_PATCH — $PATCH_DESCRIPTION"
    echo "✔ Commit realizado"
else
    echo "ℹ No se hizo commit. Recuerda agregarlo manualmente."
fi

echo ""
echo "🎉 Proceso de parche completado exitosamente"
echo "Nuevo parche: $NEW_PATCH"

