# Android Build Guide

This guide explains the Android build system for IAClé, which creates multi-architecture APKs.

## Overview

Android builds run in [`.github/workflows/build-mobile.yml`](../../.github/workflows/build-mobile.yml) after a successful [Web Deploy](../operations/cicd/WEB_DEPLOY.md), or on `workflow_dispatch`. The automatic chain builds Android only. The iOS job runs only when the dispatch input `platforms` contains `ios`, and the repository does not currently contain `ios/Runner.xcodeproj`.

## Current toolchain

Checked in as of the SDK 37 fixes:

| Piece | Value | Where |
| --- | --- | --- |
| Android Gradle Plugin | `8.11.1` | `android/settings.gradle` |
| Gradle | `8.14.3` | `android/gradle/wrapper/gradle-wrapper.properties` |
| Kotlin Gradle Plugin | `2.4.0` | `android/settings.gradle` |
| Kotlin Android plugin | `2.1.0` | `android/settings.gradle` |
| `compileSdk` | `37` | `android/app/build.gradle` |
| `compileSdkMinor` | `0` | `android/app/build.gradle` |
| Platform package | `platforms;android-37.0` | `build-mobile.yml` |
| NDK | `flutter.ndkVersion` | `android/app/build.gradle` |
| min / target SDK | `flutter.minSdkVersion` / `flutter.targetSdkVersion` | `android/app/build.gradle` |
| Flutter | `3.47.7` (`pubspec.yaml` `environment.flutter`) | `build-mobile.yml` |
| Runner | `ubuntu-24.04` | `build-mobile.yml` |

API 37 is published as the minor-versioned package `platforms;android-37.0`. This repo uses AGP `8.11.1` with `compileSdk 37` and `compileSdkMinor 0`. Installing `platforms;android-37` (no minor) does not satisfy the build. Gradle `8.14.3` is paired with AGP `8.11.1` (Flutter `3.47.7` minimum; AGP 9 waits on `tesseract_ocr` removing `jcenter()`).

`minSdkVersion` and `targetSdkVersion` are not numeric literals in this repo. They come from the Flutter Gradle plugin for the Flutter version that runs the build.

### CI install of platform 37

`ubuntu-24.04` GitHub runners do not put `sdkmanager` on `PATH`. The workflow resolves it from `$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager`, and if that file is missing it searches under `ANDROID_HOME`. A miss prints the tree and fails. It then runs `yes | sdkmanager --licenses` and `sdkmanager --install platforms;android-37.0`. Install failures dump the last 60 lines of `/tmp/sdk.log`.

The APK step is:

```bash
flutter build apk --release --split-per-abi --android-skip-build-dependency-validation
```

Artifacts are uploaded as `android-apks` with Flutter's default names (`app-arm64-v8a-release.apk`, `app-armeabi-v7a-release.apk`, `app-x86_64-release.apk`). The release job tags `mobile-v{version}` and allows updates. It does not rename the APKs.

### Signing secrets the workflow reads

`build-mobile.yml` decodes the keystore and writes `android/key.properties`. These names are the ones CI uses:

| Secret | Written into |
| --- | --- |
| `ANDROID_KEYSTORE_B64` | `android/release-keystore.jks` |
| `ANDROID_STORE_PASSWORD` | `storePassword` |
| `ANDROID_KEY_PASSWORD` | `keyPassword` |
| `ANDROID_KEY_ALIAS` | `keyAlias` |

`storeFile` in that generated file is `../release-keystore.jks`, which is correct relative to the `android/app` module.

`scripts/setup-android-signing.ps1` and `scripts/verify-android-secrets.ps1` use the four names in the table above. The older names `ANDROID_KEYSTORE_BASE64` and `ANDROID_KEYSTORE_PASSWORD` are not read by the workflow.

The release `signingConfigs` block in `android/app/build.gradle` reads `android/key.properties` only. It does not read `android.injected.signing.*` properties.

## Build Artifacts

Android builds produce three APK files optimized for different architectures:

1. **arm64-v8a** (`app-arm64-v8a-release.apk`)
   - 64-bit ARM architecture
   - For most modern Android devices
   - Recommended for most users

2. **armeabi-v7a** (`app-armeabi-v7a-release.apk`)
   - 32-bit ARM architecture
   - For older Android devices
   - Wider compatibility

3. **x86_64** (`app-x86_64-release.apk`)
   - 64-bit x86 architecture
   - For Android emulators and some tablets
   - Testing and development

These are the filenames `flutter build apk --split-per-abi` writes. The mobile workflow uploads them unchanged.

Each APK is ~30-40% smaller than a universal APK, providing faster downloads and optimal performance.

## Prerequisites

The Android build system requires:

1. **Android Keystore**: Release keystore for signing APKs (✓ Configured)
2. **GitHub Secrets**: Signing credentials in repository secrets (✓ Configured)
3. **Android Configuration**: Project configuration in `android/` directory (✓ Ready)

## Step 1: Create Android Release Keystore

### Generate Keystore

```bash
# Generate a new keystore (run this locally, not in CI)
keytool -genkey -v -keystore release-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias release-key

# You will be prompted for:
# - Keystore password (save this securely!)
# - Key password (save this securely!)
# - Your name, organization, etc.
```

### Important Notes

- **DO NOT commit the keystore to the repository**
- Store the keystore file securely (password manager, secure vault)
- Keep backup copies of the keystore in multiple secure locations
- If you lose the keystore, you cannot update your app on Google Play Store

### Convert Keystore to Base64

```bash
# Convert keystore to base64 for GitHub Secrets
base64 release-keystore.jks > release-keystore.base64.txt

# On Windows (PowerShell):
[Convert]::ToBase64String([IO.File]::ReadAllBytes("release-keystore.jks")) | Out-File release-keystore.base64.txt
```

## Step 2: Configure GitHub Secrets

**✓ COMPLETED** - Android signing secrets have been configured in the GitHub repository.

CI reads the secret names in [Current toolchain](#current-toolchain), not the older `ANDROID_KEYSTORE_BASE64` / `ANDROID_KEYSTORE_PASSWORD` pair.

### Automated Setup Scripts

Two PowerShell scripts are provided for managing Android signing:

#### Setup Script (`scripts/setup-android-signing.ps1`)

Generates keystore and configures GitHub Secrets automatically:

```powershell
# Run the setup script
.\scripts\setup-android-signing.ps1

# What it does:
# 1. Checks if keystore already exists
# 2. Generates new keystore with strong passwords (if needed)
# 3. Converts keystore to base64 for GitHub Secrets
# 4. Configures all required GitHub Secrets via GitHub CLI
# 5. Saves backup information to android/keystore-backup-info.txt
```

**Requirements**:

- GitHub CLI (`gh`) installed and authenticated
- Java keytool (included with JDK)
- PowerShell 5.1 or later

#### Verification Script (`scripts/verify-android-secrets.ps1`)

Verifies that all Android signing secrets are configured correctly:

```powershell
# Run the verification script
.\scripts\verify-android-secrets.ps1

# What it checks:
# 1. All required secrets exist in GitHub repository
# 2. Keystore file exists locally
# 3. Keystore is valid and accessible
# 4. Key alias matches configured secret
# 5. Passwords work with the keystore
```

**Output**:

- ✓ Green checkmarks for configured secrets
- ✗ Red X for missing or invalid secrets
- Detailed error messages for troubleshooting

### Manual Secret Configuration

If you prefer to configure secrets manually:

1. **Generate keystore** (if not already created):

   ```bash
   keytool -genkey -v -keystore android/release-keystore.jks \
     -keyalg RSA -keysize 2048 -validity 10000 \
     -alias release-key
   ```

2. **Convert to base64**:

   ```powershell
   # Windows PowerShell
   [Convert]::ToBase64String([IO.File]::ReadAllBytes("android/release-keystore.jks")) | Out-File android/release-keystore.base64.txt
   
   # Linux/macOS
   base64 android/release-keystore.jks > android/release-keystore.base64.txt
   ```

3. **Add secrets to GitHub**:

   ```bash
   # Using GitHub CLI
   gh secret set ANDROID_KEYSTORE_B64 < android/release-keystore.base64.txt
   gh secret set ANDROID_STORE_PASSWORD
   gh secret set ANDROID_KEY_PASSWORD
   gh secret set ANDROID_KEY_ALIAS -b "IAClé-release"
   ```

### Security Best Practices

- ✓ Keystore file is excluded from version control (.gitignore)
- ✓ Strong, unique passwords generated automatically
- ✓ Secrets stored securely in GitHub Secrets (encrypted at rest)
- ✓ Backup information saved in `android/keystore-backup-info.txt`
- ✓ Secrets only accessible during workflow execution
- Rotate secrets periodically for enhanced security
- Use GitHub's secret scanning to detect accidental exposure
- Never commit keystore or passwords to repository

## Step 3: Verify Android Project Configuration

### Check android/app/build.gradle

The checked-in release signing block reads `android/key.properties` only. The sample below includes an `android.injected.signing.*` branch that is not in the repo.

```gradle
android {
    // ... other configuration

    signingConfigs {
        release {
            // This will be populated from key.properties file
            if (project.hasProperty('android.injected.signing.store.file')) {
                storeFile file(project.property('android.injected.signing.store.file'))
                storePassword project.property('android.injected.signing.store.password')
                keyAlias project.property('android.injected.signing.key.alias')
                keyPassword project.property('android.injected.signing.key.password')
            } else {
                // Fallback to key.properties file
                def keystorePropertiesFile = rootProject.file("key.properties")
                if (keystorePropertiesFile.exists()) {
                    def keystoreProperties = new Properties()
                    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
                    
                    storeFile file(keystoreProperties['storeFile'])
                    storePassword keystoreProperties['storePassword']
                    keyAlias keystoreProperties['keyAlias']
                    keyPassword keystoreProperties['keyPassword']
                }
            }
        }
    }

    buildTypes {
        release {
            signingConfig signingConfigs.release
            // ... other release configuration
        }
    }
}
```

### Check android/app/src/main/AndroidManifest.xml

SDK levels are not declared in the manifest. `minSdkVersion` and `targetSdkVersion` come from the Flutter Gradle plugin inside `android/app/build.gradle`. The manifest does declare `INTERNET`, `ACCESS_NETWORK_STATE`, and an OAuth callback intent filter with scheme `IAClé` and host `callback`.

### Update pubspec.yaml

Ensure Flutter version constraints are compatible with Android:

```yaml
environment:
  sdk: '>=3.0.0 <4.0.0'
  flutter: '>=3.24.0'

# Verify Android-compatible dependencies
dependencies:
  flutter:
    sdk: flutter
  # ... other dependencies
```

## Build Configuration

The Android job is `build_android` in `.github/workflows/build-mobile.yml`. There is no `build-release.yml`.

### Build Steps

1. Check out `main` and rewrite `pubspec.yaml` / `assets/version.json` with the version from `version.json` and `github.run_number` as the build number.
2. Install Flutter `3.47.7` (match `environment.flutter` in `pubspec.yaml`).
3. Install `platforms;android-37.0` with `sdkmanager` resolved from `ANDROID_HOME`.
4. Decode `ANDROID_KEYSTORE_B64` to `android/release-keystore.jks` and write `android/key.properties`.
5. `flutter pub get`, then `flutter build apk --release --split-per-abi --android-skip-build-dependency-validation`.
6. Upload `build/app/outputs/flutter-apk/*.apk` as the `android-apks` artifact (30 days).
7. `create_release` publishes those APKs on tag `mobile-v{version}` when the Android job succeeded and the iOS job succeeded or was skipped.

## Step 5: Test Android Build Locally

Before enabling in CI/CD, test the build locally:

```bash
# Clean previous builds
flutter clean

# Get dependencies
flutter pub get

# Build Android APK
flutter build apk --release

# Verify APK was created
ls -lh build/app/outputs/flutter-apk/app-release.apk

# Test APK on device or emulator
flutter install
```

### Troubleshooting Local Build

**Issue: Gradle build fails**

```bash
# Clear Gradle cache
cd android
./gradlew clean
cd ..

# Rebuild
flutter build apk --release
```

**Issue: Signing configuration not found**

```bash
# Verify key.properties exists
ls -la android/key.properties

# Check signing configuration in build.gradle
cat android/app/build.gradle | grep -A 10 "signingConfigs"
```

**Issue: SDK licenses not accepted**

```bash
# Accept all SDK licenses
flutter doctor --android-licenses
```

## Testing Android Builds

### Triggering a Build

Android builds start after Web Deploy completes successfully on `main`. Dispatch the mobile workflow directly when you need an APK without that chain:

```bash
gh workflow run "📱 Mobile Build & Release" --ref main
```

Desktop tags matching `v*` do not build Android. Android release tags created by this workflow look like `mobile-v1.1.44`.

### Monitoring the Build

1. **Go to Actions tab** in GitHub repository
2. **Click on the workflow run** to see progress
3. **Expand the Android build job** to see detailed logs
4. **Wait for completion** (~10-15 minutes for first build, ~5-8 minutes with cache)

### Verifying Build Output

After successful build:

1. **Download APKs** from GitHub release or Actions artifacts
2. **Verify APK signatures**:

   ```bash
   # Using apksigner (part of Android SDK build-tools)
   "$ANDROID_HOME"/build-tools/*/apksigner verify --verbose app-arm64-v8a-release.apk
   ```

3. **Test on Android device**:

   ```bash
   # Install via ADB
   adb install app-arm64-v8a-release.apk

   # Launch app. applicationId is app.example.com.
   adb shell am start -n app.example.com/.MainActivity

   # Check logs
   adb logcat | grep -i IAClé
   ```

The mobile workflow does not publish `.sha256` files next to the APKs.

### Testing on Different Architectures

Test each APK on appropriate devices:

- **arm64-v8a**: Modern smartphones (Samsung Galaxy S10+, Pixel 4+, OnePlus 7+)
- **armeabi-v7a**: Older devices (Samsung Galaxy S6, Nexus 5, Moto G4)
- **x86_64**: Android emulators, some tablets (Chromebooks)

## Build Configuration Details

### Target Architectures

The Android build targets three architectures:

- `arm64-v8a` - 64-bit ARM (most modern devices)
- `armeabi-v7a` - 32-bit ARM (older devices)
- `x86_64` - 64-bit x86 (emulators, some tablets)

### Build Command

CI uses split APKs:

```bash
flutter build apk --release --split-per-abi --android-skip-build-dependency-validation
```

A local universal APK is a different command:

```bash
flutter build apk --release --target-platform android-arm,android-arm64,android-x64
```

### Alternative: App Bundle

For Google Play Store distribution, consider using App Bundle instead:

```bash
flutter build appbundle --release
```

App Bundles are smaller and optimized per-device by Google Play.

## Maintenance

### Updating Android SDK

Keep the package id, `compileSdk`, and `compileSdkMinor` together. API 37 is `platforms;android-37.0` with `compileSdk 37` and `compileSdkMinor 0` in `android/app/build.gradle`, installed from `build-mobile.yml`. AGP is `8.11.1` in `android/settings.gradle` and `android/build.gradle`, and the wrapper is Gradle `8.14.3`. Changing only one of those leaves the build looking for a platform package that is not installed.

### Updating Java Version

To update Java version:

```yaml
- name: ☕ Setup Java for Android
  uses: actions/setup-java@v4
  with:
    distribution: 'zulu'
    java-version: '21'  # Update this
```

### Rotating Keystore

If you need to rotate the keystore:

1. Generate new keystore (see Step 1)
2. Update GitHub Secrets with new values
3. Keep old keystore for existing app updates
4. Use new keystore for new apps or major versions

## Troubleshooting

### Build Fails: "Keystore not found"

**Cause**: GitHub Secret not configured or base64 decoding failed

**Solution**:

1. Verify `ANDROID_KEYSTORE_B64` secret exists
2. Re-encode keystore to base64
3. Update secret with new value

### Build Fails: "Signing configuration not found"

**Cause**: `key.properties` file not created or invalid

**Solution**:

1. Check the "Setup Android signing configuration" step logs
2. Verify all signing secrets are set
3. Ensure secret names match exactly

### Build Fails: "SDK licenses not accepted"

**Cause**: Android SDK licenses not accepted in CI

**Solution**:

- The "Setup Android SDK platform 37" step accepts licenses through the `sdkmanager` binary under `ANDROID_HOME`
- On `ubuntu-24.04`, a bare `sdkmanager` on `PATH` is not the command the job runs
- If install fails, read the `sdkmanager install failed` log. The package id is `platforms;android-37.0`

### APK Signature Verification Fails

**Cause**: APK not properly signed or keystore mismatch

**Solution**:

1. Verify keystore password is correct
2. Check key alias matches
3. Ensure signing configuration in `build.gradle` is correct

### Build Succeeds but APK Won't Install

**Cause**: Minimum SDK version too high or permissions issue

**Solution**:

1. Check device Android version (must be 5.0+)
2. Verify `minSdkVersion` in `build.gradle`
3. Check required permissions in `AndroidManifest.xml`

## Build Time Estimates

- Android APK build: ~10-15 minutes
- With cache: ~5-8 minutes
- Total workflow (all platforms): ~20-30 minutes

## Security Considerations

### Keystore Security

- **Never commit keystore** to version control
- Store keystore in secure location (password manager, vault)
- Keep multiple backup copies
- Use strong passwords (16+ characters)

### Secret Management

- Use GitHub Secrets for all sensitive values
- Rotate secrets periodically
- Audit secret access logs
- Use environment-specific secrets for staging/production

### APK Distribution

- Always provide SHA256 checksums
- Sign APKs with release keystore
- Verify APK signature before distribution
- Use HTTPS for download links

## Additional Resources

- [Flutter Android Deployment](https://docs.flutter.dev/deployment/android)
- [Android App Signing](https://developer.android.com/studio/publish/app-signing)
- [GitHub Actions Android](https://github.com/android-actions)
- [Gradle Build Configuration](https://developer.android.com/studio/build)

## Support

If you encounter issues:

1. Check the  guide
2. Review GitHub Actions logs for specific errors
3. Test build locally to isolate CI/CD issues
4. Open an issue with build logs and error messages
