#!/bin/bash
# ──────────────────────────────────────────────
# process-imports.sh
# Scans the imports/ folder and converts each
# HTML file into a playbook.
#
# Usage:
#   ./scripts/process-imports.sh
#   (or trigger via Quick Action)
# ──────────────────────────────────────────────

set -e

BLUE='\033[0;34m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

# ── Find repo root ──
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
IMPORTS_DIR="$REPO_ROOT/imports"
PLAYBOOKS_DIR="$REPO_ROOT/playbooks"
PROCESSED=0

echo ""
echo -e "${BLUE}┌─────────────────────────────────────┐${NC}"
echo -e "${BLUE}│  Scheer IDS — Process Imports        │${NC}"
echo -e "${BLUE}└─────────────────────────────────────┘${NC}"
echo ""

# ── Check imports directory ──
if [ ! -d "$IMPORTS_DIR" ]; then
  echo -e "${ORANGE}Creating imports/ directory...${NC}"
  mkdir -p "$IMPORTS_DIR"
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
  echo ""
  exit 0
fi

echo -e "Gevonden: ${GREEN}${#HTML_FILES[@]}${NC} bestand(en)"
echo ""

# ── Process each file ──
for HTML_FILE in "${HTML_FILES[@]}"; do
  FILENAME=$(basename "$HTML_FILE")
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}Bestand:${NC} $FILENAME"
  echo ""

  # ── Try to extract title from HTML ──
  EXTRACTED_TITLE=$(grep -o '<title>[^<]*</title>' "$HTML_FILE" | head -1 | sed 's/<title>//;s/<\/title>//' | sed 's/Scheer IDS - //' | sed 's/ — .*$//' | xargs)

  if [ -n "$EXTRACTED_TITLE" ]; then
    echo -e "  Gevonden titel: ${GREEN}$EXTRACTED_TITLE${NC}"
  fi

  # ── Generate default ID from filename ──
  DEFAULT_ID=$(echo "$FILENAME" | sed 's/\.html$//' | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//' | sed 's/-$//')

  # ── Ask for metadata ──
  read -rp "  ID (slug) [$DEFAULT_ID]: " PB_ID
  PB_ID=${PB_ID:-$DEFAULT_ID}
  PB_ID=$(echo "$PB_ID" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g' | sed 's/--*/-/g' | sed 's/^-//' | sed 's/-$//')

  # Check if exists
  if [ -d "$PLAYBOOKS_DIR/$PB_ID" ]; then
    echo -e "  ${ORANGE}⚠ playbooks/$PB_ID/ bestaat al${NC}"
    read -rp "  Overschrijven? (y/N): " OVERWRITE
    if [[ ! "$OVERWRITE" =~ ^[Yy]$ ]]; then
      echo -e "  ${ORANGE}Overgeslagen.${NC}"
      echo ""
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

  # Copy HTML
  cp "$HTML_FILE" "$PB_DIR/index.html"
  echo -e "  ${GREEN}✓${NC} HTML → playbooks/$PB_ID/index.html"

  # ── Inject header if needed ──
  if ! grep -q "Back to Playbooks" "$PB_DIR/index.html"; then
    HEADER='<!-- Scheer Playbook Header (auto) --><div style="background:#fff;border-bottom:1px solid #dee2e6;padding:12px 20px;position:sticky;top:0;z-index:9999;font-family:Segoe UI,Tahoma,sans-serif;display:flex;align-items:center;justify-content:space-between;"><a href="../../index.html" style="color:#2996cc;text-decoration:none;font-size:13px;font-weight:600;">← Back to Playbooks</a><span style="font-size:12px;color:#6c757d;">'"$PB_TITLE"'</span></div>'

    # Inject after <body> tag
    if grep -q "<body" "$PB_DIR/index.html"; then
      sed -i '' "s|<body[^>]*>|&${HEADER}|" "$PB_DIR/index.html" 2>/dev/null || true
    fi
    echo -e "  ${GREEN}✓${NC} Header geïnjecteerd"
  else
    echo -e "  ${GREEN}✓${NC} Header al aanwezig"
  fi

  # ── Create meta.json ──
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

  # ── Move processed file to .processed ──
  mkdir -p "$IMPORTS_DIR/.processed"
  mv "$HTML_FILE" "$IMPORTS_DIR/.processed/$FILENAME"
  echo -e "  ${GREEN}✓${NC} Verplaatst naar imports/.processed/"

  PROCESSED=$((PROCESSED + 1))
  echo ""
done

# ── Summary ──
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}$PROCESSED playbook(s) verwerkt.${NC}"
echo ""

if [ "$PROCESSED" -gt 0 ]; then
  # ── Git push? ──
  read -rp "Git add, commit & push? (Y/n): " DO_GIT
  if [[ ! "$DO_GIT" =~ ^[Nn]$ ]]; then
    cd "$REPO_ROOT"
    git add playbooks/ imports/
    git commit -m "feat: add $PROCESSED new playbook(s) via import"
    git push
    echo ""
    echo -e "${GREEN}✓ Pushed!${NC} GitHub Action update registry automatisch."
  else
    echo ""
    echo "Wanneer klaar:"
    echo "  cd $REPO_ROOT"
    echo "  git add -A && git commit -m 'add playbooks' && git push"
  fi
fi

echo ""
echo -e "${BLUE}Done.${NC}"
