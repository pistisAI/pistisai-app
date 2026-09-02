import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/services/research/camoufox_research_service.dart';

void main() {
  test('records audit log entries for research requests', () async {
    final service = CamoufoxResearchService();
    final result = await service.runDuckDuckGoSearch('pistisai architecture');

    expect(result.query, 'pistisai architecture');
    expect(service.auditLog, isNotEmpty);
    expect(service.auditLog.first['action'], 'camoufox.ddg_search');
  });
}
