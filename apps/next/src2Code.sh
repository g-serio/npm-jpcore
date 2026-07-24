#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLI_ASSETS_DIR="$SCRIPT_DIR/../../packages/cli/assets"
DELIMITER="END_OF_FILE_CONTENT"

TEMPLATE_NAME=""
TARGETS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --template)
      TEMPLATE_NAME="$2"
      shift 2
      ;;
    --template=*)
      TEMPLATE_NAME="${1#*=}"
      shift
      ;;
    *)
      TARGETS+=("$1")
      shift
      ;;
  esac
done

if [ ${#TARGETS[@]} -eq 0 ]; then
  echo "Error: specify at least one folder or file target."
  echo "Example: ./src2Code.sh --template alpha src"
  exit 1
fi

if [ -z "$TEMPLATE_NAME" ]; then
  APP_DIR_NAME="$(basename "$SCRIPT_DIR")"
  TEMPLATE_NAME="${APP_DIR_NAME#tenant-}"
fi

TEMPLATE_DIR="$CLI_ASSETS_DIR/templates/$TEMPLATE_NAME"
OUTPUT_NAME="src_tenant.sh"
OUTPUT="$TEMPLATE_DIR/$OUTPUT_NAME"

mkdir -p "$TEMPLATE_DIR"

echo "Analyzing targets: ${TARGETS[*]}"
echo "Generating DNA script: $OUTPUT"

cat > "$OUTPUT" << HEADER
#!/bin/bash
set -e

echo "Starting project reconstruction..."

HEADER

find "${TARGETS[@]}" -not -path '*/.*' -not -name "$OUTPUT_NAME" -not -name "$(basename "$0")" | sort | while read -r FILE; do
  CLEAN_PATH="${FILE#./}"

  if [ -d "$FILE" ]; then
    echo "mkdir -p \"$CLEAN_PATH\"" >> "$OUTPUT"
  elif [ -f "$FILE" ]; then
    if grep -qI . "$FILE"; then
      echo "echo \"Creating $CLEAN_PATH...\"" >> "$OUTPUT"
      echo "cat << '$DELIMITER' > \"$CLEAN_PATH\"" >> "$OUTPUT"
      cat "$FILE" >> "$OUTPUT"
      echo "" >> "$OUTPUT"
      echo "$DELIMITER" >> "$OUTPUT"

      if [ -x "$FILE" ]; then
        echo "chmod +x \"$CLEAN_PATH\"" >> "$OUTPUT"
      fi
    else
      echo "# SKIP: $CLEAN_PATH is binary and cannot be embedded as text." >> "$OUTPUT"
      echo "Warning: skipped binary $CLEAN_PATH"
    fi
  fi
done

chmod +x "$OUTPUT"

SOURCE_APP="$(basename "$SCRIPT_DIR")"
cat > "$TEMPLATE_DIR/manifest.json" << MANIFEST
{
  "name": "$TEMPLATE_NAME",
  "sourceApp": "$SOURCE_APP",
  "dnaScript": "$OUTPUT_NAME"
}
MANIFEST

if [ "$TEMPLATE_NAME" = "alpha" ]; then
  cp "$OUTPUT" "$CLI_ASSETS_DIR/src_tenant_alpha.sh"
fi

echo "Done. Template DNA generated at: $OUTPUT"
echo "Manifest written at: $TEMPLATE_DIR/manifest.json"
