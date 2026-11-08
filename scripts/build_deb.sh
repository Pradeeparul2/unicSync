#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "==> Building Linux release bundle..."
cd "$PROJECT_ROOT"
flutter build linux --release

PKG_NAME="unicsync"
VERSION="1.0.1"
ARCH="amd64"
DEB_DIR="$PROJECT_ROOT/build/deb_package"
BUNDLE_DIR="$PROJECT_ROOT/build/linux/x64/release/bundle"

echo "==> Staging Debian package layout in $DEB_DIR..."
rm -rf "$DEB_DIR"
mkdir -p "$DEB_DIR/DEBIAN"
mkdir -p "$DEB_DIR/opt/unicsync"
mkdir -p "$DEB_DIR/usr/bin"
mkdir -p "$DEB_DIR/usr/share/applications"
mkdir -p "$DEB_DIR/usr/share/icons/hicolor/256x256/apps"
mkdir -p "$DEB_DIR/usr/share/icons/hicolor/128x128/apps"
mkdir -p "$DEB_DIR/usr/share/icons/hicolor/64x64/apps"
mkdir -p "$DEB_DIR/usr/share/pixmaps"

# 1. Copy full application bundle to /opt/unicsync
cp -r "$BUNDLE_DIR"/* "$DEB_DIR/opt/unicsync/"
chmod +x "$DEB_DIR/opt/unicsync/unic_sync"

# Ensure bundled engine binaries retain execute permissions
if [ -f "$DEB_DIR/opt/unicsync/data/flutter_assets/assets/bin/sync-agent" ]; then
    chmod +x "$DEB_DIR/opt/unicsync/data/flutter_assets/assets/bin/sync-agent"
fi

# 2. Symlink to /usr/bin/unic_sync
ln -sf "/opt/unicsync/unic_sync" "$DEB_DIR/usr/bin/unic_sync"

# 3. Application launcher icon (multi-resolution & dual-naming)
cp "$PROJECT_ROOT/assets/images/unicsync_icon_256.png" "$DEB_DIR/usr/share/icons/hicolor/256x256/apps/com.rsync.unic_sync.png"
cp "$PROJECT_ROOT/assets/images/unicsync_icon_256.png" "$DEB_DIR/usr/share/icons/hicolor/256x256/apps/unicsync.png"
cp "$PROJECT_ROOT/assets/images/unicsync_icon_128.png" "$DEB_DIR/usr/share/icons/hicolor/128x128/apps/com.rsync.unic_sync.png"
cp "$PROJECT_ROOT/assets/images/unicsync_icon_128.png" "$DEB_DIR/usr/share/icons/hicolor/128x128/apps/unicsync.png"
cp "$PROJECT_ROOT/assets/images/unicsync_icon_64.png" "$DEB_DIR/usr/share/icons/hicolor/64x64/apps/com.rsync.unic_sync.png"
cp "$PROJECT_ROOT/assets/images/unicsync_icon_64.png" "$DEB_DIR/usr/share/icons/hicolor/64x64/apps/unicsync.png"
cp "$PROJECT_ROOT/assets/images/unicsync_icon_256.png" "$DEB_DIR/usr/share/pixmaps/com.rsync.unic_sync.png"
cp "$PROJECT_ROOT/assets/images/unicsync_icon_256.png" "$DEB_DIR/usr/share/pixmaps/unicsync.png"

# 4. Standard XDG Desktop Entry matching Wayland app_id and GtkApplication ID
cat << 'EOF' > "$DEB_DIR/usr/share/applications/com.rsync.unic_sync.desktop"
[Desktop Entry]
Name=unicSync
GenericName=Cloud Sync Client
Comment=Standalone desktop cloud sync application powered by the uSync engine
Exec=/opt/unicsync/unic_sync %U
Icon=com.rsync.unic_sync
Terminal=false
Type=Application
Categories=Utility;Network;FileTransfer;
StartupNotify=true
StartupWMClass=com.rsync.unic_sync
Keywords=sync;cloud;backup;s3;gdrive;webdav;
EOF
chmod 644 "$DEB_DIR/usr/share/applications/com.rsync.unic_sync.desktop"
ln -sf "com.rsync.unic_sync.desktop" "$DEB_DIR/usr/share/applications/unicsync.desktop"

# 5. Debian control file
cat << EOF > "$DEB_DIR/DEBIAN/control"
Package: $PKG_NAME
Version: $VERSION
Section: utils
Priority: optional
Architecture: $ARCH
Depends: libc6, libgtk-3-0, libglib2.0-0
Maintainer: unicSync Contributors <support@unicsync.io>
Description: Standalone desktop cloud sync application powered by the uSync engine
 unicSync is a cross-platform desktop UI control hub for synchronizing
 local PC folders to cloud storage targets (AWS S3, Cloudflare R2, Google Drive,
 WebDAV) featuring intelligent storage tiering, bounded RAM streaming, and
 client-side zero-knowledge AES-256-GCM encryption.
EOF

# 6. Post-install script
cat << 'EOF' > "$DEB_DIR/DEBIAN/postinst"
#!/bin/sh
set -e
if command -v update-desktop-database > /dev/null 2>&1; then
    update-desktop-database /usr/share/applications || true
fi
if command -v gtk-update-icon-cache > /dev/null 2>&1; then
    gtk-update-icon-cache -f /usr/share/icons/hicolor || true
fi
exit 0
EOF
chmod 755 "$DEB_DIR/DEBIAN/postinst"

# 7. Post-remove script
cat << 'EOF' > "$DEB_DIR/DEBIAN/postrm"
#!/bin/sh
set -e
if command -v update-desktop-database > /dev/null 2>&1; then
    update-desktop-database /usr/share/applications || true
fi
if command -v gtk-update-icon-cache > /dev/null 2>&1; then
    gtk-update-icon-cache -f /usr/share/icons/hicolor || true
fi
exit 0
EOF
chmod 755 "$DEB_DIR/DEBIAN/postrm"

# 8. Build the Debian package
OUTPUT_DEB="$PROJECT_ROOT/${PKG_NAME}_${VERSION}_${ARCH}.deb"
echo "==> Packaging .deb using dpkg-deb..."
dpkg-deb --build "$DEB_DIR" "$OUTPUT_DEB"

echo "==> Debian package generated successfully:"
ls -lh "$OUTPUT_DEB"
