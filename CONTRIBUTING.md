# Contributing to Pistisai

Thanks for showing up. Pistisai is **local-first, open, and built in the open** — your
issues, failure reports, and pull requests are the lifeblood of this launch. This guide
gets you from "I cloned the repo" to "my change is in `main`" without surprises.

> Launch anchor issue: [#39 — Paperclip AI — public launch](https://github.com/pistisAI/pistisai-app/issues/39).
> Read it first if you're here from a launch channel. Open an issue or discussion with your
> real use case — that counts as a contribution.

---

## Ways to contribute (no code required)

- **File an issue** with a real use case, a bug, or a failure report.
  Use [GitHub Issues](https://github.com/pistisAI/pistisai-app/issues).
- **Report a security vulnerability privately** — see [SECURITY.md](SECURITY.md). **Do not**
  open a public issue for security problems.
- **Improve the docs** — fix a typo, clarify a step, add a guide. Docs PRs are the fastest
  path to a merged contribution.
- **Send a code PR** — features, fixes, tests, tooling.

---

## Development setup

Pistisai is a Flutter desktop/web app plus Node.js backend services. You need both toolchains.

### Flutter app

- **Dart SDK**: `>=3.5.0 <4.0.0` (the app package `pistisai`)
- **Flutter**: 3.x stable
- A shared package `lib/shared` (`pistisai_shared`) targets Dart `>=3.9.0 <4.0.0`

```bash
git clone https://github.com/pistisAI/pistisai-app.git
cd pistisai-app

flutter pub get
flutter analyze lib/     # must pass — CI scopes analysis to lib/ (test-file lints are non-blocking)
flutter test             # run the app test suite

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

- `services/api-backend` and `services/streaming-proxy`: Node `>=22.0.0 <25.0.0`
- `services/sdk`: Node `>=18.0.0`
- `backend/auth`: CommonJS, no `npm run dev` (run with `node handlers.js`)

```bash
# Root tooling
npm install
npm test                 # ESM Jest, matches **/test/**/*.test.js

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
   - `flutter test` (or the affected suite) passes
   - `npm test` passes for backend/tooling changes
4. **Open a pull request** against `main` with a clear description of what and why.

> (Internal agent contributors follow the push-to-`main` discipline in
> [AGENTS.md](AGENTS.md). External contributors use the fork → PR flow above.)

---

## Commit & PR conventions

- Use **conventional commits**: `feat:`, `fix:`, `docs:`, `chore:`, `test:`, `refactor:`.
- Prefix agent-authored commits with the agent name, e.g. `ai(Paperclip): ...`.
- Keep PRs focused. One logical change per PR is easier to review and merge.
- Reference the relevant issue: `fix: correct wizard clone dir (issue #39)`.

---

## Code style

- **Dart**: `flutter format .`; prefer single quotes; `snake_case.dart` files, `PascalCase`
  classes. Strong mode is on (`implicit-casts`/`implicit-dynamic` are false).
- **JS/TS**: match the surrounding `kebab-case` files; `PascalCase` classes.
- Avoid code comments unless the code is genuinely not self-explanatory.
- Preserve branding exactly: `Pistisai`, `OpenClaw`, `Zoidbot`, and the lobster branding.

---

## Where things live

| Area | Path |
|------|------|
| App entry / DI | `lib/main.dart`, `lib/di/locator.dart` |
| Services (router, agents, desktop, vision) | `lib/services/` |
| Architecture docs | `docs/architecture/` |
| Dev / testing guides | `docs/development/` |
| Deployment | `docs/deployment/DEPLOYMENT_OVERVIEW.md` (current), `DEPLOYMENT.md` (legacy Swarm runbook) |
| Launch content (issue #39 assets) | `docs/LAUNCH.md`, `docs/marketing/publish-ready/`, `cmo-deliverables/` |

Full map: [AGENTS.md](AGENTS.md) and [docs/LAUNCH.md](docs/LAUNCH.md).

---

## Questions?

Open a [Discussion](https://github.com/pistisAI/pistisai-app/discussions) or comment on
[issue #39](https://github.com/pistisAI/pistisai-app/issues/39). Welcome aboard.
