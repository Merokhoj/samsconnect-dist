# SamsConnect Installation Guide

## Quick Install

### 1. Remove Old Version (if any)
```bash
sudo dpkg -r samsconnect
```

### 2. Install SamsConnect
```bash
sudo dpkg -i samsconnect.deb
sudo apt-get install -f
```

### 3. Re-login or Reboot
**IMPORTANT**: After installation, you must **log out and log back in** (or reboot) for device connectivity to work properly.

This is required because:
- The installer adds your user to the `plugdev` group
- Udev rules for Android devices are installed
- These changes only take effect after re-login

### 4. Connect Your Device
1. Connect your Android device via USB
2. Enable **USB Debugging** on your device:
   - Go to `Settings > About Phone`
   - Tap `Build Number` 7 times to enable Developer Options
   - Go to `Settings > Developer Options`
   - Enable `USB Debugging`
3. If prompted on your device, tap **Allow** for USB debugging

### 5. Launch SamsConnect
- Find **SamsConnect** in your application menu
- Or run from terminal: `samsconnect`

---

## Troubleshooting

### Device Not Detected?

**1. Check USB Debugging is enabled**
```bash
# Run this command to check if device is detected
adb devices
```

**2. Verify udev rules are installed**
```bash
ls -l /etc/udev/rules.d/51-samsconnect-android.rules
```

**3. Check if you're in the plugdev group**
```bash
groups $USER | grep plugdev
```

If `plugdev` doesn't appear, run:
```bash
sudo usermod -a -G plugdev $USER
```
Then **log out and log back in**.

**4. Reload udev rules manually**
```bash
sudo udevadm control --reload-rules
sudo udevadm trigger
```

**5. Try reconnecting your device**
- Unplug your device
- Plug it back in
- Check if a prompt appears on your device to allow USB debugging

### Still Not Working?

**Check if ADB can see your device:**
```bash
# Use bundled ADB
/opt/samsconnect/data/flutter_assets/assets/tools/linux/adb devices

# Or system ADB
adb devices
```

If your device shows up in ADB but not in SamsConnect, restart the app.

---

## Package Details

- **Package Size**: 13 MB
- **Installed Size**: ~43 MB
- **Installation Location**: `/opt/samsconnect/`
- **Binary**: `/usr/bin/samsconnect` (symlink to `/opt/samsconnect/samsconnect`)
- **Desktop Entry**: `/usr/share/applications/samsconnect.desktop`
- **Icon**: `/usr/share/icons/hicolor/128x128/apps/samsconnect.png`

### Dependencies (auto-installed)
- libgtk-3-0
- libglib2.0-0
- android-tools-adb
- ffmpeg
- uxplay
- ifuse
- libimobiledevice6

---

## Uninstall

To completely remove SamsConnect:
```bash
sudo dpkg -r samsconnect
```

This will remove:
- The application files from `/opt/samsconnect/`
- The desktop launcher
- The udev rules
- The application icon

**Note**: Your user will remain in the `plugdev` group even after uninstall.

---

## For Developers

### Building from Source
```bash
cd samsconnect
flutter build linux --release
./scripts/package_deb.sh
```

This will create `samsconnect.deb` in the project root.
