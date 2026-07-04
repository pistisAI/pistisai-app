# Engineering Standards — pistisAI/pistisai-app

## Objective
Maintain a local-first, review-disciplined codebase for the Pistisai Flutter app and Node backend services. These standards are enforced by CI and accepted in code review.

## Scope
- Flutter app: `lib/`, `android/`, `linux/`, `macos/`, `web/`
- Backend: `services/api-backend/`, `services/streaming-proxy/`, `backend/auth/`
- Shared services: `services/sdk/`, `services/openclaw-skills/`
- Repo tooling: `package.json`, CI workflows, Docker, deploy configs

## Code Quality Gates

### Flutter
- `flutter analyze lib/` must pass before merge.
- `flutter test` must pass for default shared-resource CI path.
- Platform builds require a triggering reason; do not include platform builds in default CI.
- Use `dart run build_runner build --delete-conflicting-outputs` after Drift schema or query changes.
- Do not hand-edit generated `.g.dart` / `.freezed.dart` files.

### Node/TypeScript
- Use Node engines declared in each service `package.json`.
- Run the service-local lint/test commands before opening a PR:
  - API backend: `npm run lint`, `npm test`
  - Streaming proxy: `npm run lint`, `npm test`
  - SDK: `npm run lint`, `npm test`
- Keep `backend/auth/` CommonJS-consistent; do not require `npm run dev` there unless explicitly changed.

### Root tooling
- `npm test` is repo-level Jest; it is not a replacement for service-local tests.
- `npm run lint` and `npm run format` apply to documented backend/services paths.

## Branch Discipline
- Default: push to `main`.
- Use a branch only when Christopher explicitly requests a PR, the change is experimental, or CI feedback is required before landing.
- Branch naming when needed: `<agent>/<change-description>`.

## PR Requirements
- Link the GitHub issue.
- Include what changed, why, verification commands, and risks.
- Keep PRs reviewable; avoid large mixed-purpose PRs.

## Commit Style
- Use conventional commits.
- Prefix agent commits with agent name if written by automation: `ai(<agent>): ...`.

## Security and Secrets
- Do not commit secrets.
- Read secrets from environment variables or secret stores.
- Secret-bearing files and templates live under `config/` and deployment assets.

## CI Expectations
- CI blocks merge on failing quality gates unless explicitly marked non-blocking.
- Jobs should not silently absorb failures with blanket `continue-on-error: true` on test gates.
