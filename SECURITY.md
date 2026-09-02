# Security Policy

## Reporting a Vulnerability

We take the security of Pistisai seriously. If you discover a security vulnerability, please report it responsibly.

**Do not** open a public GitHub issue. Instead, send details to:

- **Email**: security@pistisai.app
- **GitHub**: Use the private vulnerability reporting tool at:
  https://github.com/pistisAI/pistisai-app/security/advisories

We aim to acknowledge receipt within 48 hours and provide a fix timeline within 5 business days.

## Supported Versions

| Version | Supported |
|---------|-----------|
| Latest release | ✅ |
| Development (main) | ⚠️ Limited |
| Older releases | ❌ |

## Security Measures
- ✅ Every push to `main` is a reviewed commit — the project is owner- and
  agent-maintained with a direct-push-to-`main` model (no PR gating of the
  branch); see `AGENTS.md`. No unreviewed third-party change lands without the
  owner's explicit action.
- ✅ CI runs on every push — automated build and test gates execute on each
  commit to `main`.
- ✅ Secret scanning — automatic detection of leaked credentials
- ✅ Push protection — blocks commits with known secrets
- ✅ CodeQL — code analysis on every push
- ✅ Dependabot — automated dependency updates

## Disclosure Policy

1. Report received → acknowledged within 48h
2. Investigation → timeline shared within 5 business days
3. Fix released → advisory published
4. Public disclosure → 30 days after fix release