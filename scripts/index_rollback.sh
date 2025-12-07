#!/bin/bash

# ========================================
#  ROLLBACK STABLE VERSION FOR SHOT
#  Revierte el último publish (index.html)
#  Autor: ChatGPT + Felipe Tabares
# ========================================

VERSION_FILE="version.json"
STABLE_FILE="index.html"
VERSIONS_DIR="versions"

echo "=== 🔄 Iniciando rollback de versión estable ==="
echo ""

# -------------------------------------------------------------
# 1. Validar archivos requeridos
# -------------------------------------------------------------
if [[ ! -f "$VERSION_FILE" ]]; then
  echo "❌ ERROR: No existe version.json"
  exit 1
fi

if [[ ! -f "$STABLE_FILE" ]]; then
  echo "❌ ERROR: No existe index.html"
  exit 1
fi

# -------------------------------------------------------------
# 2. Determinar snapshot más reciente
# -------------------------------------------------------------
LAST_SNAPSHOT=$(ls -t ${VERSIONS_DIR}/dev_*_snapshot.html 2>/dev/null | head -n 1)

if [[ -z "$LAST_SNAPSHOT" ]]; then
  echo "❌ ERROR: No se encontró ningún snapshot en versions/"
  exit 1
fi

echo "📸 Snapshot encontrado:"
echo "   $LAST_SNAPSHOT"
echo ""

# -------------------------------------------------------------
# 3. Restaurar index.html desde snapshot
# -------------------------------------------------------------
cp "$LAST_SNAPSHOT" "$STABLE_FILE"

echo "✔ index.html restaurado desde snapshot"
echo ""

# -------------------------------------------------------------
# 4. Revertir version.json
# -------------------------------------------------------------
echo "Revirtiendo cambios en version.json..."

# Leer semver actual
SEMVER=$(jq -r '.semver' "$VERSION_FILE")
IFS='.' read -r major minor patch <<< "$SEMVER"

# Revertir patch (si es 0, no hacemos nada más complejo)
if (( patch > 0 )); then
  patch=$((patch - 1))
else
  patch=0
fi

NEW_SEMVER="${major}.${minor}.${patch}"
NEW_VERSION="v${NEW_SEMVER}"

jq \
  --arg newVersion "$NEW_VERSION" \
  --arg newSemver "$NEW_SEMVER" \
  '
  .version = $newVersion
  | .semver = $newSemver
  | .build.number -= 1
  | .changelog |= map(select(.type != "publish"))
  ' "$VERSION_FILE" > version.tmp && mv version.tmp "$VERSION_FILE"

echo "✔ version.json revertido:"
echo "   - Nueva versión: $NEW_VERSION"
echo ""

# -------------------------------------------------------------
# 5. Commit automático
# -------------------------------------------------------------
echo "¿Deseas hacer commit automático del rollback? (s/n)"
read DO_COMMIT

if [[ "$DO_COMMIT" == "s" ]]; then
  git add "$STABLE_FILE" "$VERSION_FILE"
  git commit -m "Rollback de versión estable a ${NEW_VERSION}"
  echo "✔ Commit realizado"
else
  echo "ℹ No se realizó commit."
fi

echo ""
echo "🎉 Rollback completo."
