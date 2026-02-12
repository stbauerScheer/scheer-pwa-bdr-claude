#!/bin/bash
# ──────────────────────────────────────────────
# apply-styles.sh
# Applies the master playbook stylesheet to
# all existing playbooks.
#
# Push via GitHub Desktop after running.
#
# Usage:
#   ./scripts_playbook/apply-styles.sh           (all playbooks)
#   ./scripts_playbook/apply-styles.sh branding  (single playbook)
# ──────────────────────────────────────────────

BLUE='\033[0;34m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PLAYBOOKS_DIR="$REPO_ROOT/playbooks"
SHARED_CSS="../shared/playbook.css"
PROCESSED=0
SKIPPED=0

echo ""
echo -e "${BLUE}+-------------------------------------+${NC}"
echo -e "${BLUE}|  Scheer IDS - Apply Master Styles    |${NC}"
echo -e "${BLUE}+-------------------------------------+${NC}"
echo ""

if [ ! -f "$PLAYBOOKS_DIR/shared/playbook.css" ]; then
  echo -e "${RED}Error: playbooks/shared/playbook.css not found.${NC}"
  exit 1
fi

if [ -n "$1" ]; then
  TARGETS=("$1")
else
  TARGETS=()
  for dir in "$PLAYBOOKS_DIR"/*/; do
    dirname=$(basename "$dir")
    if [ "$dirname" != "shared" ] && [ -f "$dir/index.html" ]; then
      TARGETS+=("$dirname")
    fi
  done
fi

if [ ${#TARGETS[@]} -eq 0 ]; then
  echo -e "${ORANGE}Geen playbooks gevonden.${NC}"
  exit 0
fi

echo -e "Playbooks: ${GREEN}${#TARGETS[@]}${NC}"
echo ""

inject_header() {
  local FILE="$1"
  local TITLE="$2"
  perl -i -0pe '
    unless (m/class="pb-header"/) {
      s/(<body[^>]*>)/$1\n<!-- Scheer Playbook Header -->\n<div class="pb-header">\n  <a href="..\/..\/index.html" class="pb-header-back"><- Back to Playbooks<\/a>\n  <span class="pb-header-title">'"$TITLE"'<\/span>\n<\/div>/s;
    }
  ' "$FILE"
}

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

for PB_ID in "${TARGETS[@]}"; do
  PB_FILE="$PLAYBOOKS_DIR/$PB_ID/index.html"

  if [ ! -f "$PB_FILE" ]; then
    echo -e "${ORANGE}! $PB_ID/index.html not found - skipped${NC}"
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  echo -e "${BLUE}Processing:${NC} $PB_ID"

  PB_TITLE=""
  if [ -f "$PLAYBOOKS_DIR/$PB_ID/meta.json" ]; then
    PB_TITLE=$(python3 -c "import json; print(json.load(open('$PLAYBOOKS_DIR/$PB_ID/meta.json')).get('title',''))" 2>/dev/null || echo "")
  fi
  if [ -z "$PB_TITLE" ]; then
    PB_TITLE=$(grep -o '<title>[^<]*</title>' "$PB_FILE" | head -1 | sed 's/<title>//;s/<\/title>//' | xargs)
  fi

  if grep -q "shared/playbook.css" "$PB_FILE"; then
    echo -e "  ${GREEN}v${NC} CSS link al aanwezig"
  else
    inject_css "$PB_FILE"
    echo -e "  ${GREEN}v${NC} CSS link geinjecteerd"
  fi

  if grep -q 'class="pb-header"' "$PB_FILE"; then
    echo -e "  ${GREEN}v${NC} Standaard header al aanwezig"
  else
    inject_header "$PB_FILE" "$PB_TITLE"
    echo -e "  ${GREEN}v${NC} Standaard header geinjecteerd"
  fi

  PROCESSED=$((PROCESSED + 1))
  echo ""
done

echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}$PROCESSED verwerkt${NC}, $SKIPPED overgeslagen"
echo ""
if [ "$PROCESSED" -gt 0 ]; then
  echo -e "  ${BLUE}-> Open GitHub Desktop om te committen en pushen.${NC}"
fi
echo ""
