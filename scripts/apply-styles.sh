#!/bin/bash
# ──────────────────────────────────────────────
# apply-styles.sh
# Applies the master playbook stylesheet to
# all existing playbooks.
#
# Usage:
#   ./scripts/apply-styles.sh           (all playbooks)
#   ./scripts/apply-styles.sh branding  (single playbook)
# ──────────────────────────────────────────────

set -e

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
echo -e "${BLUE}┌─────────────────────────────────────────┐${NC}"
echo -e "${BLUE}│  Scheer IDS — Apply Master Styles        │${NC}"
echo -e "${BLUE}└─────────────────────────────────────────┘${NC}"
echo ""

if [ ! -f "$PLAYBOOKS_DIR/shared/playbook.css" ]; then
  echo -e "${RED}Error: playbooks/shared/playbook.css not found.${NC}"
  exit 1
fi

# ── Determine targets ──
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

# ── Helper: inject header after <body> using perl ──
inject_header() {
  local FILE="$1"
  local TITLE="$2"

  perl -i -0pe '
    # Only inject if not already present
    unless (m/class="pb-header"/) {
      s/(<body[^>]*>)/$1\n<!-- Scheer Playbook Header -->\n<div class="pb-header">\n  <a href="..\/..\/index.html" class="pb-header-back">\x{2190} Back to Playbooks<\/a>\n  <span class="pb-header-title">'"$TITLE"'<\/span>\n<\/div>/s;
    }
  ' "$FILE"
}

# ── Helper: inject CSS link before </head> using perl ──
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

# ══════════════════════════════════════
# Process each playbook
# ══════════════════════════════════════
for PB_ID in "${TARGETS[@]}"; do
  PB_FILE="$PLAYBOOKS_DIR/$PB_ID/index.html"

  if [ ! -f "$PB_FILE" ]; then
    echo -e "${ORANGE}⚠ $PB_ID/index.html not found — skipped${NC}"
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  echo -e "${BLUE}Processing:${NC} $PB_ID"

  # ── Get title ──
  PB_TITLE=""
  if [ -f "$PLAYBOOKS_DIR/$PB_ID/meta.json" ]; then
    PB_TITLE=$(python3 -c "import json; print(json.load(open('$PLAYBOOKS_DIR/$PB_ID/meta.json')).get('title',''))" 2>/dev/null || echo "")
  fi
  if [ -z "$PB_TITLE" ]; then
    PB_TITLE=$(grep -o '<title>[^<]*</title>' "$PB_FILE" | head -1 | sed 's/<title>//;s/<\/title>//' | xargs)
  fi

  # ── 1. CSS link ──
  if grep -q "shared/playbook.css" "$PB_FILE"; then
    echo -e "  ${GREEN}✓${NC} CSS link al aanwezig"
  else
    inject_css "$PB_FILE"
    echo -e "  ${GREEN}✓${NC} CSS link geïnjecteerd"
  fi

  # ── 2. Remove old inline-style headers ──
  if grep -q 'id="scheer-pb-header"' "$PB_FILE"; then
    perl -i -pe 's/.*id="scheer-pb-header".*\n?//' "$PB_FILE"
    echo -e "  ${GREEN}✓${NC} Oude inline header verwijderd"
  fi

  # Remove any loose inline "Back to Playbooks" links (not in a pb-header div)
  if grep -q 'Back to Playbooks' "$PB_FILE" && ! grep -q 'class="pb-header"' "$PB_FILE"; then
    perl -i -pe 's/.*Back to Playbooks.*\n?//' "$PB_FILE"
    echo -e "  ${GREEN}✓${NC} Oude back-link verwijderd"
  fi

  # ── 3. Inject standard header ──
  if grep -q 'class="pb-header"' "$PB_FILE"; then
    echo -e "  ${GREEN}✓${NC} Standaard header al aanwezig"
  else
    inject_header "$PB_FILE" "$PB_TITLE"
    echo -e "  ${GREEN}✓${NC} Standaard header geïnjecteerd"
  fi

  PROCESSED=$((PROCESSED + 1))
  echo ""
done

# ── Summary ──
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}$PROCESSED verwerkt${NC}, $SKIPPED overgeslagen"
echo ""

if [ "$PROCESSED" -gt 0 ]; then
  read -rp "Git add, commit & push? (Y/n): " DO_GIT
  if [[ ! "$DO_GIT" =~ ^[Nn]$ ]]; then
    cd "$REPO_ROOT"
    git add playbooks/
    git commit -m "style: apply master stylesheet to $PROCESSED playbook(s)"
    git push
    echo ""
    echo -e "${GREEN}✓ Pushed!${NC}"
  fi
fi

echo ""
echo -e "${BLUE}Done.${NC}"
