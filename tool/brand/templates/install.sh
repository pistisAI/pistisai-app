#!/bin/bash
# {{product_name}} web bootstrap installer — served from {{website_domain}}/install.sh
# Fetches the full release installer (AppImage + desktop entry + update daemon).
set -euo pipefail
exec bash <(curl -fsSL "{{releases_url}}/download/install.sh") "$@"
