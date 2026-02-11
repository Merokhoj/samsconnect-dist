# SamsConnect - Quick Install & Setup Guide

## 📦 Installation

```bash
# Install the package (will auto-install dependencies)
sudo dpkg -i samsconnect.deb
sudo apt-get install -f

# Add your user to the plugdev group (REQUIRED for device access)
sudo usermod -aG plugdev $USER

# Log out and log back in for group changes to take effect
# OR run this to apply immediately:
newgrp plugdev
```

## 🔌 Device Setup

### For Android:
1. Enable **USB Debugging** on your device:
   - Settings → About Phone → Tap "Build Number" 7 times
   - Settings → Developer Options → Enable "USB Debugging"
2. Connect device via USB
3. **Tap "Allow"** on the authorization popup

### For iOS (iPhone/iPad):
1. Connect device via USB
2. **Unlock the device**
3. **Tap "Trust This Computer"**
4. Enter your device passcode

## ✅ Verify Installation

```bash
# Check Android device
adb devices
# Should show: List of devices attached
#              XXXXXXXXXX device

# Check iOS device
idevice_id -l
# Should show device UDID

# Launch SamsConnect
samsconnect
# OR find it in your applications menu
```

## ❓ Troubleshooting

If no devices are detected, see **TROUBLESHOOTING.md** for detailed help.

**Quick fixes:**
```bash
# For Android: Restart ADB
adb kill-server && adb start-server

# For iOS: Restart USB service
sudo systemctl restart usbmuxd

# Reload udev rules
sudo udevadm control --reload-rules && sudo udevadm trigger
```

## 🎯 What's Included

- ✅ **Device Management**: Android & iOS device detection
- ✅ **Screen Mirroring**: Real-time device screen mirroring
- ✅ **File Manager**: Browse and transfer files
- ✅ **App Manager**: Install, uninstall, and manage apps
- ✅ **Wi-Fi Control**: Connect and manage wireless connections
- ✅ **Pattern Unlock**: Unlock device patterns visually

---
**Need Help?** Check `TROUBLESHOOTING.md` or run `samsconnect --help`
