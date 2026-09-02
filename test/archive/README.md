# Archived tests

These tests were removed from CI because they are slow, low-signal, or require local
infrastructure (Hermes, Ollama, libsecret) that CI does not provide.

They remain in the repo for optional local regression runs.

## Run locally

```bash
# Legacy theming/responsive/property integration tests
flutter test test/archive/ --reporter expanded --timeout 5m

# Or via npm script from repo root
npm run test:archive:flutter
```

## CI replacement

- **Flutter:** `scripts/ci/flutter_security_basic_tests.sh` (smoke + security/basic allowlist)
- **Backend:** `services/api-backend` → `npm run test:ci:security`

## Contents

| Path | Reason archived |
| --- | --- |
| `archive/integration/*property*` | Unified theming property tests — not security/product gates |
| `archive/integration/*theme*` | Same |
| `archive/integration/local_demo_test.dart` | Requires live Hermes/Ollama/backend on localhost |
| `archive/integration/setup_wizard_test.dart` | Same |
| `archive/widgets/*property*` | Widget property/timing tests — noisy in CI |
