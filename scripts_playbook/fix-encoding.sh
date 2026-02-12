#!/bin/bash
# ──────────────────────────────────────────────
# fix-encoding.sh
# Fixes broken UTF-8 characters in playbooks.
# Replaces emoji, euro signs, bullets, em-dashes
# with plain ASCII equivalents.
#
# Usage:
#   ./scripts/fix-encoding.sh           (all playbooks)
#   ./scripts/fix-encoding.sh style-test (single playbook)
# ──────────────────────────────────────────────

set -e

BLUE='\033[0;34m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PLAYBOOKS_DIR="$REPO_ROOT/playbooks"
PROCESSED=0

echo ""
echo -e "${BLUE}┌─────────────────────────────────────────┐${NC}"
echo -e "${BLUE}│  Scheer IDS — Fix Encoding               │${NC}"
echo -e "${BLUE}└─────────────────────────────────────────┘${NC}"
echo ""

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

echo -e "Playbooks: ${GREEN}${#TARGETS[@]}${NC}"
echo ""

for PB_ID in "${TARGETS[@]}"; do
  PB_FILE="$PLAYBOOKS_DIR/$PB_ID/index.html"

  if [ ! -f "$PB_FILE" ]; then
    continue
  fi

  echo -e "${BLUE}Processing:${NC} $PB_ID"

  # Count replacements
  BEFORE=$(wc -c < "$PB_FILE")

  perl -i -pe '
    # ── Emoji (multi-byte UTF-8 mojibake) ──
    # Target/bullseye
    s/\xF0\x9F\x8E\xAF//g;
    s/ð\x9F\x8E\xAF//g;
    s/ð¯//g;

    # Floppy disk / save
    s/\xF0\x9F\x92\xBE//g;
    s/ð¾//g;

    # Wastebasket / trash
    s/\xF0\x9F\x97\x91\xEF\xB8\x8F//g;
    s/ðï¸//g;
    s/ð\x9F\x97\x91//g;

    # Rocket
    s/\xF0\x9F\x9A\x80//g;
    s/ð\x9F\x9A\x80//g;

    # Star / sparkles
    s/\xF0\x9F\x8C\x9F//g;
    s/â¨//g;
    s/\xE2\x9C\xA8//g;

    # Check mark
    s/\xE2\x9C\x85//g;
    s/â//g;
    s/\xE2\x9C\x93/*/g;

    # Warning sign
    s/\xE2\x9A\xA0\xEF\xB8\x8F//g;
    s/â ï¸//g;

    # Fire
    s/\xF0\x9F\x94\xA5//g;

    # Chart / graph
    s/\xF0\x9F\x93\x88//g;
    s/\xF0\x9F\x93\x8A//g;

    # Light bulb
    s/\xF0\x9F\x92\xA1//g;

    # Handshake
    s/\xF0\x9F\xA4\x9D//g;

    # Trophy
    s/\xF0\x9F\x8F\x86//g;

    # Phone
    s/\xF0\x9F\x93\x9E//g;
    s/\xF0\x9F\x93\xB1//g;

    # Mail
    s/\xF0\x9F\x93\xA7//g;

    # Pin / pushpin
    s/\xF0\x9F\x93\x8C//g;

    # Globe
    s/\xF0\x9F\x8C\x8D//g;
    s/\xF0\x9F\x8C\x90//g;

    # Building
    s/\xF0\x9F\x8F\xA2//g;

    # People
    s/\xF0\x9F\x91\xA5//g;

    # Money
    s/\xF0\x9F\x92\xB0//g;
    s/\xF0\x9F\x92\xB5//g;

    # Arrow right
    s/\xE2\x9E\xA1\xEF\xB8\x8F/->/g;
    s/â¡ï¸/->/g;

    # Catch-all: any remaining 4-byte emoji (F0 9F xx xx)
    s/\xF0\x9F[\x80-\xBF][\x80-\xBF]//g;

    # ── Special characters ──
    # Euro sign (real UTF-8)
    s/\xE2\x82\xAC/EUR /g;

    # Euro sign (mojibake variants)
    s/â¬/EUR /g;

    # Bullet point (real UTF-8)
    s/\xE2\x80\xA2/- /g;

    # Bullet point (mojibake)
    s/â¢/- /g;

    # Em-dash (real UTF-8)
    s/\xE2\x80\x94/ - /g;

    # Em-dash (mojibake)
    s/â/ - /g;

    # En-dash (real UTF-8)
    s/\xE2\x80\x93/-/g;

    # En-dash (mojibake)
    s/â/-/g;

    # Ellipsis
    s/\xE2\x80\xA6/.../g;
    s/â¦/.../g;

    # Left/right double quotes
    s/\xE2\x80\x9C/"/g;
    s/\xE2\x80\x9D/"/g;
    s/â\x9C/"/g;
    s/â\x9D/"/g;
    s/[""]/"/g;

    # Left/right single quotes
    s/\xE2\x80\x98/'\''/g;
    s/\xE2\x80\x99/'\''/g;
    s/['']/'\'''/g;

    # Non-breaking space
    s/\xC2\xA0/ /g;

    # Clean up double spaces left by emoji removal
    s/  +/ /g;

    # Clean up empty lines with just spaces
    s/^\s+$//;
  ' "$PB_FILE"

  AFTER=$(wc -c < "$PB_FILE")
  DIFF=$((BEFORE - AFTER))

  if [ "$DIFF" -gt 0 ]; then
    echo -e "  ${GREEN}✓${NC} Fixed ($DIFF bytes removed)"
  else
    echo -e "  ${GREEN}✓${NC} No issues found"
  fi

  PROCESSED=$((PROCESSED + 1))
done

echo ""
echo -e "${GREEN}$PROCESSED playbook(s) verwerkt.${NC}"
echo ""
echo -e "  ${BLUE}-> Open GitHub Desktop om te committen en pushen.${NC}"
echo ""
