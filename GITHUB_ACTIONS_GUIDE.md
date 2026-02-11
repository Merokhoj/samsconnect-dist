# GitHub Actions Guide for SamsConnect

This guide explains how the automated build and release process works for SamsConnect using GitHub Actions.

## 🚀 Overview
The GitHub Action is configured to automatically build a **Windows Release** whenever a new version tag (e.g., `v1.1.0`) is pushed to the repository.

## 🛠️ Workflow Details
- **File Location**: `.github/workflows/release.yml`
- **Trigger**: Pushing a tag that starts with `v` (e.g., `git tag v1.1.0`).
- **Target OS**: Windows (using `windows-latest` runner).

### Build Steps:
1. **Checkout**: Downloads the source code.
2. **Flutter Setup**: Installs the Flutter stable SDK.
3. **Dependencies**: Runs `flutter pub get`.
4. **Build**: Compiles the application to a Windows executable using `flutter build windows --release`.
5. **Packaging**: Compresses the `build/windows/runner/Release` folder into a `.zip` file.
6. **Release**: Automatically creates a GitHub Release and attaches the `.zip` file as an artifact.

## ⚙️ How to Release a New Version
To release a new version of SamsConnect, follow these steps in your terminal:

1. **Commit your changes**:
   ```bash
   git add .
   git commit -m "Your description of changes"
   git push origin main
   ```

2. **Tag the version**:
   ```bash
   git tag v1.1.0
   git push origin v1.1.0
   ```

3. **Monitor the Build**:
   - Go to the **Actions** tab on your GitHub repository.
   - You will see a workflow named "Build & Release" running.
   - Once finished, the Windows `.zip` will appear under **Releases**.

## 🔧 Troubleshooting
- **GitHub Action error (`Unable to resolve action`)**: This usually happens if a third-party action is removed or renamed. We have switched to the official `softprops/action-gh-release` which is the industry standard.
- **Permissions**: The workflow requires `contents: write` permission to create a release, which is already configured in the `release.yml`.

## 📂 Artifact Locations
- **Windows**: `samsconnect-windows-x64.zip`
- **Linux**: Build locally using `flutter build linux --release` and then package with `build_deb.sh`.

---
*Maintained by Antigravity*
