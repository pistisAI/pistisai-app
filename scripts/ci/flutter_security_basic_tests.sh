#!/usr/bin/env bash
# CI gate: security-relevant and basic Flutter tests only.
set -euo pipefail

cd "$(dirname "$0")/../.."

flutter test \
  --dart-define=BRAND=pistisai \
  test/database/local_brain_encryption_test.dart \
  test/smoke/ \
  test/config/ \
  test/services/onboarding/mobile_connection_service_test.dart \
  test/screens/onboarding/mobile_connection_screen_test.dart \
  test/models/ \
  test/utils/ \
  test/helpers/ \
  test/services/local_conversation_storage_test.dart \
  test/services/settings_hermes_api_key_storage_test.dart \
  test/services/session_token_secure_storage_test.dart \
  test/services/hermes_gateway_only_transport_test.dart \
  test/services/onboarding/setup_wizard_service_test.dart \
  test/services/session_service_test.dart \
  test/services/connection_manager_service_test.dart \
  test/services/tunnel/ \
  test/services/hermes/ \
  test/services/hermes_manager/main_chat_timeline_trust_store_test.dart \
  test/services/hermes_manager/hermes_gateway_control_service_test.dart \
  test/services/providers/hermes_adapter_test.dart \
  test/services/provider_discovery_service_test.dart \
  test/services/local_agent_data_portability_service_test.dart \
  test/services/approval_gate_service_test.dart \
  test/widgets/approval/ \
  test/widgets/common/refreshable_screen_test.dart \
  test/widgets/management_screens_test.dart \
  test/widgets/navigation/popout_button_test.dart \
  test/screens/usage_screen_test.dart \
  test/screens/skills_screen_test.dart \
  test/screens/nodes_screen_test.dart \
  test/services/subagent_registry_service_test.dart \
  test/services/cloud_zero_egress_test.dart \
  test/services/avatar/avatar_progress_test.dart \
  test/services/avatar/avatar_appearance_test.dart \
  test/services/avatar/avatar_personality_publish_test.dart \
  test/screens/sessions/ \
  test/screens/channels/ \
  test/services/channel_service_test.dart \
  test/screens/settings/llm_provider_settings_status_test.dart \
  test/screens/settings/connection_settings_rerun_wizard_test.dart \
  test/services/agent_action_audit_service_test.dart \
  test/services/openclaw_manager/ \
  test/services/desktop_control/ \
  test/services/agent_runtime/runtime_status_snapshot_test.dart \
  test/screens/instances/instances_screen_test.dart \
  test/screens/logs_screen_test.dart \
  test/widgets/overview_screen_test.dart \
  test/widgets/logout_token_clearing_timing_test.dart \
  test/widgets/voice/ \
  test/integration/navigation_test.dart \
  test/integration/settings_integration_test.dart \
  test/integration/evolution_flow_test.dart \
  --reporter expanded \
  --timeout 30s
