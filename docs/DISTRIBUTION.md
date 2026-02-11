# SamsConnect - Distribution Guide

Documentation for building and installing the **SamsConnect** application.

## Build Status
- **Linux**: ✅ Stable (Build 1.0.0+1)
- **Windows**: ⚠️ In Progress (.exe)
- **macOS**: ⚠️ In Progress (.dmg)
- **Web**: ⚠️ Reviewing feasibility

## Linux Installation (.deb)

### 1. Requirements
- FFmpeg (for mirroring) - `sudo apt install ffmpeg`
- libimobiledevice-utils & ifuse (for iOS) - `sudo apt install libimobiledevice6 ifuse`
- Android Debug Bridge - `sudo apt install android-tools-adb`
- UXPlay (for iOS mirroring) - `sudo apt install uxplay`

**Note**: Most dependencies will be automatically installed when you install the .deb package.

### 2. Remove Old Version (if installed)
Before installing the new version, remove any previous installations:
```bash
# Remove old version
sudo dpkg -r samsconnect
```

### 3. Install New Version
Download the `samsconnect.deb` package (13 MB) and run:
```bash
sudo dpkg -i samsconnect.deb
sudo apt-get install -f  # This will install any missing dependencies
```

### 4. Post-Installation
After installation:
1. **Re-login or reboot** to apply udev rules and user group changes
2. **Connect your Android device** via USB
3. **Enable USB debugging** on your Android device
4. Launch **SamsConnect** from your application menu

**Note**: The installer adds your user to the `plugdev` group. You may need to log out and log back in for this to take effect.

### 5. Verify Installation
```bash
# Check if installed correctly
samsconnect --version

# Verify bundled ADB
ls -l /opt/samsconnect/data/flutter_assets/assets/tools/linux/
```

### 6. Uninstall
To completely remove SamsConnect:
```bash
sudo dpkg -r samsconnect
```

## Platform Roadmap
- **Windows**: Implementing `.exe` build via `msix` or custom installer.
- **macOS**: Preparing `.app` and `.dmg` packaging.
- **Web**: Evaluating WebHID/WebUSB for device communication.

---
*Identity: SamsConnect*
