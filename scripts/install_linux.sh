#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Resolve where the bundle files are located
if [ -d "$SCRIPT_DIR/build/linux/x64/release/bundle" ]; then
    BUNDLE_SRC="$SCRIPT_DIR/build/linux/x64/release/bundle"
elif [ -d "$PROJECT_ROOT/build/linux/x64/release/bundle" ]; then
    BUNDLE_SRC="$PROJECT_ROOT/build/linux/x64/release/bundle"
elif [ -d "$PROJECT_ROOT/build/linux/x64/debug/bundle" ]; then
    BUNDLE_SRC="$PROJECT_ROOT/build/linux/x64/debug/bundle"
elif [ -d "$SCRIPT_DIR/bundle" ]; then
    BUNDLE_SRC="$SCRIPT_DIR/bundle"
elif [ -f "$SCRIPT_DIR/unic_sync" ]; then
    BUNDLE_SRC="$SCRIPT_DIR"
else
    echo "Error: Could not locate unicSync bundle."
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
    ICON_BASE="/usr/share/icons/hicolor"
    PIXMAP_DIR="/usr/share/pixmaps"
    echo "==> Installing unicSync system-wide (requires root)..."
else
    INSTALL_DIR="$HOME/.local/share/unicsync"
    BIN_DIR="$HOME/.local/bin"
    APPS_DIR="$HOME/.local/share/applications"
    ICON_BASE="$HOME/.local/share/icons/hicolor"
    PIXMAP_DIR="$HOME/.local/share/pixmaps"
    echo "==> Installing unicSync for current user ($USER)..."
fi

mkdir -p "$INSTALL_DIR"
mkdir -p "$BIN_DIR"
mkdir -p "$APPS_DIR"
mkdir -p "$ICON_BASE/256x256/apps"
mkdir -p "$ICON_BASE/128x128/apps"
mkdir -p "$ICON_BASE/64x64/apps"
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

echo "==> Installing multi-resolution desktop application icons..."
find_icon() {
    local filename="$1"
    if [ -f "$BUNDLE_SRC/data/flutter_assets/assets/images/$filename" ]; then
        echo "$BUNDLE_SRC/data/flutter_assets/assets/images/$filename"
    elif [ -f "$PROJECT_ROOT/assets/images/$filename" ]; then
        echo "$PROJECT_ROOT/assets/images/$filename"
    elif [ -f "$INSTALL_DIR/data/flutter_assets/assets/images/$filename" ]; then
        echo "$INSTALL_DIR/data/flutter_assets/assets/images/$filename"
    else
        echo ""
    fi
}

ICON_256="$(find_icon "unicsync_icon_256.png")"
ICON_128="$(find_icon "unicsync_icon_128.png")"
ICON_64="$(find_icon "unicsync_icon_64.png")"

if [ -n "$ICON_256" ]; then
    cp "$ICON_256" "$ICON_BASE/256x256/apps/com.rsync.unic_sync.png"
    cp "$ICON_256" "$ICON_BASE/256x256/apps/unicsync.png"
    cp "$ICON_256" "$PIXMAP_DIR/com.rsync.unic_sync.png"
    cp "$ICON_256" "$PIXMAP_DIR/unicsync.png"
fi

if [ -n "$ICON_128" ]; then
    cp "$ICON_128" "$ICON_BASE/128x128/apps/com.rsync.unic_sync.png"
    cp "$ICON_128" "$ICON_BASE/128x128/apps/unicsync.png"
fi

if [ -n "$ICON_64" ]; then
    cp "$ICON_64" "$ICON_BASE/64x64/apps/com.rsync.unic_sync.png"
    cp "$ICON_64" "$ICON_BASE/64x64/apps/unicsync.png"
fi

echo "==> Registering Desktop Launcher Entries..."
# Remove any legacy / conflicting entries
rm -f "$APPS_DIR/unicSync.desktop"

# Standard Freedesktop reverse-DNS entry matching Wayland app_id and GtkApplication ID
cat << EOF > "$APPS_DIR/com.rsync.unic_sync.desktop"
[Desktop Entry]
Name=unicSync
GenericName=Cloud Sync Client
Comment=Standalone desktop cloud sync application powered by the uSync engine
Exec=$INSTALL_DIR/unic_sync %U
Icon=com.rsync.unic_sync
Terminal=false
Type=Application
Categories=Utility;Network;FileTransfer;
StartupNotify=true
StartupWMClass=com.rsync.unic_sync
Keywords=sync;cloud;backup;s3;gdrive;webdav;
EOF
chmod 644 "$APPS_DIR/com.rsync.unic_sync.desktop"

# Also symlink unicsync.desktop for convenience and compatibility
ln -sf "com.rsync.unic_sync.desktop" "$APPS_DIR/unicsync.desktop"

# Update Linux desktop database and icon cache
if command -v update-desktop-database > /dev/null 2>&1; then
    update-desktop-database "$APPS_DIR" 2>/dev/null || true
fi
if command -v gtk-update-icon-cache > /dev/null 2>&1; then
    gtk-update-icon-cache -f -t "$ICON_BASE" 2>/dev/null || true
fi

echo ""
echo "=================================================="
echo "  unicSync v1.0.0 installed successfully!         "
echo "=================================================="
echo "Executable: $INSTALL_DIR/unic_sync"
echo "Command:    unic_sync (via $BIN_DIR)"
echo "Launcher:   $APPS_DIR/com.rsync.unic_sync.desktop"
echo ""
echo "You can now launch 'unicSync' directly from your application launcher / dash!"
