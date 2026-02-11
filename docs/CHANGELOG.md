# SamsConnect Changelog

## Version 1.1.0-2 (2026-02-11)

### ✨ New Features
- **Auto-Start Mirroring**: Click "Live Screen" in sidebar now automatically starts screen mirroring - no double-click needed!
- **App Logo Integration**: Beautiful app logo now displayed in sidebar and top bar

### 🐛 Bug Fixes
- Fixed `libcrypto.so.0` library dependency error by using system ADB
- Fixed `libbase.so.0` missing library error
- Resolved screen mirroring initialization issues
- Fixed ADB server connection errors

### 🔧 Improvements
- Enhanced sidebar branding with app logo
- Improved mirroring service initialization
- Better error handling and user feedback
- More reliable device connection

### 📦 Technical Changes
- Symlinked system ADB (v36.0.2) for better compatibility
- Updated version to 1.1.0+2
- Improved .deb package structure
- Added proper desktop integration files

### 📝 Installation
```bash
sudo dpkg -i samsconnect_1.1.0-2_amd64.deb
```

### 🚀 Run
```bash
samsconnect
```

---

## Version 1.0.0-1 (Initial Release)
- Android device management
- Screen mirroring with scrcpy
- File browser and transfer
- App management
- Device information display
