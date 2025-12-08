#!/bin/bash

# ========================================
#  APPLY DEV → INDEX (Versión Estable SHOT)
#  Convierte dev/dev.html en index.html
#  Limpia código DEV y aplica versión estable
#  Autor: ChatGPT + Felipe Tabares
# ========================================

DEV_FILE="dev/dev.html"
STABLE_FILE="index.html"
VERSION_FILE="version.json"
VERSIONS_DIR="versions"

mkdir -p "$VERSIONS_DIR"

echo "=== 🚀 Publicando nueva versión estable desde DEV ==="
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
# FUNCIÓN: LIMPIAR ELEMENTOS DE DEV Y PREPARAR INDEX.HTML
# -------------------------------------------------------------
clean_index_html() {
  echo "🔧 Limpiando elementos exclusivos de DEV en index.html..."

  # 1. Eliminar badge de DEV
  sed -i 's/<div id="version-badge".*<\/div>//g' "$STABLE_FILE"

  # 2. Eliminar scripts de DEV que usan rutas ../version.json
  sed -i '/fetch(\.\.\/version.json)/,/<\/script>/d' "$STABLE_FILE"

  # 3. Eliminar scripts que contienen texto "SHOT DEV"
  sed -i '/SHOT DEV/d' "$STABLE_FILE"

  # 4. Insertar badge exclusivo de versión estable SHOT
  sed -i '1i \
<div id="version-badge" style="position:fixed;bottom:10px;right:10px;background:rgba(0,0,0,0.65);color:white;padding:6px 12px;border-radius:6px;font-size:11px;z-index:9999;">SHOT | versión no disponible</div>
' "$STABLE_FILE"

  # 5. Insertar script estable para lectura de versión
  cat << 'EOF' >> "$STABLE_FILE"

<script>
(() => {
  const badge = document.getElementById('version-badge');
  if (!badge) return;

  fetch("version.json")
    .then(r => r.ok ? r.json() : null)
    .then(data => {
      const version = data?.version ?? "desconocida";
      document.title = `SHOT ${version}`;
      badge.textContent = `SHOT | ${version}`;
    })
    .catch(() => {
      document.title = "SHOT (versión desconocida)";
      badge.textContent = "SHOT | versión desconocida";
    });
})();
</script>

EOF

  echo "✔ index.html convertido correctamente en versión ESTABLE."
  echo ""
}

# -------------------------------------------------------------
# 3. Crear snapshot, AHORA CON NOMBRE DE VERSIÓN ESTABLE
# -------------------------------------------------------------
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
SNAPSHOT_FILE="${VERSIONS_DIR}/stable_${NEW_SEMVER}_${TIMESTAMP}.html"

cp "$DEV_FILE" "$SNAPSHOT_FILE"

echo "📸 Snapshot estable guardado: $SNAPSHOT_FILE"
echo ""

# -------------------------------------------------------------
# 4. Convertir dev → index y limpiar código DEV
# -------------------------------------------------------------
cp "$DEV_FILE" "$STABLE_FILE"
clean_index_html

echo "✔ index.html actualizado y limpiado como versión estable"
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
  .version = $newVersion
  | .semver = $newSemver
  | .status = "stable"
  | .build.number += 1
  | .build.date = (now | strftime("%Y-%m-%d"))
  | .changelog += [{
      type: $type,
      snapshot: $snapshot,
      version: $newVersion,
      date: (now | strftime("%Y-%m-%d %H:%M:%S"))
    }]
  ' "$VERSION_FILE" > version.tmp && mv version.tmp "$VERSION_FILE"

echo "📄 version.json actualizado:"
echo "   - version       = $NEW_VERSION"
echo "   - semver        = $NEW_SEMVER"
echo "   - snapshot      = $SNAPSHOT_FILE"
echo "   - tipo cambio   = $TYPE"
echo ""

# -------------------------------------------------------------
# 6. Commit automático
# -------------------------------------------------------------
echo "¿Deseas hacer commit automático? (s/n)"
read DO_COMMIT

if [[ "$DO_COMMIT" == "s" ]]; then
  git add "$STABLE_FILE" "$VERSION_FILE" "$SNAPSHOT_FILE"
  git commit -m "Publicada versión estable ${NEW_VERSION} (tipo: ${TYPE})"
  echo "✔ Commit realizado"
else
  echo "ℹ Commit no realizado."
fi

echo ""
echo "🎉 Publicación completada. Nueva versión estable: $NEW_VERSION"
