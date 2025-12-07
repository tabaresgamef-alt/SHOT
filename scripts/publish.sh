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
    ;;
  2)
    minor=$((minor + 1))
    patch=0
    ;;
  3)
    patch=$((patch + 1))
    ;;
  *)
    echo "❌ Opción inválida."
    exit 1
    ;;
esac

NEW_SEMVER="${major}.${minor}.${patch}"
NEW_VERSION="v${NEW_SEMVER}"

echo ""
echo "➡ Nueva versión estable: $NEW_VERSION"
echo ""
