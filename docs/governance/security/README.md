# Security Documentation

This directory contains security policies and procedures for Pistisai. The
statements below describe what is implemented in this repository; they do not
claim a certification, audit, or control that has not been verified here.

## Contents

- [Permissions](permissions.json) — permission and access-control configuration

Related documentation: operations and deployment guides, and the legal/privacy
documents under `docs/governance/legal/`.

## Implementation notes (checked against this repository)

- **Local-first defaults.** Cloud integrations are opt-in from
  Settings → General; see `docs/governance/legal/CLOUD_PROVIDER_DATA_FLOW.md`
  and `docs/governance/legal/PRIVACY.md`.
- **Authentication.** The app's sign-in provider is Cloudflare Access
  (`lib/auth/providers/cloudflare_access_auth_provider.dart`). There is no Auth0
  provider in `lib/`.
- **Credential storage.** `flutter_secure_storage` is used by
  `lib/services/token_storage_service.dart`, `device_identity_service.dart`,
  `setup_status_service.dart` and `admin_data_flush_service.dart`.
- **Backend authorization.** Role-based checks and JWT validation live in
  `services/api-backend/middleware/admin-auth.js` and `rbac.js`.
- **Audit logging.** Admin routes record activity; see
  `services/api-backend/routes/admin/audit.js`.
- **Error reporting.** Sentry integration exists in `lib/config/app_config.dart`,
  `lib/main.dart`, `lib/widgets/settings/crash_reporting_tile.dart` and
  `services/api-backend/services/error-notification-service.js`; it is exposed
  as a user-facing setting, not an unconditional telemetry path.
- **CI security gates.** `scripts/ci/flutter_security_basic_tests.sh` and
  `services/api-backend/jest.ci-security.config.js` run restricted security and
  regression suites in CI.
- **Transport and local services.** Public hosted endpoints are served over
  HTTPS in the standard deployment. Local services bind to loopback by default
  unless another device must reach them, in which case a token is required
  (see `AGENTS.md`).

## Not claimed here

The following are **not** evidenced by this repository and must not be presented
as facts about the product: end-to-end encryption of all communications,
SOC 2 Type II, GDPR certification, routine penetration testing, OWASP compliance,
or a "zero trust" architecture. Any such claim needs its own verification and a
recorded decision before it is added.

## Incident response (guidance, not an automated feature)

1. Detection — monitoring and user reports
2. Assessment — evaluate scope and impact
3. Containment — isolate the affected component
4. Eradication — remove the cause
5. Recovery — restore normal operation
6. Lessons learned — record the outcome and update this guide
