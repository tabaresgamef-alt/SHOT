#!/bin/bash

# ========================================
#  ROLLBACK STABLE VERSION FOR SHOT
#  Restaura index.html desde un snapshot estable
#  Repara version.json y limpia elementos DEV
#  Autor: ChatGPT + Felipe Tabares
# ========================================

VERSION_FILE="version.json"
STABLE_FILE="index.html"
VERSIONS_DIR="versions"

echo "=== 🔄 Iniciando rollback de versión estable ==="
echo ""

# -------------------------------------------------------------
# 1. Validar archivos base
# -------------------------------------------------------------
if [[ ! -f "$VERSION_FILE" ]]; then
  echo "❌ ERROR: No existe version.json"
  exit 1
fi

if [[ ! -f "$STABLE_FILE" ]]; then
  echo "❌ ERROR: No existe index.html"
  exit 1
fi

if [[ ! -d "$VERSIONS_DIR" ]]; then
  echo "❌ ERROR: No existe el directorio $VERSIONS_DIR"
  exit 1
fi


# -------------------------------------------------------------
# 2. Resolver snapshot desde argumento o menú
# -------------------------------------------------------------
if [[ -n "$1" ]]; then
    SNAPSHOT="$1"
    if [[ ! -f "$SNAPSHOT" ]]; then
        echo "❌ ERROR: El snapshot indicado no existe."
        exit 1
    fi
else
    echo "Buscando snapshots estables en $VERSIONS_DIR..."

    mapfile -t SNAPSHOTS < <(ls -t "$VERSIONS_DIR"/stable_*.html 2>/dev/null)

    if (( ${#SNAPSHOTS[@]} == 0 )); then
        echo "❌ ERROR: No existe ningún snapshot estable."
        exit 1
    fi

    echo ""
    echo "Selecciona el snapshot a restaurar:"
    idx=1
    for f in "${SNAPSHOTS[@]}"; do
        echo "  $idx) $f"
        ((idx++))
    done

    echo ""
    read -p "Opción (1-${#SNAPSHOTS[@]}): " OPT

    if (( OPT < 1 || OPT > ${#SNAPSHOTS[@]} )); then
        echo "❌ Opción inválida."
        exit 1
    fi

    SNAPSHOT="${SNAPSHOTS[$((OPT-1))]}"
fi

echo ""
echo "📸 Snapshot seleccionado:"
echo "   $SNAPSHOT"
echo ""

# -------------------------------------------------------------
# 3. Extraer semver desde el nombre del archivo
# -------------------------------------------------------------
SNAPSHOT_BASENAME=$(basename "$SNAPSHOT")

SEMVER_FROM_FILE=$(echo "$SNAPSHOT_BASENAME" | sed -E 's/stable_([0-9]+\.[0-9]+\.[0-9]+)_.*/\1/')

if [[ -z "$SEMVER_FROM_FILE" ]]; then
    echo "❌ ERROR: No se pudo extraer SemVer del snapshot."
    exit 1
fi

NEW_SEMVER="$SEMVER_FROM_FILE"
NEW_VERSION="v${NEW_SEMVER}"

echo "➡ Versión detectada desde snapshot: $NEW_VERSION"
echo ""


# -------------------------------------------------------------
# 4. Restaurar index.html desde snapshot
# -------------------------------------------------------------
cp "$SNAPSHOT" "$STABLE_FILE"
echo "✔ index.html restaurado desde snapshot"
echo ""


# -------------------------------------------------------------
# 5. Limpiar elementos DEV y reinstalar scripts de versión estable
# -------------------------------------------------------------
echo "🔧 Limpiando elementos DEV y normalizando index.html..."

# Eliminar badges previos
sed -i 's/<div id="version-badge".*<\/div>//g' "$STABLE_FILE"

# Eliminar scripts DEV (fetch "../version.json")
sed -i '/fetch(\.\.\/version.json)/,/<\/script>/d' "$STABLE_FILE"

# Eliminar textos SHOT DEV
sed -i '/SHOT DEV/d' "$STABLE_FILE"

# Insertar badge estable
sed -i '1i \
<div id="version-badge" style="position:fixed;bottom:10px;right:10px;background:rgba(0,0,0,0.7);color:white;padding:6px 12px;border-radius:6px;font-size:11px;z-index:9999;">SHOT | versión no disponible</div>
' "$STABLE_FILE"

# Insertar script estable para leer versión
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

echo "✔ index.html ahora está 100% corregido como versión estable"
echo ""


# -------------------------------------------------------------
# 6. Actualizar version.json de forma segura
# -------------------------------------------------------------
echo "🔧 Ajustando version.json..."

jq \
  --arg newVersion "$NEW_VERSION" \
  --arg newSemver "$NEW_SEMVER" \
  --arg snapshot "$SNAPSHOT" \
  '
  .version = $newVersion
  | .semver = $newSemver
  | .status = "stable"
  | .build.number = (if .build.number > 0 then .build.number - 1 else 0 end)
  | .changelog |= map(select(.snapshot != $snapshot))
  ' "$VERSION_FILE" > version.tmp && mv version.tmp "$VERSION_FILE"

echo "✔ version.json actualizado:"
echo "   - version  = $NEW_VERSION"
echo "   - semver   = $NEW_SEMVER"
echo ""


# -------------------------------------------------------------
# 7. Commit automático
# -------------------------------------------------------------
echo "¿Deseas hacer commit automático del rollback? (s/n)"
read DO_COMMIT

if [[ "$DO_COMMIT" == "s" ]]; then
    git add "$STABLE_FILE" "$VERSION_FILE"
    git commit -m "Rollback estable restaurado desde snapshot $SNAPSHOT"
    echo "✔ Commit realizado"
else
    echo "ℹ No se realizó commit automático."
fi

echo ""
echo "🎉 Rollback estable completado correctamente."
