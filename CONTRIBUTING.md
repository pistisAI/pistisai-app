# Contributing to IAClé

Thanks for showing up. This repository is the IAClé app. The product description is the [README](README.md)
([English](README.en.md)). This guide gets you from "I cloned the repo" to a pull request.

---

## Ways to contribute (no code required)

- **File an issue** with a real use case, a bug, or a failure report.
  Use [GitHub Issues](https://github.com/iacle-solutions/iacle-app/issues).
- **Report a security vulnerability privately** — see [SECURITY.md](SECURITY.md). **Do not**
  open a public issue for security problems.
- **Improve the docs** — fix a typo, clarify a step, add a guide. Docs PRs are the fastest
  path to a merged contribution.
- **Send a code PR** — features, fixes, tests, tooling.

---

## Development setup

IAClé is a Flutter desktop/web app plus Node.js backend services. You need both toolchains.

### Flutter app

- **Dart SDK**: `>=3.5.0 <4.0.0` (the app package name is in `pubspec.yaml`)
- **Flutter**: 3.x stable
- A shared package in `lib/shared` targets Dart `>=3.9.0 <4.0.0`

```bash
git clone https://github.com/iacle-solutions/iacle-app.git
cd iacle-app

flutter pub get
cd lib/shared && flutter pub get && cd ../..   # shared package deps are separate
flutter analyze lib/     # must pass — CI scopes analysis to lib/ (test-file lints are non-blocking)
bash scripts/ci/flutter_security_basic_tests.sh   # CI Flutter gate suite

# Run it
flutter run -d linux     # desktop
flutter run -d chrome    # web
```

If you change Drift database tables or queries, regenerate the codegen:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Do **not** hand-edit generated `*.g.dart` / `*.freezed.dart` files.

### Node.js services

Node services use ESM. Engines:

- `services/api-backend` and `services/streaming-proxy`: Node `>=22.0.0 <27.0.0` (CI pins Node `26` via `.nvmrc`)
- `services/sdk`: Node `>=18.0.0`
- `backend/auth`: CommonJS, no `npm run dev` (run with `node handlers.js`)

```bash
# Root tooling
npm install
npm test                 # api-backend security CI suite only
# npm run test:full      # broader Jest run; many suites are ignore-listed — see jest.config.js

# Per-service (example: api-backend)
cd services/api-backend && npm install && npm test
```

The API backend's tests live at repo root in `test/api-backend/`, not inside the service
directory. See [AGENTS.md](AGENTS.md) for the full command reference per service.

---

## Making a change

We keep it low-ceremony.

1. **Fork** the repo and create a branch off `main`:
   ```bash
   git switch -c my-change
   ```
2. **Make the change.** Keep commits small and real — no stubs, no empty docs.
3. **Verify before pushing:**
   - `flutter analyze lib/` is clean (CI only analyzes `lib/`; `test/` info-lints don't block)
   - `bash scripts/ci/flutter_security_basic_tests.sh` (or the affected suite) passes
   - `npm test` passes for backend/tooling changes (security suite; use per-service tests as needed)
4. **Open a pull request** against `main` with a clear description of what and why.

> (Internal agent contributors follow the push-to-`main` discipline in
> [AGENTS.md](AGENTS.md). External contributors use the fork → PR flow above.)

---

## Commit & PR conventions

- Use **conventional commits**: `feat:`, `fix:`, `docs:`, `chore:`, `test:`, `refactor:`.
- Prefix agent-authored commits with the agent name, e.g. `ai(<agent>): ...`.
- Keep PRs focused. One logical change per PR is easier to review and merge.
- Reference the relevant issue when there is one: `fix: correct wizard clone dir (issue #8)`.

---

## Code style

- **Dart**: `dart format .`; prefer single quotes; `snake_case.dart` files, `PascalCase`
  classes. Strong mode is on (`implicit-casts`/`implicit-dynamic` are false).
- **JS/TS**: match the surrounding `kebab-case` files; `PascalCase` classes.
- Avoid code comments unless the code is genuinely not self-explanatory.
- Preserve branding exactly: `IAClé`, `OpenClaw`, `Zoidbot`.

---

## Where things live

| Area | Path |
|------|------|
| App entry / DI | `lib/main.dart`, `lib/di/locator.dart` |
| Services (router, agents, desktop, vision) | `lib/services/` |
| Architecture docs | `docs/architecture/` |
| Dev / testing guides | `docs/development/` |
| Deployment | `docs/deployment/DEPLOYMENT_OVERVIEW.md` (current), `docs/deployment/SELF_HOSTING.md` |
| Product description and source quick start | `README.md`, `README.en.md`, `docs/LAUNCH.md` |

Full map: [AGENTS.md](AGENTS.md) and [docs/LAUNCH.md](docs/LAUNCH.md).

---

## Questions?

Open an [issue](https://github.com/iacle-solutions/iacle-app/issues) on this repository.
Welcome aboard.
