# White-label builds

A downstream repository can ship this stack under its own name. Keep the brand files as the only committed difference from upstream `main`. Regenerate the baked brand after each merge.

## Brand folder

Each brand is a directory:

```text
brand/<id>/brand.yaml
brand/<id>/assets/logo.png
brand/<id>/assets/icon.png
```

`brand/pistisai/` is the upstream product. `brand/example/` is a placeholder with no real company behind it. Copy `brand/example/` to `brand/<id>/` and replace the fields.

`brand.yaml` holds the product name, short name, company name, tagline, support email and URL, privacy email, website, app URL, default locale, logo and icon paths, colors, app id, bundle id, Linux application id, executable name, window title, about text, closing line, legal line, copyright lines, repository, docs URL, release URL, and the strings used on the website and desktop metadata.

The default locale is applied only when `lock_locale` is `true`. The upstream brand leaves it `false` and does not set `locale` or `supportedLocales`, so Material resolution stays as it was. A locked brand sets its locale and loads Flutter's French and English localizations.

Logo and icon paths must be listed under `flutter: assets:` in `pubspec.yaml` (a directory entry per brand folder).

## Build

From the repository root:

```bash
tool/brand.sh <id>
flutter build linux --dart-define=BRAND=<id>
```

Use `apk`, `web`, `windows`, or `macos` the same way. `tool/brand.sh` with no argument bakes `pistisai`.

The script writes the brand into the Flutter app and into the window title, Android display name, macOS product name, Linux desktop `Name`, Windows version info, installer display name, web title, and the privacy and terms pages. `--dart-define=BRAND=<id>` must match the id you just baked. A define on its own does not change copy.

### Paid whitelabel brands

The upstream brand (`pistisai`) bakes freely. **Every other brand is a paid whitelabel and requires a licence.** `tool/brand.sh` refuses to bake a non-upstream brand without one:

```bash
python3 tool/issue_licence.py \
  --key /path/to/private.key \
  --brand iacle --licensee "IAClé" \
  --expires 2027-12-31 --seats 5 \
  --out iacle.licence

tool/brand.sh iacle --license iacle.licence
flutter build linux --dart-define=BRAND=iacle
```

The licence is an Ed25519-signed JSON document. The public key is embedded in `lib/brand/brand_licence.dart`; the private key stays with the licensor and never enters the repository. Verification is offline — no server call. A licence that is missing, tampered with, for another brand, or expired makes the bake exit non-zero (`65` invalid, `66` missing).

Only the *bake* is gated. A binary produced from a licensed build can still be redistributed; closing that needs runtime entitlement, which is not implemented.

After merging upstream `main`, run `tool/brand.sh <id>` again before building. Do not hand-edit the generated files (`lib/brand/active_brand.g.dart`, `linux/runner/brand_config.h`, `windows/runner/brand_config.h`, `macos/Runner/Configs/Brand.xcconfig`, `android/app/src/main/res/values/brand_strings.xml`).

## Not switched yet

These stay as they are in upstream. The brand file records some of them so a later build can pick them up. The current build does not rename them:

- Dart package name `pistisai`, and type names that include it
- Linux binary name `pistisai` (`linux/CMakeLists.txt` `BINARY_NAME`) and Windows `Pistisai.exe`
- Linux `APPLICATION_ID` (`app.pistisai.pistisai`) and the Flatpak / AppStream component id
- Android `applicationId` (`app.pistisai.app`) and the OAuth scheme `Pistisai`
- macOS `PRODUCT_BUNDLE_IDENTIFIER`
- URL schemes `pistisai://` and `com.pistisai.app://`
- Hub path `GET /api/pistisai/hub`
- API hosts such as `api.pistisai.app`, the admin host, Supabase, and Sentry
- Web Content-Security-Policy host list
- Hermes platform id `pistisai` and the on-disk Hermes package directory
- Settings export prefix `Pistisai-settings` and the local data directory `Pistisai`
- Desktop `Exec`, `Icon`, and `StartupWMClass` entries, which follow the binary name
- Kubernetes namespaces, package manifests, and internal log lines

`executable_name`, `app_id`, `bundle_id`, and `linux_application_id` in `brand.yaml` are stored for the brand. Only the user-facing window title, launcher label, and installer display name are rewritten today. Download links in the app use `releases_url` and `artifact_prefix`. The Linux and Windows launch instructions still name the binaries this build emits (`pistisai` and `Pistisai.exe`). The macOS quarantine hint uses the product name, which `Brand.xcconfig` applies as `PRODUCT_NAME`. Upstream release files are still published with the upstream artifact names until a brand publishes its own.
