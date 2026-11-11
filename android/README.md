# Android Build Configuration

This directory contains the Android-specific configuration for Pistisai.

## Signing Configuration

### For Local Development

1. **Generate a debug keystore** (if not already present):
   ```bash
   keytool -genkey -v -keystore debug-keystore.jks \
     -keyalg RSA -keysize 2048 -validity 10000 \
     -alias androiddebugkey
   ```

2. **For release builds**, create a release keystore:
   ```bash
   keytool -genkey -v -keystore release-keystore.jks \
     -keyalg RSA -keysize 2048 -validity 10000 \
     -alias release-key
   ```

3. **Create key.properties** from template:
   ```bash
   cp key.properties.template key.properties
   ```

4. **Edit key.properties** with your keystore information:
   ```properties
   storePassword=your-keystore-password
   keyPassword=your-key-password
   keyAlias=release-key
   storeFile=../release-keystore.jks
   ```

### For CI/CD (GitHub Actions)

The CI/CD workflow automatically creates the signing configuration from GitHub Secrets.

**Required GitHub Secrets** (names read by `.github/workflows/build-mobile.yml`):

- `ANDROID_KEYSTORE_BASE64` or `ANDROID_KEYSTORE_B64` - Base64-encoded keystore file
- `ANDROID_KEYSTORE_PASSWORD` or `ANDROID_STORE_PASSWORD` - Keystore password
- `ANDROID_KEY_PASSWORD` — key password
- `ANDROID_KEY_ALIAS` — key alias

`scripts/setup-android-signing.ps1` writes the four secret names above. The older names `ANDROID_KEYSTORE_BASE64` and `ANDROID_KEYSTORE_PASSWORD` are not read by the workflow.

**Setup Instructions:**

See [Android Build Guide](../docs/development/ANDROID_BUILD_GUIDE.md).

## Toolchain

| Piece | Value |
| --- | --- |
| Android Gradle Plugin | 8.11.1 (`android/settings.gradle`) |
| Gradle wrapper | 8.14.3 |
| Kotlin Gradle Plugin | 2.4.0 |
| Flutter CI pin | `pubspec.yaml` → `environment.flutter` (3.47.7) |
| `compileSdk` / `compileSdkMinor` | 37 / 0 |
| SDK package CI installs | `platforms;android-37.0` |
| NDK, minSdk, targetSdk | Flutter's values (`flutter.ndkVersion`, `flutter.minSdkVersion`, `flutter.targetSdkVersion`) |

`platforms;android-37` without the `.0` minor does not match what AGP 8.10.1 requests when `compileSdkMinor` is `0`. On GitHub `ubuntu-24.04` runners, call `sdkmanager` from `$ANDROID_HOME`. It is not on `PATH`.

## Security Notes

⚠️ **IMPORTANT**: Never commit these files to version control:
- `key.properties` - Contains passwords
- `*.jks` - Keystore files
- `*.keystore` - Keystore files

These files are already listed in `.gitignore` to prevent accidental commits.

## Android test rig (hub in Docker + phone/emulator)

Same idea as the Linux **test-desktop** rig (`docker-compose.test.yml`): a containerized Pistisai desktop hub (router on **:1337**, `the hub endpoint`) plus on-device Flutter integration tests.

```bash
# Hub + on-device tests (or use run_android_test_rig.sh — same flags)
bash scripts/run_integration_test_rig.sh --android-only

# Hub only — manual testing, VNC on :5900
bash scripts/run_integration_test_rig.sh --android-only --no-tests --keep-running

# Hub already running
bash scripts/run_integration_test_rig.sh --android-only --no-hub --hub-host 10.0.2.2   # emulator
bash scripts/run_integration_test_rig.sh --android-only --no-hub --hub-host 100.x.x.x  # phone → PC Tailscale IP

# Desktop + phone in one run (skips Android if no device)
bash scripts/run_integration_test_rig.sh
```

Same hub as the Linux rig: `docker-compose.test.yml`.

**On your PC (automated rig uses an emulator, not your USB phone):**

```bash
bash scripts/setup-android-test-emulator.sh   # once
bash scripts/run_pc_integration_test_rig.sh
```

USB phone smoke: `scripts/test-android-phone.sh`. Docs: `docs/development/testing/PHYSICAL_INTEGRATION_TEST_RIG.md`. Cloud CI: `integration-test-rig.yml`. Optional self-hosted PC: `integration-test-rig-physical.yml`.

### Phone-only smoke (no Docker hub)

```bash
bash scripts/test-android-phone.sh
# Set the hub-host variable named in scripts/test-android-phone.sh, then:
bash scripts/test-android-phone.sh
```

Optional: `ANDROID_DEVICE_ID` if multiple devices are attached.

## Building Android APK

### Debug Build

```bash
# From project root
flutter build apk --debug
```

### Release Build

```bash
# From project root
flutter build apk --release
```

The release build requires proper signing configuration (key.properties and keystore).

### Build for Specific Architectures

```bash
# ARM 64-bit only (most modern devices)
flutter build apk --release --target-platform android-arm64

# ARM 32-bit only (older devices)
flutter build apk --release --target-platform android-arm

# All architectures (fat APK)
flutter build apk --release --target-platform android-arm,android-arm64,android-x64
```

## Testing

### Install on Device

```bash
# Install debug build
flutter install

# Install specific APK
adb install build/app/outputs/flutter-apk/app-release.apk
```

### Run on Device

```bash
# Run debug build
flutter run

# Run release build
flutter run --release
```

## Troubleshooting

### "Keystore not found"

**Solution**: Ensure `key.properties` exists and `storeFile` path is correct.

### "Signing configuration not found"

**Solution**: Check that `android/app/build.gradle` has the signing configuration block.

### "SDK licenses not accepted"

**Solution**: Locally, run `flutter doctor --android-licenses`. In CI, the mobile workflow runs `yes | "$SDKMANAGER" --licenses` using the binary under `ANDROID_HOME`, then installs `platforms;android-37.0`.

### Build fails with Gradle errors

**Solution**: 
```bash
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
flutter build apk --release
```

## Additional Resources

- [Flutter Android Deployment](https://docs.flutter.dev/deployment/android)
- [Android App Signing](https://developer.android.com/studio/publish/app-signing)
- [Android Build Guide](../docs/development/ANDROID_BUILD_GUIDE.md) 
