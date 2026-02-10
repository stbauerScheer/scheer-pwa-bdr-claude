#!/bin/bash
# ──────────────────────────────────────────────
# apply-styles.sh
# Applies the master playbook stylesheet to
# all existing playbooks.
#
# What it does:
#   1. Injects <link> to shared/playbook.css
#   2. Standardizes the "Back to Playbooks" header
#   3. Removes inline styles that conflict
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

# ── Check shared CSS exists ──
if [ ! -f "$PLAYBOOKS_DIR/shared/playbook.css" ]; then
  echo -e "${RED}Error: playbooks/shared/playbook.css not found.${NC}"
  exit 1
fi

# ── Determine target(s) ──
if [ -n "$1" ]; then
  # Single playbook
  TARGETS=("$1")
else
  # All playbooks (exclude 'shared' directory)
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

  # ── Get title from meta.json ──
  PB_TITLE=""
  if [ -f "$PLAYBOOKS_DIR/$PB_ID/meta.json" ]; then
    PB_TITLE=$(python3 -c "import json; print(json.load(open('$PLAYBOOKS_DIR/$PB_ID/meta.json')).get('title',''))" 2>/dev/null || echo "")
  fi
  if [ -z "$PB_TITLE" ]; then
    PB_TITLE=$(grep -o '<title>[^<]*</title>' "$PB_FILE" | head -1 | sed 's/<title>//;s/<\/title>//' | xargs)
  fi

  # ── Backup ──
  cp "$PB_FILE" "$PB_FILE.bak"

  # ════════════════════════════════
  # 1. INJECT CSS LINK
  # ════════════════════════════════
  if grep -q "shared/playbook.css" "$PB_FILE"; then
    echo -e "  ${GREEN}✓${NC} CSS link al aanwezig"
  else
    # Insert after <head> or after last <meta> tag
    if grep -q "</head>" "$PB_FILE"; then
      sed -i '' "s|</head>|<link rel=\"stylesheet\" href=\"$SHARED_CSS\">\n</head>|" "$PB_FILE"
      echo -e "  ${GREEN}✓${NC} CSS link geïnjecteerd"
    else
      echo -e "  ${ORANGE}⚠${NC} Geen </head> gevonden — CSS link niet toegevoegd"
    fi
  fi

  # ════════════════════════════════
  # 2. STANDARDIZE HEADER
  # ════════════════════════════════
  # Remove any old inline-style header injections
  if grep -q 'id="scheer-pb-header"' "$PB_FILE"; then
    # Remove the old auto-injected inline header (single line)
    sed -i '' '/id="scheer-pb-header"/d' "$PB_FILE"
    echo -e "  ${GREEN}✓${NC} Oude inline header verwijderd"
  fi

  # Check if there's already a proper pb-header
  if grep -q 'class="pb-header"' "$PB_FILE"; then
    echo -e "  ${GREEN}✓${NC} Standaard header al aanwezig"
  else
    # Build the new standard header using CSS classes (no inline styles)
    HEADER_HTML='<!-- Scheer Playbook Header --><div class="pb-header"><a href="../../index.html" class="pb-header-back">← Back to Playbooks</a><span class="pb-header-title">'"$PB_TITLE"'</span></div>'

    # Remove any existing "Back to Playbooks" links that use inline styles
    sed -i '' '/Back to Playbooks/d' "$PB_FILE"

    # Inject after <body>
    if grep -q "<body" "$PB_FILE"; then
      sed -i '' "s|<body[^>]*>|&${HEADER_HTML}|" "$PB_FILE"
      echo -e "  ${GREEN}✓${NC} Standaard header geïnjecteerd"
    fi
  fi

  # ════════════════════════════════
  # 3. REMOVE CONFLICTING INLINE CSS
  # ════════════════════════════════
  # We don't remove all <style> blocks (playbooks may have unique styles)
  # Instead we remove specific inline declarations that the master CSS handles

  # Remove inline body margin:0 (handled by master)
  sed -i '' 's/body{margin:0;/body{/' "$PB_FILE" 2>/dev/null || true

  # Remove backup
  rm -f "$PB_FILE.bak"

  PROCESSED=$((PROCESSED + 1))
  echo ""
done

# ── Summary ──
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}$PROCESSED verwerkt${NC}, $SKIPPED overgeslagen"
echo ""

# ── Git? ──
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
