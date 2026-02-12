#!/bin/bash
# ──────────────────────────────────────────────
# fix-encoding.sh
# Fixes broken UTF-8 characters in playbooks.
# Replaces emoji, euro signs, bullets, em-dashes
# with plain ASCII equivalents.
#
# Usage:
#   ./scripts_playbook/fix-encoding.sh           (all playbooks)
#   ./scripts_playbook/fix-encoding.sh style-test (single playbook)
# ──────────────────────────────────────────────

BLUE='\033[0;34m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PLAYBOOKS_DIR="$REPO_ROOT/playbooks"
PROCESSED=0

echo ""
echo -e "${BLUE}+-------------------------------------+${NC}"
echo -e "${BLUE}|  Scheer IDS - Fix Encoding           |${NC}"
echo -e "${BLUE}+-------------------------------------+${NC}"
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

  BEFORE=$(wc -c < "$PB_FILE")

  perl -i -pe '
    # Remove common emoji (4-byte UTF-8)
    s/\xF0\x9F[\x80-\xBF][\x80-\xBF]//g;

    # Remove mojibake emoji fragments
    s/\xC3\xB0[\xC2\x9F]?//g;

    # Euro sign
    s/\xE2\x82\xAC/EUR /g;
    s/\xC3\xA2\xC2\x82\xC2\xAC/EUR /g;

    # Bullet point
    s/\xE2\x80\xA2/- /g;
    s/\xC3\xA2\xC2\x80\xC2\xA2/- /g;

    # Em-dash
    s/\xE2\x80\x94/ - /g;
    s/\xC3\xA2\xC2\x80\xC2\x94/ - /g;

    # En-dash
    s/\xE2\x80\x93/-/g;
    s/\xC3\xA2\xC2\x80\xC2\x93/-/g;

    # Ellipsis
    s/\xE2\x80\xA6/.../g;

    # Left/right double quotes
    s/\xE2\x80\x9C/"/g;
    s/\xE2\x80\x9D/"/g;
    s/\xC3\xA2\xC2\x80[\xC2\x9C\xC2\x9D]/"/g;

    # Left/right single quotes
    s/\xE2\x80\x98/'\''/g;
    s/\xE2\x80\x99/'\''/g;

    # Non-breaking space
    s/\xC2\xA0/ /g;

    # Arrow left (used in header)
    s/\xC3\xA2\xC2\x86\xC2\x90/<-/g;
    s/\xE2\x86\x90/<-/g;

    # Checkmark
    s/\xE2\x9C\x93/*/g;
    s/\xE2\x9C\x85//g;

    # Common mojibake patterns
    s/\xC3\x83\xC2\xA2\xC3\x82\xC2\x80\xC3\x82\xC2\x9[3-4]/-/g;
    s/\xC3\x83\xC2\xA2\xC3\x82\xC2\x82\xC3\x82\xC2\xAC/EUR /g;

    # Clean up double spaces
    s/  +/ /g;
  ' "$PB_FILE" || echo -e "  ${ORANGE}! perl warning (non-fatal)${NC}"

  AFTER=$(wc -c < "$PB_FILE")
  DIFF=$((BEFORE - AFTER))

  if [ "$DIFF" -gt 0 ]; then
    echo -e "  ${GREEN}v${NC} Fixed ($DIFF bytes removed)"
  else
    echo -e "  ${GREEN}v${NC} Clean"
  fi

  PROCESSED=$((PROCESSED + 1))
done

echo ""
echo -e "${GREEN}$PROCESSED playbook(s) verwerkt.${NC}"
echo ""
echo -e "  ${BLUE}-> Open GitHub Desktop om te committen en pushen.${NC}"
echo ""
