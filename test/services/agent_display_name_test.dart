import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/services/agent_display_name.dart';

void main() {
  test('parseHermesAgentName reads the configured agent name', () {
    expect(
      parseHermesAgentName('OTHER=1\nA2A_AGENT_NAME=Zoid\n'),
      'Zoid',
    );
    expect(
      parseHermesAgentName('# comment\nA2A_AGENT_NAME="hermes"\n'),
      'hermes',
    );
    expect(parseHermesAgentName('API_SERVER_ENABLED=true\n'), isNull);
  });

  test('connectedAgentDisplayName prefers the Hermes config name', () {
    expect(
      connectedAgentDisplayName(hermesEnv: 'A2A_AGENT_NAME=Zoid\n'),
      'Zoid',
    );
    expect(
      connectedAgentDisplayName(hermesEnv: 'A2A_AGENT_NAME=hermes\n'),
      'hermes',
    );
  });

  test('connectedAgentDisplayName falls back when Hermes has no name', () {
    expect(connectedAgentDisplayName(hermesEnv: ''), kDefaultAgentName);
  });

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
