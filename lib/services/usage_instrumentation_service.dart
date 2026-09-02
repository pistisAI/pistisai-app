import 'package:uuid/uuid.dart';

import '../database/drift_local_brain.dart';

class UsageInstrumentationService {
  UsageInstrumentationService(this._db);

  final LocalBrain _db;
  final _uuid = const Uuid();
  final Map<String, String> _activeRequestIds = {};

  Future<String> startRequest(String modelId) async {
    final requestId = _uuid.v4();
    final normalizedModel = modelId.isEmpty ? 'default' : modelId;
    _activeRequestIds[normalizedModel] = requestId;
    await _db.recordLlmRequest(
      requestId: requestId,
      modelId: normalizedModel,
    );
    return requestId;
  }

  Future<void> completeRequest({
    required String modelId,
    required String status,
    int? promptTokens,
    int? completionTokens,
    String? errorMessage,
  }) async {
    final normalizedModel = modelId.isEmpty ? 'default' : modelId;
    final requestId = _activeRequestIds.remove(normalizedModel);
    if (requestId == null) {
      return;
    }

    await _db.completeLlmRequest(
      requestId: requestId,
      status: status,
      promptTokens: promptTokens,
      completionTokens: completionTokens,
      errorMessage: errorMessage,
    );
  }

  Future<List<LlmRequest>> getRequestsSince(DateTime since) =>
      _db.getLlmRequestsSince(since);

  Future<UsageChartData> buildChartData(DateTime since) async {
    final requests = await getRequestsSince(since);
    final tokenBuckets = <DateTime, int>{};
    final requestBuckets = <DateTime, int>{};

    for (final request in requests) {
      final bucket = DateTime(
        request.startedAt.year,
        request.startedAt.month,
        request.startedAt.day,
        request.startedAt.hour,
      );
      requestBuckets[bucket] = (requestBuckets[bucket] ?? 0) + 1;
      final tokens =
          (request.promptTokens ?? 0) + (request.completionTokens ?? 0);
      tokenBuckets[bucket] = (tokenBuckets[bucket] ?? 0) + tokens;
    }

    final sortedKeys = requestBuckets.keys.toList()..sort();
    return UsageChartData(
      labels: sortedKeys,
      requestCounts: sortedKeys.map((k) => requestBuckets[k] ?? 0).toList(),
      tokenTotals: sortedKeys.map((k) => tokenBuckets[k] ?? 0).toList(),
      totalRequests: requests.length,
      totalTokens: requests.fold<int>(
        0,
        (sum, request) =>
            sum + (request.promptTokens ?? 0) + (request.completionTokens ?? 0),
      ),
    );
  }
}

class UsageChartData {
  final List<DateTime> labels;
  final List<int> requestCounts;
  final List<int> tokenTotals;
  final int totalRequests;
  final int totalTokens;

  const UsageChartData({
    required this.labels,
    required this.requestCounts,
    required this.tokenTotals,
    required this.totalRequests,
    required this.totalTokens,
  });
}
