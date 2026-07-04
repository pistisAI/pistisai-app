# Engineering Standards — PAP-1 / GH #29

## Objective
Implement engineering standards and dev infrastructure for pistisAI/pistisai-app so that code quality, CI, and review discipline are enforced.

## Acceptance Criteria (from scope)
- Branch/tooling conventions match actual repo (Flutter + Node)
- CI is a blocking quality gate
- flutter analyze lib/
- flutter test for changed paths
- npm run lint / test for backend/services when changed
- Default: push to main. Branch only when Christopher asks or for experimental/CI feedback.
- Branch pattern when used: cto/pap1-infra-29 or similar

## Tooling (actual repo)
- Flutter primary: flutter analyze, flutter test, flutter build
- Root: npm test, npm run lint, npm run format
- Services: services/api-backend, services/streaming-proxy

## CI Gate Policy
Treat build and test as blocking unless explicitly non-blocking.

See child Paperclip tasks PAP-12 and PAP-13.

