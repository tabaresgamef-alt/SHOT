#!/bin/bash

# ========================================
#  ROLLBACK STABLE VERSION FOR SHOT
#  Restaura index.html desde un snapshot
#  y ajusta version.json a la versión que tú indiques
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
# 2. Elegir snapshot para rollback
#    - Si se pasa como argumento, lo usamos
#    - Si no, mostramos una lista para elegir
# -------------------------------------------------------------
SNAPSHOT_FILE_ARG="$1"

if [[ -n "$SNAPSHOT_FILE_ARG" ]]; then
  # Se pasó un archivo por parámetro
  if [[ ! -f "$SNAPSHOT_FILE_ARG" ]]; then
    echo "❌ ERROR: El snapshot indicado no existe:"
    echo "   $SNAPSHOT_FILE_ARG"
    exit 1
  fi
  SNAPSHOT_FILE="$SNAPSHOT_FILE_ARG"
else
  echo "Buscando snapshots en $VERSIONS_DIR ..."
  mapfile -t SNAPSHOTS < <(ls -t "$VERSIONS_DIR"/dev_*_snapshot.html 2>/dev/null)

  if (( ${#SNAPSHOTS[@]} == 0 )); then
    echo "❌ ERROR: No se encontró ningún snapshot en $VERSIONS_DIR/"
    exit 1
  fi

  echo ""
  echo "Selecciona el snapshot para hacer rollback:"
  i=1
  for f in "${SNAPSHOTS[@]}"; do
    echo "  $i) $f"
    ((i++))
  done
  echo ""
  read -p "Opción (1-${#SNAPSHOTS[@]}): " OPT

  if ! [[ "$OPT" =~ ^[0-9]+$ ]] || (( OPT < 1 || OPT > ${#SNAPSHOTS[@]} )); then
    echo "❌ Opción inválida."
    exit 1
  fi

  SNAPSHOT_FILE="${SNAPSHOTS[$((OPT-1))]}"
fi

echo ""
echo "📸 Snapshot seleccionado:"
echo "   $SNAPSHOT_FILE"
echo ""

# -------------------------------------------------------------
# 3. Restaurar index.html desde snapshot
# -------------------------------------------------------------
cp "$SNAPSHOT_FILE" "$STABLE_FILE"
echo "✔ index.html restaurado desde snapshot"
echo ""

# -------------------------------------------------------------
# 4. Mostrar versión actual y preguntar nueva versión
# -------------------------------------------------------------
CURRENT_VERSION=$(jq -r '.version' "$VERSION_FILE")
CURRENT_SEMVER=$(jq -r '.semver' "$VERSION_FILE")

echo "Versión actual en version.json:"
echo "  - version : $CURRENT_VERSION"
echo "  - semver  : $CURRENT_SEMVER"
echo ""

read -p "¿Quieres actualizar también la versión en version.json? (s/n) " UPDATE_VER

if [[ "$UPDATE_VER" != "s" ]]; then
  echo ""
  echo "ℹ No se modificó version.json. Rollback de archivo completado."
else
  echo ""
  read -p "Indica a qué SemVer quieres regresar (ej: 1.0.0): " NEW_SEMVER

  # Validación simple de formato X.Y.Z
  if ! [[ "$NEW_SEMVER" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "❌ Formato inválido. Debe ser algo como 1.0.0"
    exit 1
  fi

  NEW_VERSION="v${NEW_SEMVER}"

  echo ""
  echo "➡ version.json se ajustará a: $NEW_VERSION ($NEW_SEMVER)"
  echo ""

  # -----------------------------------------------------------
  # 5. Actualizar version.json
  #   - Ajustamos version y semver
  #   - Decrementamos build.number si es posible
  #   - Añadimos entrada de rollback en el changelog
  # -----------------------------------------------------------
  jq \
    --arg newVersion "$NEW_VERSION" \
    --arg newSemver "$NEW_SEMVER" \
    --arg snapshot "$SNAPSHOT_FILE" \
    '
    .version = $newVersion
    | .semver = $newSemver
    | .status = "stable"
    | .build.number = (if .build.number > 0 then .build.number - 1 else 0 end)
    | .changelog += [{
        type: "rollback",
        targetVersion: $newVersion,
        snapshotUsed: $snapshot,
        date: (now | strftime("%Y-%m-%d %H:%M:%S"))
      }]
    ' "$VERSION_FILE" > version.tmp && mv version.tmp "$VERSION_FILE"

  echo "✔ version.json actualizado:"
  echo "   - version  = $NEW_VERSION"
  echo "   - semver   = $NEW_SEMVER"
  echo ""
fi

# -------------------------------------------------------------
# 6. Commit automático (opcional)
# -------------------------------------------------------------
echo "¿Deseas hacer commit automático del rollback? (s/n)"
read DO_COMMIT

if [[ "$DO_COMMIT" == "s" ]]; then
  git add "$STABLE_FILE" "$VERSION_FILE"
  git commit -m "Rollback estable usando snapshot ${SNAPSHOT_FILE}"
  echo "✔ Commit realizado"
else
  echo "ℹ No se realizó commit."
fi

echo ""
echo "🎉 Rollback completado."
