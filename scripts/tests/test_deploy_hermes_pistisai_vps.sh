#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEPLOY_SCRIPT="$PROJECT_ROOT/scripts/deploy-hermes-pistisai-vps.sh"
WORKFLOW="$PROJECT_ROOT/.github/workflows/deploy-hermes.yml"
WEB_WORKFLOW="$PROJECT_ROOT/.github/workflows/deploy-web.yml"
COMPOSE="$PROJECT_ROOT/deploy/hermes/docker-compose.hermes.yml"
CONFIG="$PROJECT_ROOT/deploy/hermes/config.yaml"
SOUL="$PROJECT_ROOT/deploy/hermes/SOUL.md"
MULTI="$PROJECT_ROOT/docker-compose.multi.yml"

for path in "$DEPLOY_SCRIPT" "$WORKFLOW" "$WEB_WORKFLOW" "$COMPOSE" "$CONFIG" "$SOUL" "$MULTI"; do
  if [[ ! -f "$path" ]]; then
    echo "Missing $path" >&2
    exit 1
  fi
done

python3 - <<'PY' "$DEPLOY_SCRIPT" "$WORKFLOW" "$WEB_WORKFLOW" "$COMPOSE" "$CONFIG" "$SOUL" "$MULTI"
from pathlib import Path
import sys

deploy, workflow, web_workflow, compose, config, soul, multi = map(Path, sys.argv[1:])
deploy_text = deploy.read_text()
workflow_text = workflow.read_text()
web_text = web_workflow.read_text()
compose_text = compose.read_text()
config_text = config.read_text()
soul_text = soul.read_text()
multi_text = multi.read_text()

required_deploy = [
    'VPS_HOST="${VPS_HOST:-${PISTISAI_VPS_HOST:-pistisai.app}}"',
    'VPS_USER="${VPS_USER:-${PISTISAI_VPS_USER:-cloudllm}}"',
    'REMOTE_DIR="${REMOTE_DIR:-${PISTISAI_REMOTE_DIR:-/opt/Pistisai}}"',
    "ignoring Simon VPS host",
    'deploy/hermes/docker-compose.hermes.yml',
    'https://api.pistisai.app/hermes/health',
    'https://pistisai.app/hermes/health',
]
for needle in required_deploy:
    if needle not in deploy_text:
        raise SystemExit(f'missing deploy script string: {needle}')

if 'HostName ${VPS_HOST}' in deploy_text and '31.97.140.7' in deploy_text.split('VPS_HOST=', 1)[-1][:80]:
    raise SystemExit('deploy script still uses Simon VPS as SSH host')

required_workflow = [
    "secrets.VPS_HOST || 'pistisai.app'",
    "secrets.VPS_USER || 'cloudllm'",
    'REMOTE_DIR=/opt/Pistisai',
    'https://api.pistisai.app/hermes/health',
    'https://pistisai.app/hermes/health',
    'Ignoring Simon VPS host',
    'skipping live VPS deploy',
]
for needle in required_workflow:
    if needle not in workflow_text:
        raise SystemExit(f'missing workflow string: {needle}')

if "secrets.VPS_HOST || '31.97.140.7'" in workflow_text:
    raise SystemExit('Hermes workflow must not fall back to Simon VPS')
if "secrets.VPS_USER || 'pistisai'" in workflow_text:
    raise SystemExit('Hermes workflow must not fall back to Simon SSH user')

required_web = [
    "secrets.VPS_HOST || 'pistisai.app'",
    "secrets.VPS_USER || 'cloudllm'",
    '/opt/Pistisai',
    'https://app.pistisai.app/health',
    'skipping live VPS deploy',
]
for needle in required_web:
    if needle not in web_text:
        raise SystemExit(f'missing web deploy string: {needle}')
if "secrets.VPS_HOST || '31.97.140.7'" in web_text:
    raise SystemExit('web deploy must not fall back to Simon VPS')
if "secrets.VPS_USER || 'pistisai'" in web_text:
    raise SystemExit('web deploy must not fall back to Simon SSH user')
if "/opt/pistisai/deploy" in web_text:
    raise SystemExit('web deploy still targets Simon deploy dir')
if '31.97.140.7' in web_text and 'Ignoring Simon VPS host' not in web_text:
    raise SystemExit('web deploy mentions Simon VPS without remapping it')

required_compose = [
    'nousresearch/hermes-agent',
    'API_SERVER_ENABLED',
    '127.0.0.1:8642:8642',
    'pistisai-network',
    'external: true',
]
for needle in required_compose:
    if needle not in compose_text:
        raise SystemExit(f'missing compose string: {needle}')

if '0.0.0.0:8642' in compose_text or '0.0.0.0:8642' in multi_text:
    raise SystemExit('Hermes must not publish 8642 on all interfaces')

if 'provider: opencode-free' not in config_text:
    raise SystemExit('config.yaml must use opencode-free')
if 'nemotron-3.5-lightning-free' not in config_text:
    raise SystemExit('config.yaml must default to nemotron-3.5-lightning-free')
if 'pistisai.app' not in soul_text:
    raise SystemExit('SOUL.md must identify the pistisai.app agent')
if 'container_name: pistisai-hermes' not in multi_text:
    raise SystemExit('docker-compose.multi.yml must define pistisai-hermes')

web_nginx = Path(sys.argv[1]).parents[1] / 'config/docker/nginx-web.conf'
flutter_nginx = Path(sys.argv[1]).parents[1] / 'config/nginx/nginx-flutter.conf'
for nginx_path in (web_nginx, flutter_nginx):
    text = nginx_path.read_text()
    if 'location /hermes/' not in text or 'proxy_pass http://hermes:8642/' not in text:
        raise SystemExit(f'{nginx_path.name} must proxy /hermes/ to hermes:8642')

print('[test_deploy_hermes_pistisai_vps] Passed')
PY
