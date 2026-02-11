# SamsConnect - Device Connection Troubleshooting Guide

## ✅ Pre-Installation Checklist

### 1. Install System Dependencies
```bash
# For Android devices
sudo apt install android-tools-adb android-tools-fastboot

# For iOS devices (iPhone/iPad)
sudo apt install libimobiledevice6 libimobiledevice-utils ifuse usbmuxd

# For screen mirroring
sudo apt install ffmpeg scrcpy

# For network mirroring (iOS)
sudo apt install uxplay
```

### 2. Add User to plugdev Group
```bash
sudo usermod -aG plugdev $USER
# Then log out and log back in, or run:
newgrp plugdev
```

### 3. Verify USB Connection
```bash
# Check if device is visible
lsusb

# For Android: Check ADB
adb devices

# For iOS: Check libimobiledevice
idevice_id -l
```

## 📱 **Android Device Setup**

### Enable USB Debugging
1. Go to **Settings** → **About Phone**
2. Tap **Build Number** 7 times to enable **Developer Options**
3. Go to **Settings** → **Developer Options**
4. Enable **USB Debugging**
5. Connect device via USB
6. **Tap "Allow"** on the "Allow USB Debugging?" popup

### If Device Still Not Detected:
```bash
# Kill and restart ADB server
adb kill-server
adb start-server
adb devices

# Check udev rules
ls /lib/udev/rules.d/*android* /lib/udev/rules.d/*samsconnect*

# Reload udev rules
sudo udevadm control --reload-rules
sudo udevadm trigger

# Check device permissions
lsusb
# Note the device ID (e.g., 04e8:6860 for Samsung)
# Then check udev rules match it
```

## 📱 **iOS Device Setup (iPhone/iPad)**

### Enable Trust
1. Connect iPhone/iPad via USB
2. **Unlock the device**
3. Tap **"Trust This Computer"** when prompted
4. Enter your device passcode

### Verify iOS Detection:
```bash
# List connected iOS devices
idevice_id -l

# Get device info
ideviceinfo

# If not working, restart usbmuxd
sudo systemctl restart usbmuxd
```

## 🐛 **Common Issues**

### Issue: "No devices found" for Android
**Solution:**
1. Enable USB Debugging (see Android setup above)
2. Check USB cable (try a different one - data cables, not just charging cables)
3. Try a different USB port
4. Revoke USB debugging authorizations: Settings → Developer Options → Revoke USB debugging authorizations
5. Reconnect and accept the authorization popup

### Issue: "No devices found" for iOS
**Solution:**
1. Unlock the iPhone and tap "Trust This Computer"
2. Install libimobiledevice: `sudo apt install libimobiledevice6 libimobiledevice-utils`
3. Restart usbmuxd: `sudo systemctl restart usbmuxd`
4. Check pairing: `idevicepair pair`

### Issue: Device detected but can't control
**Solution:**
1. For Android: Enable "USB Debugging (Security Settings)" in Developer Options
2. Check file permissions: `ls -l ~/.local/share/com.merokhoj.samsconnect/tools/`
3. All binaries should be executable (with `x` permission)

### Issue: "Permission denied" when connecting
**Solution:**
```bash
# Verify you're in plugdev group
groups | grep plugdev

# If not, add yourself and reboot
sudo usermod -aG plugdev $USER
sudo reboot
```

## 🔍 **Debugging Steps**

### Check if SamsConnect can see the extracted tools:
```bash
ls -lh ~/.local/share/com.merokhoj.samsconnect/tools/
# Should show: adb, samsconnect, samsconnect-server (all executable)
```

### Check ADB directly:
```bash
~/.local/share/com.merokhoj.samsconnect/tools/adb devices
# OR system ADB:
adb devices
```

### Check device in lsusb:
```bash
# Android will show manufacturer name (Samsung, Google, etc.)
# iOS will show "Apple, Inc."
lsusb | grep -E "(Samsung|Google|Apple|OnePlus|Xiaomi)"
```

### Run app from terminal to see logs:
```bash
samsconnect
# Look for error messages about: ADB, iOS service, device detection
```

## 📦 **Reinstallation**

If all else fails, try a clean reinstall:
```bash
# Remove old config
rm -rf ~/.local/share/com.merokhoj.samsconnect
rm -rf ~/.local/share/com.merokhoj.console  # Old name if upgrading

# Remove and reinstall package
sudo dpkg -r samsconnect
sudo dpkg -i samsconnect.deb
sudo apt-get install -f

# Reboot
sudo reboot
```

## 🆘 **Still Not Working?**

1. **Check logs when running from terminal:**
   ```bash
   samsconnect 2>&1 | grep -E "(Error|Failed|Warning)"
   ```

2. **Verify dependencies:**
   ```bash
   dpkg -l | grep -E "(adb|libimobiledevice|scrcpy|uxplay)"
   ```

3. **Test each tool individually:**
   ```bash
   # Android
   adb devices
   
   # iOS
   idevice_id -l
   ideviceinfo
   
   # Mirroring
   scrcpy --version
   ```

---
**Need More Help?**  
Check the GitHub issues or contact support with the output of:
```bash
lsusb
adb devices
idevice_id -l
samsconnect 2>&1 | head -50
```
