#!/bin/bash
# ──────────────────────────────────────────────
# add-playbook.sh
# Adds a new playbook to the Scheer IDS environment
#
# Usage:
#   ./add-playbook.sh path/to/your-file.html
#   or drag & drop the HTML file onto this script
# ──────────────────────────────────────────────

set -e

# ── Colors for terminal output ──
BLUE='\033[0;34m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

echo ""
echo -e "${BLUE}┌─────────────────────────────────────┐${NC}"
echo -e "${BLUE}│  Scheer IDS — Add Playbook           │${NC}"
echo -e "${BLUE}└─────────────────────────────────────┘${NC}"
echo ""

# ── Find repo root ──
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
if [ -z "$REPO_ROOT" ]; then
  echo -e "${RED}Error: Not inside a git repository.${NC}"
  echo "Run this script from within your Scheer IDS repo."
  exit 1
fi

PLAYBOOKS_DIR="$REPO_ROOT/playbooks"
mkdir -p "$PLAYBOOKS_DIR"

# ── Check for input file ──
HTML_FILE="$1"

if [ -z "$HTML_FILE" ]; then
  echo -e "${ORANGE}No file provided. Drag & drop an HTML file here and press Enter:${NC}"
  read -r HTML_FILE
  # Strip quotes that macOS might add
  HTML_FILE=$(echo "$HTML_FILE" | sed "s/^'//" | sed "s/'$//" | sed 's/^ //')
fi

if [ ! -f "$HTML_FILE" ]; then
  echo -e "${RED}Error: File not found: $HTML_FILE${NC}"
  exit 1
fi

echo -e "${GREEN}✓${NC} File: $(basename "$HTML_FILE")"
echo ""

# ── Gather metadata ──
read -rp "Playbook ID (slug, e.g. 'battlecards'): " PB_ID
if [ -z "$PB_ID" ]; then
  echo -e "${RED}Error: ID is required.${NC}"
  exit 1
fi

# Sanitize: lowercase, hyphens only
PB_ID=$(echo "$PB_ID" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g' | sed 's/--*/-/g' | sed 's/^-//' | sed 's/-$//')

# Check if already exists
if [ -d "$PLAYBOOKS_DIR/$PB_ID" ]; then
  echo -e "${ORANGE}Warning: playbooks/$PB_ID/ already exists.${NC}"
  read -rp "Overwrite? (y/N): " OVERWRITE
  if [[ ! "$OVERWRITE" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
  fi
fi

read -rp "Title (e.g. 'Competitive Battlecards'): " PB_TITLE
if [ -z "$PB_TITLE" ]; then
  echo -e "${RED}Error: Title is required.${NC}"
  exit 1
fi

read -rp "Description (short, optional): " PB_DESC

echo ""
echo -e "${BLUE}Creating playbook...${NC}"

# ── Create directory ──
PB_DIR="$PLAYBOOKS_DIR/$PB_ID"
mkdir -p "$PB_DIR"

# ── Copy HTML ──
cp "$HTML_FILE" "$PB_DIR/index.html"
echo -e "${GREEN}✓${NC} Copied HTML → playbooks/$PB_ID/index.html"

# ── Inject playbook header if not present ──
if ! grep -q "Back to Playbooks" "$PB_DIR/index.html"; then
  echo -e "${BLUE}  Injecting playbook header...${NC}"

  # Build the header HTML block
  HEADER_BLOCK=$(cat <<'HEADEREOF'
<!-- Scheer IDS Playbook Header (auto-injected) -->
<div id="scheer-pb-header" style="
  background: #ffffff;
  border-bottom: 1px solid #dee2e6;
  padding: 12px 20px;
  position: sticky;
  top: 0;
  z-index: 9999;
  font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
  display: flex;
  align-items: center;
  justify-content: space-between;
">
  <a href="../../index.html" style="
    color: #2996cc;
    text-decoration: none;
    font-size: 13px;
    font-weight: 600;
    display: inline-flex;
    align-items: center;
    gap: 4px;
  ">← Back to Playbooks</a>
  <span style="font-size: 12px; color: #6c757d;">__PB_TITLE__</span>
</div>
HEADEREOF
)

  # Replace placeholder with actual title
  HEADER_BLOCK="${HEADER_BLOCK//__PB_TITLE__/$PB_TITLE}"

  # Inject after <body> tag
  if grep -q "<body" "$PB_DIR/index.html"; then
    # Use perl for reliable multiline replacement (macOS compatible)
    perl -i -pe "s/(<body[^>]*>)/\$1\n$( echo "$HEADER_BLOCK" | sed 's/[\/&]/\\&/g' | tr '\n' '\x00' | sed 's/\x00/\\n/g' )/" "$PB_DIR/index.html" 2>/dev/null || {
      # Fallback: simpler sed approach
      sed -i '' "s|<body>|<body>\n$(echo "$HEADER_BLOCK" | tr '\n' ' ')|" "$PB_DIR/index.html" 2>/dev/null || {
        # Last resort: prepend to file
        TEMP=$(mktemp)
        echo "$HEADER_BLOCK" > "$TEMP"
        cat "$PB_DIR/index.html" >> "$TEMP"
        mv "$TEMP" "$PB_DIR/index.html"
      }
    }
    echo -e "${GREEN}✓${NC} Header injected"
  else
    echo -e "${ORANGE}⚠${NC} No <body> tag found — header prepended to file"
    TEMP=$(mktemp)
    echo "$HEADER_BLOCK" > "$TEMP"
    cat "$PB_DIR/index.html" >> "$TEMP"
    mv "$TEMP" "$PB_DIR/index.html"
  fi
else
  echo -e "${GREEN}✓${NC} Header already present — skipped injection"
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
echo -e "${GREEN}✓${NC} Created meta.json"

# ── Summary ──
echo ""
echo -e "${GREEN}┌─────────────────────────────────────┐${NC}"
echo -e "${GREEN}│  Playbook ready!                     │${NC}"
echo -e "${GREEN}└─────────────────────────────────────┘${NC}"
echo ""
echo "  playbooks/$PB_ID/"
echo "  ├── index.html"
echo "  └── meta.json"
echo ""

# ── Git push? ──
read -rp "Git add, commit & push now? (Y/n): " DO_GIT
if [[ ! "$DO_GIT" =~ ^[Nn]$ ]]; then
  cd "$REPO_ROOT"
  git add "playbooks/$PB_ID/"
  git commit -m "feat: add playbook '$PB_TITLE'"
  git push
  echo ""
  echo -e "${GREEN}✓ Pushed!${NC} GitHub Action will update registry.json automatically."
else
  echo ""
  echo "When ready, run:"
  echo "  git add playbooks/$PB_ID/"
  echo "  git commit -m \"feat: add playbook '$PB_TITLE'\""
  echo "  git push"
fi

echo ""
echo -e "${BLUE}Done.${NC}"
