#!/bin/bash

# SamsConnect .deb Package Builder
# Creates a Debian package from the Flutter build

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}SamsConnect .deb Package Builder${NC}"
echo -e "${GREEN}========================================${NC}"

# Get version from pubspec.yaml
VERSION=$(grep "^version:" pubspec.yaml | cut -d' ' -f2 | cut -d'+' -f1)
BUILD_NUMBER=$(grep "^version:" pubspec.yaml | cut -d' ' -f2 | cut -d'+' -f2)
PACKAGE_NAME="samsconnect"
ARCHITECTURE="amd64"
DEB_NAME="${PACKAGE_NAME}_${VERSION}-${BUILD_NUMBER}_${ARCHITECTURE}"

echo -e "${YELLOW}Version: ${VERSION}${NC}"
echo -e "${YELLOW}Build: ${BUILD_NUMBER}${NC}"
echo -e "${YELLOW}Package: ${DEB_NAME}.deb${NC}"

# Create package directory structure
PKG_DIR="build/deb/${DEB_NAME}"
rm -rf build/deb
mkdir -p "${PKG_DIR}/DEBIAN"
mkdir -p "${PKG_DIR}/usr/bin"
mkdir -p "${PKG_DIR}/usr/share/applications"
mkdir -p "${PKG_DIR}/usr/share/icons/hicolor/256x256/apps"
mkdir -p "${PKG_DIR}/usr/share/${PACKAGE_NAME}"

echo -e "${GREEN}✓ Created package directory structure${NC}"

# Create DEBIAN/control file
cat > "${PKG_DIR}/DEBIAN/control" << EOF
Package: ${PACKAGE_NAME}
Version: ${VERSION}-${BUILD_NUMBER}
Section: utils
Priority: optional
Architecture: ${ARCHITECTURE}
Maintainer: MeroKhoj <support@merokhoj.com>
Description: SamsConnect - Android Device Management & Mirroring Console
 A powerful Android device management and screen mirroring application.
 Features include:
  - Device discovery and connection
  - Real-time screen mirroring
  - File management
  - App management
  - Device information display
Homepage: https://github.com/merokhoj/samsconnect
Depends: libgtk-3-0, libblkid1, liblzma5
EOF

echo -e "${GREEN}✓ Created control file${NC}"

# Create postinst script
cat > "${PKG_DIR}/DEBIAN/postinst" << 'EOF'
#!/bin/bash
set -e

# Update desktop database
if command -v update-desktop-database &> /dev/null; then
    update-desktop-database -q
fi

# Update icon cache
if command -v gtk-update-icon-cache &> /dev/null; then
    gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor || true
fi

echo "SamsConnect installed successfully!"
echo "Run 'samsconnect' to start the application."

exit 0
EOF

chmod 755 "${PKG_DIR}/DEBIAN/postinst"
echo -e "${GREEN}✓ Created postinst script${NC}"

# Create postrm script
cat > "${PKG_DIR}/DEBIAN/postrm" << 'EOF'
#!/bin/bash
set -e

# Update desktop database
if command -v update-desktop-database &> /dev/null; then
    update-desktop-database -q
fi

# Update icon cache
if command -v gtk-update-icon-cache &> /dev/null; then
    gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor || true
fi

exit 0
EOF

chmod 755 "${PKG_DIR}/DEBIAN/postrm"
echo -e "${GREEN}✓ Created postrm script${NC}"

# Copy built application
echo -e "${YELLOW}Copying application files...${NC}"
cp -r build/linux/x64/release/bundle/* "${PKG_DIR}/usr/share/${PACKAGE_NAME}/"
echo -e "${GREEN}✓ Copied application bundle${NC}"

# Create launcher script
cat > "${PKG_DIR}/usr/bin/${PACKAGE_NAME}" << EOF
#!/bin/bash
cd /usr/share/${PACKAGE_NAME}
exec ./samsconnect "\$@"
EOF

chmod 755 "${PKG_DIR}/usr/bin/${PACKAGE_NAME}"
echo -e "${GREEN}✓ Created launcher script${NC}"

# Copy desktop file
cp linux/com.merokhoj.samsconnect.desktop "${PKG_DIR}/usr/share/applications/"
echo -e "${GREEN}✓ Copied desktop file${NC}"

# Copy icon
if [ -f "assets/images/app_logo.png" ]; then
    cp assets/images/app_logo.png "${PKG_DIR}/usr/share/icons/hicolor/256x256/apps/samsconnect.png"
    echo -e "${GREEN}✓ Copied application icon${NC}"
else
    echo -e "${YELLOW}⚠ Icon not found, using default${NC}"
fi

# Set correct permissions
echo -e "${YELLOW}Setting permissions...${NC}"
find "${PKG_DIR}" -type d -exec chmod 755 {} \;
find "${PKG_DIR}/usr/share/${PACKAGE_NAME}" -type f -name "*.so*" -exec chmod 644 {} \;
chmod 755 "${PKG_DIR}/usr/share/${PACKAGE_NAME}/samsconnect"
chmod 755 "${PKG_DIR}/usr/share/${PACKAGE_NAME}/lib/"*.so* 2>/dev/null || true

# Build the .deb package
echo -e "${YELLOW}Building .deb package...${NC}"
dpkg-deb --build --root-owner-group "${PKG_DIR}"

# Move to root of build directory
mv build/deb/${DEB_NAME}.deb build/

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✓ Package built successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "${YELLOW}Package: ${GREEN}build/${DEB_NAME}.deb${NC}"
echo ""
echo -e "Install with: ${YELLOW}sudo dpkg -i build/${DEB_NAME}.deb${NC}"
echo ""

# Get package size
SIZE=$(du -h "build/${DEB_NAME}.deb" | cut -f1)
echo -e "Package size: ${GREEN}${SIZE}${NC}"
echo ""
