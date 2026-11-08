#!/usr/bin/env bash
set -euo pipefail

IS_SYSTEM=0
if [ "${1:-}" = "--system" ] || [ "$(id -u)" -eq 0 ]; then
    IS_SYSTEM=1
fi

if [ "$IS_SYSTEM" -eq 1 ]; then
    echo "==> Uninstalling unicSync system-wide..."
    rm -rf "/opt/unicsync"
    rm -f "/usr/local/bin/unic_sync" "/usr/bin/unic_sync"
    rm -f "/usr/share/applications/unicsync.desktop"
    rm -f "/usr/share/icons/hicolor/256x256/apps/unicsync.png"
    rm -f "/usr/share/pixmaps/unicsync.png"
    if command -v update-desktop-database > /dev/null 2>&1; then
        update-desktop-database /usr/share/applications 2>/dev/null || true
    fi
else
    echo "==> Uninstalling unicSync for user $USER..."
    rm -rf "$HOME/.local/share/unicsync"
    rm -f "$HOME/.local/bin/unic_sync"
    rm -f "$HOME/.local/share/applications/unicsync.desktop"
    rm -f "$HOME/.local/share/icons/hicolor/256x256/apps/unicsync.png"
    rm -f "$HOME/.local/share/pixmaps/unicsync.png"
    if command -v update-desktop-database > /dev/null 2>&1; then
        update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
    fi
fi

echo "unicSync has been cleanly uninstalled."
