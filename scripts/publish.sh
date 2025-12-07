#!/bin/bash

# ========================================
#  PUBLISH STABLE VERSION FOR SHOT
#  Copia dev/dev.html → index.html
#  Actualiza version.json y genera snapshot
#  Autor: ChatGPT + Felipe Tabares
# ========================================

DEV_FILE="dev/dev.html"
STABLE_FILE="index.html"
VERSION_FILE="version.json"
VERSIONS_DIR="versions"

mkdir -p "$VERSIONS_DIR"

echo "=== 🚀 Publicando nueva versión estable ==="
echo ""

# -------------------------------------------------------------
# 1. Validar archivos base
# -------------------------------------------------------------
if [[ ! -f "$DEV_FILE" ]]; then
  echo "❌ ERROR: No existe dev/dev.html"
  exit 1
fi

if [[ ! -f "$VERSION_FILE" ]]; then
  echo "❌ ERROR: No existe version.json"
  exit 1
fi

# -------------------------------------------------------------
# 2. Leer versión actual
# -------------------------------------------------------------
CURRENT_VERSION=$(jq -r '.version' "$VERSION_FILE")
SEMVER=$(jq -r '.semver' "$VERSION_FILE")

echo "➡ Versión estable actual : $CURRENT_VERSION"
echo "➡ SemVer actual          : $SEMVER"

IFS='.' read -r major minor patch <<< "$SEMVER"

echo ""
echo "Selecciona el tipo de incremento de versión:"
echo "1) Major (${major}.${minor}.${patch} → $((major+1)).0.0)"
echo "2) Minor (${major}.${minor}.${patch} → ${major}.$((minor+1)).0)"
echo "3) Patch (${major}.${minor}.${patch} → ${major}.${minor}.$((patch+1)))"
echo ""
read -p "Opción (1/2/3): " OPTION

case "$OPTION" in
  1)
    major=$((major + 1))
    minor=0
    patch=0
    TYPE="major"
    ;;
  2)
    minor=$((minor + 1))
    patch=0
    TYPE="minor"
    ;;
  3)
    patch=$((patch + 1))
    TYPE="patch"
    ;;
  *)
    echo "❌ Opción inválida."
    exit 1
    ;;
esac

NEW_SEMVER="${major}.${minor}.${patch}"
NEW_VERSION="v${NEW_SEMVER}"

echo ""
echo "➡ Nueva versión estable generada: $NEW_VERSION"
echo "➡ Tipo de incremento aplicado    : $TYPE"
echo ""

# -------------------------------------------------------------
# 3. Crear snapshot histórico
# -------------------------------------------------------------
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
SNAPSHOT_FILE="${VERSIONS_DIR}/dev_${TIMESTAMP}_snapshot.html"

cp "$DEV_FILE" "$SNAPSHOT_FILE"

echo "📸 Snapshot guardado: $SNAPSHOT_FILE"
echo ""

# -------------------------------------------------------------
# 4. Publicar dev → index
# -------------------------------------------------------------
cp "$DEV_FILE" "$STABLE_FILE"

echo "✔ index.html actualizado con contenido de dev.html"
echo ""

# -------------------------------------------------------------
# 5. Actualizar version.json
# -------------------------------------------------------------
jq \
  --arg newVersion "$NEW_VERSION" \
  --arg newSemver "$NEW_SEMVER" \
  --arg snapshot "$SNAPSHOT_FILE" \
  --arg type "$TYPE" \
  '
