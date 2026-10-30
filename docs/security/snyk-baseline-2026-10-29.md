# PistisAI — Snyk Security Baseline (2026-10-29)

Organization: `imrightguy` (authenticated via headless OAuth, snyk CLI 1.1308.3)
Repo: `/mnt/DATA/dev/projects/pistisai-app`, branch `feat/sentry-runtime-wiring`

## Software Composition Analysis (SCA)

### services/api-backend — `pistisai-api-backend`
| Severity | Vuln | Package | Fix | Chain |
|---|---|---|---|---|
| HIGH | Insertion of Sensitive Info Into Sent Data | follow-redirects@1.16.1 | 1.16.2 | axios@1.20.0 > follow-redirects |
| MEDIUM | Improper Encoding/Escaping of Output | qs@6.16.1 | 6.16.2 | express@5.3.0>qs (+2 paths) |

**2 open, 0 critical, 1 high, 1 medium.**

### services/streaming-proxy — `Pistisai-tunnel-container`
| Severity | Vuln | Package | Fix | Chain |
|---|---|---|---|---|
| MEDIUM | Improper Encoding/Escaping of Output | qs@6.16.1 | 6.16.2 | express@5.3.0>qs (+1 path) |

**1 open, 0 critical, 0 high, 1 medium.**

### services/tailscale-relay
**Not scannable** — missing `node_modules` (audit issue #459, still genuinely open). Run `npm install` there before scanning.

## SBOM (api-backend)
Generated as CycloneDX 1.5 (`snyk sbom --format=cyclonedx1.5+json`): 424 components incl. express@5.3.0, axios@1.20.0, pg@8.23.1, stripe@22.6.2, zod@4.6.7, winston@3.19.0.

## Snyk Code (SAST)
**Not enabled** for org `imrightguy` (SNYK-CODE-0005, HTTP 403). Needs Snyk Code activation on the org, or the `pistisai` org with Code enabled, before SAST can run.

## Notes
- Same fix (qs 6.16.1 → 6.16.2, follow-redirects 1.16.1 → 1.16.2) appears in both services — a `require` bump on express/axios transitive deps clears 2 of 3 findings.
- tailscale-relay scan block ties to audit issues #459/#463.
- No 1Password or secrets touched during this baseline.
