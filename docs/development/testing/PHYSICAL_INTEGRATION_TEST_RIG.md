# Local PC integration test rig (emulator + Docker hub)

Automated rig on your Linux PC — same shape as cloud CI:

| Layer | What |
|--------|------|
| Desktop hub | Docker `test-desktop` (`:1337`, VNC `:5900`) |
| Linux client | Host `dart test` → `localhost:1337` |
| Android client | **Emulator** on the PC (`10.0.2.2` → host hub) |

Your **physical phone is not part of this rig**. Use it manually, or run `scripts/test-android-phone.sh` for ad-hoc USB smoke tests.

## One-time emulator setup

```bash
bash scripts/setup-android-test-emulator.sh
```

Creates the AVD named by that script (API 34, Pixel 6 profile — aligned with CI).

## Run the full rig

```bash
bash scripts/run_pc_integration_test_rig.sh
```

(`run_right_pc_integration_rig.sh` is the same entry point.)

This starts the emulator if needed, brings up the Docker hub, runs Linux integration tests, then Android tests on the **emulator** with hub probe host `10.0.2.2`.

Faster reruns after the image exists:

```bash
bash scripts/run_pc_integration_test_rig.sh --no-docker-build
```

## Phone vs emulator

| Goal | Command |
|------|---------|
| PC test rig (CI-like) | `run_pc_integration_test_rig.sh` |
| USB phone smoke / Tailscale probe | `test-android-phone.sh` |
| Force USB in unified script | `run_integration_test_rig.sh --usb-android` |

## Prerequisites

- Docker running
- Flutter + JDK 21 for Android builds
- KVM / emulator libs (see `scripts/setup-development-environment.sh` on CachyOS)
- Optional self-hosted runner: `scripts/setup-integration-rig-runner.sh` + workflow **Integration Test Rig (Physical USB)** → rename in UI is still that file but job uses emulator via `run_pc_integration_test_rig.sh`
