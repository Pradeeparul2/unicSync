#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Resolve where the bundle files are located
if [ -d "$SCRIPT_DIR/build/linux/x64/release/bundle" ]; then
    BUNDLE_SRC="$SCRIPT_DIR/build/linux/x64/release/bundle"
elif [ -d "$SCRIPT_DIR/../build/linux/x64/release/bundle" ]; then
    BUNDLE_SRC="$SCRIPT_DIR/../build/linux/x64/release/bundle"
elif [ -d "$SCRIPT_DIR/bundle" ]; then
    BUNDLE_SRC="$SCRIPT_DIR/bundle"
elif [ -f "$SCRIPT_DIR/unic_sync" ]; then
    BUNDLE_SRC="$SCRIPT_DIR"
else
    echo "Error: Could not locate unicSync release bundle."
    exit 1
fi

# Check if user requested system-wide or running as root
IS_SYSTEM=0
if [ "${1:-}" = "--system" ] || [ "$(id -u)" -eq 0 ]; then
    IS_SYSTEM=1
fi

if [ "$IS_SYSTEM" -eq 1 ]; then
    INSTALL_DIR="/opt/unicsync"
    BIN_DIR="/usr/local/bin"
    APPS_DIR="/usr/share/applications"
    ICON_DIR="/usr/share/icons/hicolor/256x256/apps"
    PIXMAP_DIR="/usr/share/pixmaps"
    echo "==> Installing unicSync system-wide (requires root)..."
else
    INSTALL_DIR="$HOME/.local/share/unicsync"
    BIN_DIR="$HOME/.local/bin"
    APPS_DIR="$HOME/.local/share/applications"
    ICON_DIR="$HOME/.local/share/icons/hicolor/256x256/apps"
    PIXMAP_DIR="$HOME/.local/share/pixmaps"
    echo "==> Installing unicSync for current user ($USER)..."
fi

mkdir -p "$INSTALL_DIR"
mkdir -p "$BIN_DIR"
mkdir -p "$APPS_DIR"
mkdir -p "$ICON_DIR"
mkdir -p "$PIXMAP_DIR"

echo "==> Copying application bundle to $INSTALL_DIR..."
cp -r "$BUNDLE_SRC"/* "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/unic_sync"

# Ensure bundled engine binary has execute permissions
if [ -f "$INSTALL_DIR/data/flutter_assets/assets/bin/sync-agent" ]; then
    chmod +x "$INSTALL_DIR/data/flutter_assets/assets/bin/sync-agent"
fi

echo "==> Creating binary symlink in $BIN_DIR/unic_sync..."
ln -sf "$INSTALL_DIR/unic_sync" "$BIN_DIR/unic_sync"

echo "==> Installing desktop application icons..."
ICON_SRC=""
if [ -f "$BUNDLE_SRC/unicsync_icon_256.png" ]; then
    ICON_SRC="$BUNDLE_SRC/unicsync_icon_256.png"
elif [ -f "$SCRIPT_DIR/../assets/images/unicsync_icon_256.png" ]; then
    ICON_SRC="$SCRIPT_DIR/../assets/images/unicsync_icon_256.png"
elif [ -f "$INSTALL_DIR/data/flutter_assets/assets/images/unicsync_icon_256.png" ]; then
    ICON_SRC="$INSTALL_DIR/data/flutter_assets/assets/images/unicsync_icon_256.png"
fi

if [ -n "$ICON_SRC" ]; then
    cp "$ICON_SRC" "$ICON_DIR/unicsync.png"
    cp "$ICON_SRC" "$PIXMAP_DIR/unicsync.png"
fi

echo "==> Registering Desktop Launcher Entry..."
cat << EOF > "$APPS_DIR/unicsync.desktop"
[Desktop Entry]
Name=unicSync
GenericName=Cloud Sync Client
Comment=Standalone desktop cloud sync application powered by the uSync engine
Exec=$INSTALL_DIR/unic_sync %U
Icon=unicsync
Terminal=false
Type=Application
Categories=Utility;Network;FileTransfer;
StartupNotify=true
StartupWMClass=unic_sync
Keywords=sync;cloud;backup;s3;gdrive;webdav;
EOF
chmod 644 "$APPS_DIR/unicsync.desktop"

# Update Linux desktop database and icon cache
if command -v update-desktop-database > /dev/null 2>&1; then
    update-desktop-database "$APPS_DIR" 2>/dev/null || true
fi
if command -v gtk-update-icon-cache > /dev/null 2>&1; then
    gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor" 2>/dev/null || true
    if [ "$IS_SYSTEM" -eq 1 ]; then
        gtk-update-icon-cache -f -t "/usr/share/icons/hicolor" 2>/dev/null || true
    fi
fi

echo ""
echo "=================================================="
echo "  unicSync v1.0.0 installed successfully!         "
echo "=================================================="
echo "Executable: $INSTALL_DIR/unic_sync"
echo "Command:    unic_sync (via $BIN_DIR)"
echo "Launcher:   $APPS_DIR/unicsync.desktop"
echo ""
echo "You can now launch 'unicSync' directly from your application launcher / dash!"
