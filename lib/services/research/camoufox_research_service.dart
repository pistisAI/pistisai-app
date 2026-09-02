import 'package:flutter/foundation.dart';

/// Minimal Camoufox research integration with audit logging.
///
/// Full browser automation remains out of scope; this wrapper records intent
/// and delegates to the repository script when enabled.
class CamoufoxResearchService {
  CamoufoxResearchService();

  final List<Map<String, dynamic>> _auditLog = [];

  List<Map<String, dynamic>> get auditLog => List.unmodifiable(_auditLog);

  Future<CamoufoxResearchResult> runDuckDuckGoSearch(String query) async {
    final entry = {
      'action': 'camoufox.ddg_search',
      'query': query,
      'timestamp': DateTime.now().toIso8601String(),
      'status': 'requested',
    };
    _auditLog.add(entry);

    debugPrint('[CamoufoxResearch] Audit: $entry');

    return CamoufoxResearchResult(
      query: query,
      status: CamoufoxResearchStatus.notConfigured,
      message:
          'Camoufox script integration is available at scripts/camoufox_ddg_search.py. '
          'Enable host Python + camoufox package to run live searches.',
    );
  }
}

enum CamoufoxResearchStatus { notConfigured, completed, failed }

class CamoufoxResearchResult {
  final String query;
  final CamoufoxResearchStatus status;
  final String message;

  const CamoufoxResearchResult({
    required this.query,
    required this.status,
    required this.message,
  });
}
