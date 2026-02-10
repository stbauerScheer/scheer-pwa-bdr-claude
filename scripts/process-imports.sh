#!/bin/bash
# ──────────────────────────────────────────────
# process-imports.sh
# Scans the imports/ folder and converts each
# HTML file into a styled playbook.
#
# Usage:
#   ./scripts/process-imports.sh
# ──────────────────────────────────────────────

set -e

BLUE='\033[0;34m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
IMPORTS_DIR="$REPO_ROOT/imports"
PLAYBOOKS_DIR="$REPO_ROOT/playbooks"
SHARED_CSS="../shared/playbook.css"
PROCESSED=0

echo ""
echo -e "${BLUE}┌─────────────────────────────────────┐${NC}"
echo -e "${BLUE}│  Scheer IDS — Process Imports        │${NC}"
echo -e "${BLUE}└─────────────────────────────────────┘${NC}"
echo ""

if [ ! -d "$IMPORTS_DIR" ]; then
  mkdir -p "$IMPORTS_DIR"
fi

if [ ! -f "$PLAYBOOKS_DIR/shared/playbook.css" ]; then
  echo -e "${RED}Error: playbooks/shared/playbook.css not found.${NC}"
  exit 1
fi

# ── Find HTML files ──
HTML_FILES=()
while IFS= read -r -d '' file; do
  HTML_FILES+=("$file")
done < <(find "$IMPORTS_DIR" -maxdepth 1 -name "*.html" -type f -print0 | sort -z)

if [ ${#HTML_FILES[@]} -eq 0 ]; then
  echo -e "${ORANGE}Geen HTML bestanden gevonden in imports/${NC}"
  echo "Drop je playbook HTML bestanden in:"
  echo "  $IMPORTS_DIR"
  exit 0
fi

echo -e "Gevonden: ${GREEN}${#HTML_FILES[@]}${NC} bestand(en)"
echo ""

# ── Helper: inject CSS link using perl ──
inject_css() {
  local FILE="$1"
  perl -i -pe '
    unless ($done) {
      if (s|</head>|<link rel="stylesheet" href="'"$SHARED_CSS"'">\n</head>|) {
        $done = 1;
      }
    }
  ' "$FILE"
}

# ── Helper: inject header using perl ──
inject_header() {
  local FILE="$1"
  local TITLE="$2"
  perl -i -0pe '
    s/(<body[^>]*>)/$1\n<!-- Scheer Playbook Header -->\n<div class="pb-header">\n  <a href="..\/..\/index.html" class="pb-header-back">\x{2190} Back to Playbooks<\/a>\n  <span class="pb-header-title">'"$TITLE"'<\/span>\n<\/div>/s;
  ' "$FILE"
}

# ── Process each file ──
for HTML_FILE in "${HTML_FILES[@]}"; do
  FILENAME=$(basename "$HTML_FILE")
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}Bestand:${NC} $FILENAME"
  echo ""

  # ── Extract title ──
  EXTRACTED_TITLE=$(grep -o '<title>[^<]*</title>' "$HTML_FILE" | head -1 | sed 's/<title>//;s/<\/title>//' | sed 's/Scheer IDS - //' | sed 's/ — .*$//' | xargs)
  if [ -n "$EXTRACTED_TITLE" ]; then
    echo -e "  Gevonden titel: ${GREEN}$EXTRACTED_TITLE${NC}"
  fi

  # ── Default ID from filename ──
  DEFAULT_ID=$(echo "$FILENAME" | sed 's/\.html$//' | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//' | sed 's/-$//')

  # ── Gather metadata ──
  read -rp "  ID (slug) [$DEFAULT_ID]: " PB_ID
  PB_ID=${PB_ID:-$DEFAULT_ID}
  PB_ID=$(echo "$PB_ID" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g' | sed 's/--*/-/g' | sed 's/^-//' | sed 's/-$//')

  if [ -d "$PLAYBOOKS_DIR/$PB_ID" ]; then
    echo -e "  ${ORANGE}⚠ playbooks/$PB_ID/ bestaat al${NC}"
    read -rp "  Overschrijven? (y/N): " OVERWRITE
    if [[ ! "$OVERWRITE" =~ ^[Yy]$ ]]; then
      echo -e "  ${ORANGE}Overgeslagen.${NC}"
      continue
    fi
  fi

  read -rp "  Titel [$EXTRACTED_TITLE]: " PB_TITLE
  PB_TITLE=${PB_TITLE:-$EXTRACTED_TITLE}
  if [ -z "$PB_TITLE" ]; then
    read -rp "  Titel (verplicht): " PB_TITLE
    if [ -z "$PB_TITLE" ]; then
      echo -e "  ${RED}Geen titel — overgeslagen.${NC}"
      continue
    fi
  fi

  read -rp "  Beschrijving (optioneel): " PB_DESC

  # ── Create playbook ──
  PB_DIR="$PLAYBOOKS_DIR/$PB_ID"
  mkdir -p "$PB_DIR"
  cp "$HTML_FILE" "$PB_DIR/index.html"
  echo -e "  ${GREEN}✓${NC} HTML → playbooks/$PB_ID/index.html"

  # ── 1. Inject CSS ──
  if grep -q "shared/playbook.css" "$PB_DIR/index.html"; then
    echo -e "  ${GREEN}✓${NC} CSS link al aanwezig"
  else
    inject_css "$PB_DIR/index.html"
    echo -e "  ${GREEN}✓${NC} Master CSS gelinkt"
  fi

  # ── 2. Inject header ──
  if grep -q "Back to Playbooks" "$PB_DIR/index.html"; then
    echo -e "  ${GREEN}✓${NC} Header al aanwezig"
  else
    inject_header "$PB_DIR/index.html" "$PB_TITLE"
    echo -e "  ${GREEN}✓${NC} Header geïnjecteerd"
  fi

  # ── 3. Create meta.json ──
  cat > "$PB_DIR/meta.json" <<EOF
{
  "id": "$PB_ID",
  "title": "$PB_TITLE",
  "description": "$PB_DESC",
  "status": "active",
  "path": "playbooks/$PB_ID/index.html"
}
EOF
  echo -e "  ${GREEN}✓${NC} meta.json aangemaakt"

  # ── 4. Move to processed ──
  mkdir -p "$IMPORTS_DIR/.processed"
  mv "$HTML_FILE" "$IMPORTS_DIR/.processed/$FILENAME"
  echo -e "  ${GREEN}✓${NC} → imports/.processed/"

  PROCESSED=$((PROCESSED + 1))
  echo ""
done

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}$PROCESSED playbook(s) verwerkt.${NC}"
echo ""

if [ "$PROCESSED" -gt 0 ]; then
  read -rp "Git add, commit & push? (Y/n): " DO_GIT
  if [[ ! "$DO_GIT" =~ ^[Nn]$ ]]; then
    cd "$REPO_ROOT"
    git add playbooks/ imports/
    git commit -m "feat: import $PROCESSED playbook(s) with master styling"
    git push
    echo ""
    echo -e "${GREEN}✓ Pushed!${NC} GitHub Action update registry automatisch."
  fi
fi

echo ""
echo -e "${BLUE}Done.${NC}"
