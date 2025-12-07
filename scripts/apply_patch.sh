#!/bin/bash

# ========================================
#  APPLY PATCH FOR SHOT (dev.html)
#  Aplica un .patch existente a dev/dev.html
#  Autor: ChatGPT + Felipe Tabares
# ========================================

VERSION_FILE="version.json"
TARGET_FILE="dev/dev.html"
PATCH_DIR="dev/patches"   # ← CORREGIDO
SNAPSHOT_DIR="snapshots"

# 1) Patch a aplicar (argumento o por defecto cambios.patch)
PATCH_FILE="${1:-$PATCH_DIR/cambios.patch}"   # ← USANDO RUTA CORREGIDA

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

if [[ ! -f "$TARGET_FILE"_]()]()
