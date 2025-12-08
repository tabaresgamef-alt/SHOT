#!/bin/bash

# ========================================
#  ROLLBACK STABLE VERSION FOR SHOT
#  Restaura index.html desde un snapshot estable
#  y ajusta version.json automáticamente
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

if [[ ! -d "$VERSIONS_DIR" ]]; then
  echo "❌ ERROR: No existe el directorio $VERSIONS_DIR"
  exit 1
fi

# -------------------------------------------------------------
# 2. Resolver snapshot desde argumento o lista
# -------------------------------------------------------------
if [[ -n "$1" ]]; then
  SNAPSHOT="$1"
  if [[ ! -f "$SNAPSHOT" ]]; then
    echo "❌ ERROR: El snapshot indicado no existe"
    exit 1
  fi
else
  echo "Buscando snapshots estables en $VERSIONS_DIR ..."

  mapfile -t SNAPSHOTS < <(ls -t "$VERSIONS_DIR"/stable_*.html 2>/dev/null)

  if (( ${#SNAPSHOTS[@]} == 0 )); then
    echo "❌ ERROR: No existe ningún snapshot estable"
    exit 1
  fi

  echo ""
  echo "Selecciona snapshot a restaurar:"
  idx=1
  for f in "${SNAPSHOTS[@]}"; do
    echo "  $idx) $f"
    ((idx++))
  done

  echo ""
  read -p "Opción (1-${#SNAPSHOTS[@]}): " OPT

  if (( OPT < 1 || OPT > ${#SNAPSHOTS[@]} )); then
    echo "❌ Opción inválida"
    exit 1
  fi

  SNAPSHOT="${SNAPSHOTS[$((OPT-1))]}"
fi

echo ""
echo "📸 Snapshot seleccionado:"
echo "  $SNAPSHOT"
echo ""

# -------------------------------------------------------------
# 3. Extraer versión del snapshot
#     Ejemplo archivo:
#       stable_2.0.0_20251207_032754.html
#     Extraemos: 2.0.0
# -------------------------------------------------------------
SNAPSHOT_BASENAME=$(basename "$SNAPSHOT")
SEMVER_FROM_FILE=$(echo "$SNAPSHOT_BASENAME" | sed -E 's/stable_([0-9]+\.[0-9]+\.[0-9]+)_.*/\1/')

if [[ -z "$SEMVER_FROM_FILE" ]]; then
  echo "❌ ERROR: No se pudo extraer versión del snapshot."
  exit 1
fi

NEW_SEMVER="$SEMVER_FROM_FILE"
NEW_VERSION="v${NEW_SEMVER}"

echo "➡ Versión detectada del snapshot: $NEW_VERSION"
echo ""

# -------------------------------------------------------------
# 4. Restaurar index.html
# -------------------------------------------------------------
cp "$SNAPSHOT" "$STABLE_FILE"
echo "✔ index.html restaurado"
echo ""

# -------------------------------------------------------------
# 5. Actualizar version.json automáticamente
# -------------------------------------------------------------
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

echo "✔ version.json ajustado automáticamente:"
echo "   - version = $NEW_VERSION"
echo "   - semver  = $NEW_SEMVER"
echo ""

# -------------------------------------------------------------
# 6. Commit automático
# -------------------------------------------------------------
echo "¿Deseas hacer commit automático del rollback? (s/n)"
read DO_COMMIT

if [[ "$DO_COMMIT" == "s" ]]; then
  git add "$STABLE_FILE" "$VERSION_FILE"
  git commit -m "Rollback estable restaurado desde snapshot $SNAPSHOT"
  echo "✔ Commit realizado"
else
  echo "ℹ No se realizó commit."
fi

echo ""
echo "🎉 Rollback de versión estable completado."
