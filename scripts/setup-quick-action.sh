#!/bin/bash
# ──────────────────────────────────────────────
# setup-quick-action.sh
# Installs a macOS Quick Action (right-click)
# and a Folder Action on the imports/ directory
#
# Run once:
#   ./scripts/setup-quick-action.sh
# ──────────────────────────────────────────────

set -e

BLUE='\033[0;34m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROCESS_SCRIPT="$SCRIPT_DIR/process-imports.sh"

echo ""
echo -e "${BLUE}┌─────────────────────────────────────────┐${NC}"
echo -e "${BLUE}│  Scheer IDS — Quick Action Installer     │${NC}"
echo -e "${BLUE}└─────────────────────────────────────────┘${NC}"
echo ""

# ── Ensure imports directory exists ──
mkdir -p "$REPO_ROOT/imports"
echo -e "${GREEN}✓${NC} imports/ directory ready"

# ── Make scripts executable ──
chmod +x "$PROCESS_SCRIPT"
chmod +x "$SCRIPT_DIR/add-playbook.sh"
echo -e "${GREEN}✓${NC} Scripts executable"

# ════════════════════════════════════════
# 1. QUICK ACTION — Right-click service
# ════════════════════════════════════════
SERVICES_DIR="$HOME/Library/Services"
WORKFLOW_NAME="Add Scheer Playbook"
WORKFLOW_DIR="$SERVICES_DIR/$WORKFLOW_NAME.workflow"

echo ""
echo -e "${BLUE}Installing Quick Action...${NC}"

mkdir -p "$SERVICES_DIR"
rm -rf "$WORKFLOW_DIR"
mkdir -p "$WORKFLOW_DIR/Contents"

# Info.plist — registers as a Finder service for HTML files
cat > "$WORKFLOW_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>NSServices</key>
	<array>
		<dict>
			<key>NSMenuItem</key>
			<dict>
				<key>default</key>
				<string>Add Scheer Playbook</string>
			</dict>
			<key>NSMessage</key>
			<string>runWorkflowAsService</string>
		</dict>
	</array>
</dict>
</plist>
PLIST

# document.wflow — the actual Automator workflow
cat > "$WORKFLOW_DIR/Contents/document.wflow" <<WFLOW
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>AMApplicationBuild</key>
	<string>523</string>
	<key>AMApplicationVersion</key>
	<string>2.10</string>
	<key>AMDocumentVersion</key>
	<string>2</string>
	<key>actions</key>
	<array>
		<dict>
			<key>action</key>
			<dict>
				<key>AMAccepts</key>
				<dict>
					<key>Container</key>
					<string>List</string>
					<key>Optional</key>
					<true/>
					<key>Types</key>
					<array>
						<string>com.apple.cocoa.string</string>
					</array>
				</dict>
				<key>AMActionVersion</key>
				<string>2.0.3</string>
				<key>AMApplication</key>
				<array>
					<string>Automator</string>
				</array>
				<key>AMLargeIconName</key>
				<string>RunShellScript</string>
				<key>AMParameterProperties</key>
				<dict>
					<key>COMMAND_STRING</key>
					<dict/>
					<key>inputMethod</key>
					<dict/>
					<key>shell</key>
					<dict/>
					<key>source</key>
					<dict/>
				</dict>
				<key>AMProvides</key>
				<dict>
					<key>Container</key>
					<string>List</string>
					<key>Types</key>
					<array>
						<string>com.apple.cocoa.string</string>
					</array>
				</dict>
				<key>ActionBundlePath</key>
				<string>/System/Library/Automator/Run Shell Script.action</string>
				<key>ActionName</key>
				<string>Run Shell Script</string>
				<key>ActionParameters</key>
				<dict>
					<key>COMMAND_STRING</key>
					<string>
# Copy dropped files to imports, then process
REPO="$REPO_ROOT"
IMPORTS="\$REPO/imports"

for f in "\$@"; do
  if [[ "\$f" == *.html ]]; then
    cp "\$f" "\$IMPORTS/"
  fi
done

open -a Terminal "\$REPO/scripts/process-imports.sh"
					</string>
					<key>CheckedForUserDefaultShell</key>
					<true/>
					<key>inputMethod</key>
					<integer>1</integer>
					<key>shell</key>
					<string>/bin/bash</string>
					<key>source</key>
					<string></string>
				</dict>
				<key>BundleIdentifier</key>
				<string>com.apple.RunShellScript</string>
				<key>CFBundleVersion</key>
				<string>2.0.3</string>
				<key>CanShowSelectedItemsWhenRun</key>
				<false/>
				<key>CanShowWhenRun</key>
				<true/>
				<key>Category</key>
				<array>
					<string>AMCategoryUtilities</string>
				</array>
				<key>Class Name</key>
				<string>RunShellScriptAction</string>
				<key>InputUUID</key>
				<string>E9B8B1A4-1234-5678-9ABC-DEF012345678</string>
				<key>Keywords</key>
				<array>
					<string>Shell</string>
					<string>Script</string>
					<string>Command</string>
					<string>Run</string>
				</array>
				<key>OutputUUID</key>
				<string>F0A1B2C3-1234-5678-9ABC-DEF012345679</string>
				<key>UUID</key>
				<string>A1B2C3D4-1234-5678-9ABC-DEF012345680</string>
				<key>UnlocalizedApplications</key>
				<array>
					<string>Automator</string>
				</array>
			</dict>
		</dict>
	</array>
	<key>connectors</key>
	<dict/>
	<key>workflowMetaData</key>
	<dict>
		<key>workflowTypeIdentifier</key>
		<string>com.apple.Automator.servicesMenu</string>
	</dict>
</dict>
</plist>
WFLOW

echo -e "${GREEN}✓${NC} Quick Action installed: '$WORKFLOW_NAME'"

# ════════════════════════════════════════
# 2. SIMPLE DOUBLE-CLICK LAUNCHER
# ════════════════════════════════════════
echo ""
echo -e "${BLUE}Creating double-click launcher...${NC}"

# Create a .command file in the repo root (double-clickable)
cat > "$REPO_ROOT/Import Playbooks.command" <<LAUNCHER
#!/bin/bash
cd "\$(dirname "\$0")"
./scripts/process-imports.sh
LAUNCHER
chmod +x "$REPO_ROOT/Import Playbooks.command"
echo -e "${GREEN}✓${NC} 'Import Playbooks.command' created (double-click to run)"

# ════════════════════════════════════════
# 3. FINDER SHORTCUT
# ════════════════════════════════════════
echo ""
echo -e "${BLUE}Creating Dock-friendly alias...${NC}"

# Create a small AppleScript app for the Dock
APP_DIR="$REPO_ROOT/Import Playbooks.app/Contents/MacOS"
mkdir -p "$APP_DIR"
mkdir -p "$REPO_ROOT/Import Playbooks.app/Contents"

cat > "$REPO_ROOT/Import Playbooks.app/Contents/MacOS/run" <<APPSCRIPT
#!/bin/bash
cd "$REPO_ROOT"
open -a Terminal "$REPO_ROOT/scripts/process-imports.sh"
APPSCRIPT
chmod +x "$REPO_ROOT/Import Playbooks.app/Contents/MacOS/run"

cat > "$REPO_ROOT/Import Playbooks.app/Contents/Info.plist" <<APPPLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>run</string>
    <key>CFBundleName</key>
    <string>Import Playbooks</string>
    <key>CFBundleIdentifier</key>
    <string>com.scheerids.import-playbooks</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
</dict>
</plist>
APPPLIST

echo -e "${GREEN}✓${NC} 'Import Playbooks.app' created (drag to Dock)"

# ════════════════════════════════════════
# 4. ADD TO .gitignore
# ════════════════════════════════════════
echo ""
GITIGNORE="$REPO_ROOT/.gitignore"
ENTRIES=(
  "imports/.processed/"
  "Import Playbooks.app/"
  "Import Playbooks.command"
  ".DS_Store"
)

touch "$GITIGNORE"
for entry in "${ENTRIES[@]}"; do
  if ! grep -qF "$entry" "$GITIGNORE" 2>/dev/null; then
    echo "$entry" >> "$GITIGNORE"
  fi
done
echo -e "${GREEN}✓${NC} .gitignore updated"

# ── Done ──
echo ""
echo -e "${GREEN}┌─────────────────────────────────────────┐${NC}"
echo -e "${GREEN}│  Setup compleet!                         │${NC}"
echo -e "${GREEN}└─────────────────────────────────────────┘${NC}"
echo ""
echo "  Je hebt nu 3 manieren om playbooks te importeren:"
echo ""
echo "  1. ${BLUE}Drag & drop${NC}"
echo "     Drop HTML in imports/ → dubbelklik 'Import Playbooks.command'"
echo ""
echo "  2. ${BLUE}Rechtermuisknop${NC} (Quick Action)"
echo "     Rechtermuisknop op HTML → Quick Actions → 'Add Scheer Playbook'"
echo ""
echo "  3. ${BLUE}Terminal${NC}"
echo "     ./scripts/process-imports.sh"
echo ""
echo "  Locatie imports map:"
echo "  $IMPORTS_DIR"
echo ""
