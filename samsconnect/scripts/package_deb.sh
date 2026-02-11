#!/bin/bash
# Console .deb Packaging Script

APP_NAME="samsconnect"
VERSION="1.0.0"
ARCH="amd64"
PKG_DIR="${APP_NAME}_${VERSION}_${ARCH}"

echo "Creating structure for $PKG_DIR..."
mkdir -p "$PKG_DIR/DEBIAN"
mkdir -p "$PKG_DIR/opt/$APP_NAME"
mkdir -p "$PKG_DIR/usr/bin"
mkdir -p "$PKG_DIR/usr/share/applications"
mkdir -p "$PKG_DIR/usr/share/icons/hicolor/128x128/apps"
mkdir -p "$PKG_DIR/usr/share/pixmaps"
mkdir -p "$PKG_DIR/lib/udev/rules.d"

# Copy build files
cp -r build/linux/x64/release/bundle/* "$PKG_DIR/opt/$APP_NAME/"

# Create control file
cat > "$PKG_DIR/DEBIAN/control" <<EOF
Package: $APP_NAME
Version: $VERSION
Section: utils
Priority: optional
Architecture: $ARCH
Depends: libgtk-3-0, libglib2.0-0, android-tools-adb, ffmpeg, uxplay, ifuse, libimobiledevice6
Maintainer: SamsConnect Dev <dev@merokhoj.com>
Description: A powerful Android & iOS device management studio.
EOF

# Copy udev rules for device connectivity (to /etc/udev/rules.d/)
mkdir -p "$PKG_DIR/etc/udev/rules.d"
if [ -f "assets/udev/51-android.rules" ]; then
    cp "assets/udev/51-android.rules" "$PKG_DIR/etc/udev/rules.d/51-samsconnect-android.rules"
fi

# Make bundled tools executable
chmod +x "$PKG_DIR/opt/$APP_NAME/data/flutter_assets/assets/tools/linux/adb" 2>/dev/null || true
chmod +x "$PKG_DIR/opt/$APP_NAME/data/flutter_assets/assets/tools/linux/samsconnect" 2>/dev/null || true
chmod +x "$PKG_DIR/opt/$APP_NAME/data/flutter_assets/assets/tools/linux/samsconnect-server" 2>/dev/null || true

# Create postinst script
cat > "$PKG_DIR/DEBIAN/postinst" <<'POSTINST'
#!/bin/sh
set -e
if [ "$1" = "configure" ]; then
    # Set execute permissions on bundled tools
    chmod +x /opt/samsconnect/data/flutter_assets/assets/tools/linux/* 2>/dev/null || true
    
    # Reload udev rules
    udevadm control --reload-rules 2>/dev/null || true
    udevadm trigger 2>/dev/null || true
    
    # Add user to plugdev group if not already
    if ! groups $SUDO_USER 2>/dev/null | grep -q plugdev; then
        usermod -a -G plugdev $SUDO_USER 2>/dev/null || true
    fi
    
    # Update desktop database
    update-desktop-database 2>/dev/null || true
fi
exit 0
POSTINST
chmod 755 "$PKG_DIR/DEBIAN/postinst"

# Create postrm script
cat > "$PKG_DIR/DEBIAN/postrm" <<'POSTRM'
#!/bin/sh
set -e
if [ "$1" = "remove" ] || [ "$1" = "purge" ]; then
    # Reload udev rules after removal
    udevadm control --reload-rules 2>/dev/null || true
    udevadm trigger 2>/dev/null || true
    
    # Update desktop database
    update-desktop-database 2>/dev/null || true
fi
exit 0
POSTRM
chmod 755 "$PKG_DIR/DEBIAN/postrm"

# Create symlink
ln -s "/opt/$APP_NAME/$APP_NAME" "$PKG_DIR/usr/bin/$APP_NAME"

# Create .desktop file
cat > "$PKG_DIR/usr/share/applications/$APP_NAME.desktop" <<EOF
[Desktop Entry]
Name=SamsConnect
Comment=Android & iOS device management studio
Exec=$APP_NAME
Icon=$APP_NAME
Type=Application
Categories=Utility;Development;
Terminal=false
EOF

# Use app logo as icon if exists
if [ -f "assets/images/app_logo.png" ]; then
    cp "assets/images/app_logo.png" "$PKG_DIR/usr/share/icons/hicolor/128x128/apps/$APP_NAME.png"
    cp "assets/images/app_logo.png" "$PKG_DIR/usr/share/pixmaps/$APP_NAME.png"
fi

# Remove old .deb if exists
rm -f "${APP_NAME}.deb"

# Build package
dpkg-deb --build "$PKG_DIR"
mv "${PKG_DIR}.deb" "${APP_NAME}.deb"

echo "Cleanup..."
rm -rf "$PKG_DIR"

echo "Done! ${APP_NAME}.deb created."
