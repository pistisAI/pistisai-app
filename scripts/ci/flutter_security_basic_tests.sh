#!/usr/bin/env bash
# CI gate: security-relevant and basic Flutter tests only.
set -euo pipefail

cd "$(dirname "$0")/../.."

flutter test \
  test/smoke/ \
  test/config/ \
  test/models/ \
  test/utils/ \
  test/helpers/ \
  test/services/hermes_gateway_only_transport_test.dart \
  test/services/onboarding/setup_wizard_service_test.dart \
  test/services/session_service_test.dart \
  test/services/connection_manager_service_test.dart \
  test/services/tunnel/ \
  test/services/hermes/ \
  test/services/hermes_manager/main_chat_timeline_trust_store_test.dart \
  test/services/hermes_manager/hermes_gateway_control_service_test.dart \
  test/services/providers/hermes_adapter_test.dart \
  test/services/openclaw_manager/ \
  test/services/desktop_control/ \
  test/widgets/logout_token_clearing_timing_test.dart \
  test/widgets/voice/ \
  test/integration/navigation_test.dart \
  test/integration/settings_integration_test.dart \
  test/integration/evolution_flow_test.dart \
  --reporter expanded \
  --timeout 30s
