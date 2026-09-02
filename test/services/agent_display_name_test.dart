import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/services/agent_display_name.dart';

void main() {
  test('configuredAgentName falls back when avatar DI is not registered', () {
    expect(configuredAgentName(), kDefaultAgentName);
  });

  test('agentPossessive handles regular names and names ending in s', () {
    expect(agentPossessive('Hermes'), "Hermes'");
    expect(agentPossessive('Ava'), "Ava's");
    expect(agentPossessive('  '), "Agent's");
  });

  test('legacy hardcoded Zoid titles are detected', () {
    expect(isLegacyHardcodedAgentTitle('Zoid Maltek'), isTrue);
    expect(isLegacyHardcodedAgentTitle('Zoid'), isTrue);
    expect(isLegacyHardcodedAgentTitle('Hermes MiniMax'), isFalse);
  });
}
