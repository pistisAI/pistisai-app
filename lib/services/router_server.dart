import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';

import 'providers/base_provider.dart';
import 'rate_limit_manager.dart';
import 'model_tiers.dart';
import 'avatar/personality_engine.dart';
import 'avatar/evolution_tracker.dart';
import 'conscience_storage_service.dart';
import 'cloud_outbound_policy.dart';
import 'voice/cloud_tts_service.dart';
import 'package:pistisai/brand/brand.dart';
import 'package:pistisai/config/app_config.dart';
import 'package:pistisai/models/avatar/personality_models.dart';
import 'package:http/http.dart' as http;

/// Async gate for optional outbound cloud features. Fail closed when null.
typedef CloudConsentChecker = Future<bool> Function();

/// Local HTTP Server that mimics OpenAI API and routes to providers.
///
/// By default the server binds to loopback only. When [allowRemoteAccess] is
/// true it binds to every interface so other devices can discover the desktop
/// hub, and an [authSecret] is always present (generated if not supplied).
/// Only the public paths (`/health`, `/v1/models`, the hub discovery document)
/// are reachable from another machine without that token.
///
/// When [authSecret] is non-null, every non-public endpoint requires a valid
/// `Bearer <authSecret>` header, from any address. Requests without a token
/// receive 403; requests with the wrong token receive 401.
///
/// When [authSecret] is null (loopback-only mode), non-public endpoints answer
/// only loopback callers (Hermes and the app on this machine). A request from
/// another address receives 403.
class RouterServer {
  final int port;
  final RateLimitManager rateLimitManager;
  final Map<String, LlmProvider> providers;
  final PersonalityEngine? personalityEngine;
  final EvolutionTracker? evolutionTracker;
  final ConscienceStorageService? conscienceStorage;
  final CloudTtsService? ttsService;

  /// When false, Zhipu / Moonshot / Gemini calls are refused even if registered.
  final CloudConsentChecker? cloudLlmAllowed;

  /// When false, Microsoft online speech synthesis is refused.
  final CloudConsentChecker? microsoftSpeechAllowed;

  /// Bearer token required for privileged endpoints.
  /// When null, non-public endpoints accept loopback callers only.
  final String? authSecret;

  /// When false (default) the router listens on loopback only. When true,
  /// binds all interfaces and always has an [authSecret] (generated if not
  /// supplied) that gates every private endpoint.
  final bool allowRemoteAccess;

  /// Co-resident Hermes gateway. Only the primary hub dials this;
  /// remote clients must use this router instead.
  final String hermesBaseUrl;

  HttpServer? _server;

  /// Endpoints that remain accessible without authentication.
  static const _publicPaths = {
    '/health',
    '/v1/models',
    AppConfig.hubPath,
  };

  RouterServer({
    this.port = 1337,
    required this.rateLimitManager,
    required this.providers,
    this.personalityEngine,
    this.evolutionTracker,
    this.conscienceStorage,
    this.ttsService,
    this.cloudLlmAllowed,
    this.microsoftSpeechAllowed,
    String? authSecret,
    this.allowRemoteAccess = false,
    String? hermesBaseUrl,
  })  : authSecret = _resolveAuthSecret(
          allowRemoteAccess: allowRemoteAccess,
          provided: authSecret,
        ),
        hermesBaseUrl = hermesBaseUrl ?? AppConfig.defaultHermesUrl;

  static String? _resolveAuthSecret({
    required bool allowRemoteAccess,
    required String? provided,
  }) {
    if (!allowRemoteAccess) return provided;
    if (provided != null && provided.isNotEmpty) return provided;
    return _generateAuthSecret();
  }

  /// Generate a URL-safe bearer token. Used by the opt-in remote hub setting
  /// so the token is stable across restarts instead of being regenerated on
  /// every bind (#861).
  static String generateAuthSecret() => _generateAuthSecret();

  static String _generateAuthSecret() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(32, (_) => rnd.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  /// Logs exception details locally; returns a response with no path/leak text.
  static Response _safeErrorResponse(
    Object error, {
    required int statusCode,
    bool asJson = false,
  }) {
    debugPrint('RouterServer error: $error');
    final body =
        asJson ? jsonEncode({'error': 'Request failed'}) : 'Request failed';
    return Response(
      statusCode,
      body: body,
      headers: asJson ? {'Content-Type': 'application/json'} : null,
    );
  }

  /// Start the server
  Future<void> start() async {
    final router = Router();

    // GET /v1/models
    router.get('/v1/models', _handleListModels);

    // POST /v1/chat/completions
    router.post('/v1/chat/completions', _handleChatCompletions);

    // GET /health
    router.get('/health', (Request request) => Response.ok('OK'));

    // GET /api/pistisai/hub — mobile clients discover the primary desktop hub.
    router.get(AppConfig.hubPath, _handleHub);

    // Hermes chat/session APIs for non-primary clients (proxied to local Hermes).
    router.post('/api/pistisai/messages', _proxyHermes);
    router.get('/api/sessions', _proxyHermes);
    router.get('/api/sessions/<sessionId>/messages', _proxyHermes);
    router.all('/api/sessions/<sessionId>', _proxyHermes);

    // OpenAI-compatible local speech endpoint for Hermes voice output.
    if (ttsService != null) {
      router.post('/v1/audio/speech', _handleAudioSpeech);
      router.get('/v1/audio/voices', _handleListVoices);
    }

    // Avatar Evolution API endpoints
    if (personalityEngine != null) {
      router.get('/avatar/state', _handleGetAvatarState);
      router.post('/avatar/traits', _handleUpdateTraits);
      router.post('/avatar/evolution/request', _handleEvolutionRequest);
      router.post(
          '/api/evolution', _handleEvolutionRequest); // Harmonized endpoint
    }

    // Conscience System API endpoints (Phase 1 - Storage Layer)
    if (conscienceStorage != null) {
      router.post('/api/conscience/thoughts', _handleWriteThought);
      router.get('/api/conscience/thoughts', _handleGetThoughts);
      router.post('/api/conscience/decisions', _handleWriteDecision);
      router.get('/api/conscience/decisions', _handleGetDecisions);
      router.put('/api/conscience/decisions/verdict', _handleSubmitVerdict);
    }

    final handler = const Pipeline()
        .addMiddleware(logRequests())
        .addMiddleware(_authMiddleware())
        .addHandler(router.call);

    // Loopback unless remote access is explicitly enabled (see #645).
    final bindAddress = allowRemoteAccess
        ? InternetAddress.anyIPv4
        : InternetAddress.loopbackIPv4;
    _server = await io.serve(handler, bindAddress, port);
    _boundAddress = bindAddress;
    debugPrint('LLM Router Server running on port ${_server!.port}');
  }

  InternetAddress? _boundAddress;

  /// Address the server is bound to. Exposed for tests of the bind choice.
  @visibleForTesting
  InternetAddress? get boundAddressForTest => _boundAddress;

  /// Stop the server
  Future<void> stop() async {
    await _server?.close();
    _server = null;
  }

  /// Decides whether a request may reach a non-public endpoint.
  ///
  /// Pure function so the rule can be tested without opening a socket from
  /// another machine. Returns null when the request may proceed, or the
  /// HTTP status to answer with.
  ///
  /// Private paths also require a loopback [host] (unless [allowRemoteAccess]),
  /// a local-or-absent [origin], and `application/json` [contentType] on
  /// state-changing methods — defenses against DNS rebinding and CSRF (#805).
  @visibleForTesting
  static int? accessDecision({
    required String path,
    required bool fromLoopback,
    required String? authorizationHeader,
    required String? authSecret,
    String? host,
    String? origin,
    String? method,
    String? contentType,
    bool allowRemoteAccess = false,
  }) {
    if (_publicPaths.contains(path)) return null;

    if (!allowRemoteAccess && !_isAllowedLoopbackHost(host)) {
      return HttpStatus.forbidden;
    }

    if (!_isAllowedOrigin(origin)) {
      return HttpStatus.forbidden;
    }

    if (_isStateChangingMethod(method) && !_isJsonContentType(contentType)) {
      return HttpStatus.unsupportedMediaType;
    }

    if (authSecret == null) {
      // No secret: only callers on this machine may use private endpoints.
      return fromLoopback ? null : HttpStatus.forbidden;
    }

    if (authorizationHeader == null || authorizationHeader.isEmpty) {
      return HttpStatus.forbidden;
    }
    if (authorizationHeader != 'Bearer $authSecret') {
      return HttpStatus.unauthorized;
    }
    return null;
  }

  /// Hostnames the embedded router accepts when bound to loopback only.
  static const _loopbackHostNames = {
    'localhost',
    '127.0.0.1',
    '::1',
    '[::1]',
  };

  static bool _isAllowedLoopbackHost(String? hostHeader) {
    if (hostHeader == null || hostHeader.isEmpty) return false;
    final host = _hostWithoutPort(hostHeader);
    return _loopbackHostNames.contains(host.toLowerCase());
  }

  static String _hostWithoutPort(String hostHeader) {
    final value = hostHeader.trim();
    if (value.startsWith('[')) {
      final end = value.indexOf(']');
      if (end != -1) return value.substring(0, end + 1);
      return value;
    }
    final colon = value.lastIndexOf(':');
    if (colon == -1) return value;
    // Raw IPv6 has more than one colon; leave it intact.
    if (value.indexOf(':') != colon) return value;
    return value.substring(0, colon);
  }

  /// Browsers send Origin on cross-site requests. Absent Origin (native
  /// clients, curl) is allowed; a present Origin must target loopback.
  static bool _isAllowedOrigin(String? origin) {
    if (origin == null || origin.isEmpty) return true;
    final uri = Uri.tryParse(origin);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return false;
    if (uri.scheme != 'http' && uri.scheme != 'https') return false;
    final host = uri.host.toLowerCase();
    return host == 'localhost' ||
        host == '127.0.0.1' ||
        host == '::1' ||
        host == '[::1]';
  }

  static bool _isStateChangingMethod(String? method) {
    if (method == null) return false;
    switch (method.toUpperCase()) {
      case 'POST':
      case 'PUT':
      case 'PATCH':
      case 'DELETE':
        return true;
      default:
        return false;
    }
  }

  static bool _isJsonContentType(String? contentType) {
    if (contentType == null || contentType.isEmpty) return false;
    final mediaType = contentType.split(';').first.trim().toLowerCase();
    return mediaType == 'application/json';
  }

  static bool _isLoopbackRequest(Request request) {
    final info = request.context['shelf.io.connection_info'];
    if (info is HttpConnectionInfo) {
      return info.remoteAddress.isLoopback;
    }
    // Unknown origin (e.g. in-memory handler): treat as remote.
    return false;
  }

  /// Auth middleware. Public paths always pass through. Private paths need
  /// the bearer token when [authSecret] is set, and a loopback caller when
  /// it is not. Also enforces Host / Origin / Content-Type on private paths.
  Middleware _authMiddleware() {
    return (Handler innerHandler) {
      return (Request request) {
        final authHeader = request.headers['authorization'];
        final decision = accessDecision(
          path: request.requestedUri.path,
          fromLoopback: _isLoopbackRequest(request),
          authorizationHeader: authHeader,
          authSecret: authSecret,
          host: request.headers['host'],
          origin: request.headers['origin'],
          method: request.method,
          contentType: request.headers['content-type'],
          allowRemoteAccess: allowRemoteAccess,
        );
        if (decision == null) return innerHandler(request);

        if (decision == HttpStatus.unauthorized) {
          return Response(
            HttpStatus.unauthorized,
            body: jsonEncode({'error': 'Invalid or missing token'}),
            headers: {
              'Content-Type': 'application/json',
              'WWW-Authenticate': 'Bearer realm="router"',
            },
          );
        }

        if (decision == HttpStatus.unsupportedMediaType) {
          return Response(
            HttpStatus.unsupportedMediaType,
            body: jsonEncode({
              'error': 'Content-Type must be application/json',
            }),
            headers: {'Content-Type': 'application/json'},
          );
        }

        final message = !_isAllowedLoopbackHost(request.headers['host']) &&
                !allowRemoteAccess
            ? 'Invalid Host header'
            : !_isAllowedOrigin(request.headers['origin'])
                ? 'Origin not allowed'
                : authSecret == null
                    ? 'This endpoint is only available on this computer'
                    : 'Missing Authorization header';
        return Response.forbidden(
          jsonEncode({'error': message}),
          headers: {'Content-Type': 'application/json'},
        );
      };
    };
  }

  Response _handleHub(Request request) {
    final routerPort = _server?.port ?? port;
    return Response.ok(
      jsonEncode(<String, Object>{
        'role': 'primary_hub',
        'product': Brand.current.productName,
        'routerPort': routerPort,
        // Co-resident Hermes only. Remote clients must use routerPort / chatBasePath.
        'hermesPort': AppConfig.defaultHermesPort,
        'clientsMustUseHub': true,
        'chatBasePath': '/',
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }

  /// Forward Hermes-native chat/session calls to the co-resident gateway.
  Future<Response> _proxyHermes(Request request) async {
    final upstream = Uri.parse(hermesBaseUrl);
    final target = Uri(
      scheme: upstream.scheme,
      host: upstream.host,
      port: upstream.hasPort ? upstream.port : null,
      path: request.requestedUri.path,
      query: request.requestedUri.hasQuery ? request.requestedUri.query : null,
    );

    final bodyBytes = await request.read().fold<List<int>>(
      <int>[],
      (List<int> acc, List<int> chunk) {
        acc.addAll(chunk);
        return acc;
      },
    );

    final headers = <String, String>{};
    request.headers.forEach((name, value) {
      final lower = name.toLowerCase();
      if (lower == 'host' || lower == 'content-length') return;
      headers[name] = value;
    });

    try {
      final streamed = http.StreamedRequest(request.method, target);
      streamed.headers.addAll(headers);
      if (bodyBytes.isNotEmpty) {
        streamed.contentLength = bodyBytes.length;
        streamed.sink.add(bodyBytes);
      }
      final upstreamResponse = await Future<http.StreamedResponse>(() async {
        // Close the sink only after send() has attached a listener; awaiting
        // close() first never completes because nothing reads the sink yet.
        final pending = streamed.send();
        await streamed.sink.close();
        return pending;
      }).timeout(
        const Duration(seconds: 120),
      );
      final responseBytes = await upstreamResponse.stream.toBytes();
      final responseHeaders = <String, String>{};
      upstreamResponse.headers.forEach((name, value) {
        final lower = name.toLowerCase();
        if (lower == 'transfer-encoding' || lower == 'content-encoding') {
          return;
        }
        responseHeaders[name] = value;
      });
      return Response(
        upstreamResponse.statusCode,
        body: responseBytes,
        headers: responseHeaders,
      );
    } catch (e) {
      debugPrint('[RouterServer] Hermes proxy failed for ${target.path}: $e');
      return Response(
        502,
        body: jsonEncode({'error': 'Hub could not reach local Hermes'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  Response _handleListModels(Request request) {
    // Only models whose provider is registered can be served. Listing the
    // rest would advertise models that fail on the first call.
    final models = ModelRegistry.models.values
        .where((m) => providers.containsKey(m.provider))
        .map((m) => {
              'id': m.id,
              'object': 'model',
              'created': 1677610602,
              'owned_by': m.provider,
            })
        .toList();

    return Response.ok(
      jsonEncode({'object': 'list', 'data': models}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  Future<Response> _handleChatCompletions(Request request) async {
    try {
      final body = await request.readAsString();
      final completionRequest = CompletionRequest.fromJson(jsonDecode(body));

      final requestedModel = completionRequest.model;

      // 1. Get best available model
      final actualModel =
          await rateLimitManager.getAvailableModel(requestedModel);
      final config = ModelRegistry.get(actualModel);
      final provider = providers[config.provider];

      if (provider == null) {
        // The caller asked for a model this router cannot serve: a client
        // error in the OpenAI error shape, not a server failure.
        return Response.notFound(
          jsonEncode({
            'error': {
              'message': 'The model `$actualModel` is not available: '
                  'its provider is not configured on this router.',
              'type': 'invalid_request_error',
              'param': 'model',
              'code': 'model_not_found',
            },
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      if (CloudOutboundPolicy.isCloudLlmProvider(config.provider)) {
        final allowed =
            cloudLlmAllowed == null ? false : await cloudLlmAllowed!();
        if (!allowed) {
          return Response.forbidden(
            jsonEncode({
              'error': {
                'message':
                    'Cloud LLM providers are off by default. Enable them in '
                        'Settings before sending prompts to '
                        '${config.provider}.',
                'type': 'permission_error',
                'param': 'model',
                'code': 'cloud_llm_consent_required',
              },
            }),
            headers: {'Content-Type': 'application/json'},
          );
        }
      }

      // 2. Start request tracking
      await rateLimitManager.startRequest(actualModel);

      // 3. Prepare response headers
      final headers = {
        'Content-Type': 'application/json',
        'X-Actual-Model': actualModel,
        if (actualModel != requestedModel) 'X-Switched-Reason': 'rate-limit',
      };

      // 4. Dispatch to provider
      if (completionRequest.stream) {
        // ignore: unawaited_return_in_try_block — returns Future<Response>, caught by catch
        return _handleStreaming(
            provider, completionRequest, actualModel, headers);
      } else {
        // ignore: unawaited_return_in_try_block — returns Future<Response>, caught by catch
        return _handleNonStreaming(
            provider, completionRequest, actualModel, headers);
      }
    } catch (e) {
      return _safeErrorResponse(e, statusCode: HttpStatus.badRequest);
    }
  }

  Future<Response> _handleStreaming(
    LlmProvider provider,
    CompletionRequest request,
    String modelId,
    Map<String, String> headers,
  ) async {
    final stream =
        provider.streamCompletion(request).map((event) => event.toSse());

    // Increment usage and decrement on close
    return Response.ok(
      stream,
      headers: {
        ...headers,
        'Content-Type': 'text/event-stream',
        'Cache-Control': 'no-cache',
        'Connection': 'keep-alive',
      },
      context: {
        'onClose': () => rateLimitManager.endRequest(modelId),
      },
    );
  }

  Future<Response> _handleNonStreaming(
    LlmProvider provider,
    CompletionRequest request,
    String modelId,
    Map<String, String> headers,
  ) async {
    try {
      final response = await provider.complete(request);
      return Response.ok(
        jsonEncode(response.toJson()),
        headers: headers,
      );
    } finally {
      await rateLimitManager.endRequest(modelId);
    }
  }

  Future<Response> _handleAudioSpeech(Request request) async {
    final service = ttsService;
    if (service == null) {
      return Response.notFound('TTS service not available');
    }

    final speechAllowed = microsoftSpeechAllowed == null
        ? false
        : await microsoftSpeechAllowed!();
    if (!speechAllowed) {
      return Response.forbidden(
        jsonEncode({
          'error': {
            'message':
                'Microsoft online speech is off by default. Enable it in '
                    'Settings before sending spoken text to the cloud.',
            'type': 'permission_error',
            'code': 'microsoft_speech_consent_required',
          },
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }

    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final speechRequest = CloudTtsRequest.fromJson(data);
      final result = await service.synthesize(speechRequest);
      final file = File(result.path);

      return Response.ok(
        file.openRead(),
        headers: {
          'Content-Type': result.contentType,
          'Content-Length': (await file.length()).toString(),
          'X-Pistisai-TTS': 'edge-tts',
        },
      );
    } on FormatException catch (e) {
      return _safeErrorResponse(
        e,
        statusCode: HttpStatus.badRequest,
        asJson: true,
      );
    } catch (e) {
      return _safeErrorResponse(
        e,
        statusCode: HttpStatus.internalServerError,
        asJson: true,
      );
    }
  }

  Response _handleListVoices(Request request) {
    return Response.ok(
      jsonEncode({
        'object': 'list',
        'data': [
          {
            'id': 'en-US-GuyNeural',
            'object': 'voice',
            'owned_by': 'pistisai',
          },
          {
            'id': 'en-US-AriaNeural',
            'object': 'voice',
            'owned_by': 'pistisai',
          },
          {
            'id': 'en-US-JennyNeural',
            'object': 'voice',
            'owned_by': 'pistisai',
          },
        ],
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }

  /// GET /avatar/state - Returns the current avatar personality state
  Future<Response> _handleGetAvatarState(Request request) async {
    if (personalityEngine == null) {
      return Response.notFound('Personality engine not available');
    }

    try {
      final profile = await personalityEngine!.getPersonality();
      return Response.ok(
        jsonEncode({
          'agent_name': profile.agentName,
          'traits': profile.traits.toMap(),
          'evolution_stage': profile.evolutionStage,
          'conversation_count': profile.conversationCount,
          'depth_score': profile.depthScore,
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return _safeErrorResponse(e, statusCode: HttpStatus.internalServerError);
    }
  }

  /// POST /avatar/traits - Updates avatar personality traits
  Future<Response> _handleUpdateTraits(Request request) async {
    if (personalityEngine == null) {
      return Response.notFound('Personality engine not available');
    }

    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      if (!data.containsKey('traits')) {
        return Response.badRequest(body: 'Missing "traits" field');
      }

      final traitsData = data['traits'] as Map<String, dynamic>;
      final traits = PersonalityTraits.fromMap(
        traitsData.map((k, v) => MapEntry(k, (v as num).toDouble())),
      );

      await personalityEngine!.updatePersonality(traits);

      return Response.ok(
        jsonEncode({'status': 'success', 'traits': traits.toMap()}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return _safeErrorResponse(e, statusCode: HttpStatus.badRequest);
    }
  }

  /// POST /avatar/evolution/request - Requests an avatar evolution
  Future<Response> _handleEvolutionRequest(Request request) async {
    if (personalityEngine == null) {
      return Response.notFound('Personality engine not available');
    }

    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      if (!data.containsKey('stage')) {
        return Response.badRequest(body: 'Missing "stage" field');
      }

      final requestedStage = data['stage'] as String;
      final reason = data['reason'] as String? ?? 'User request';

      final decision = await personalityEngine!.validateEvolutionRequest(
        requestedStage,
        reason,
      );

      final statusCode =
          decision.approved ? HttpStatus.ok : HttpStatus.badRequest;

      return Response(
        statusCode,
        body: jsonEncode({
          'approved': decision.approved,
          if (decision.newStage != null) 'new_stage': decision.newStage,
          if (decision.reason != null) 'reason': decision.reason,
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return _safeErrorResponse(e, statusCode: HttpStatus.badRequest);
    }
  }

  // ==========================================================================
  // CONSCIENCE SYSTEM API HANDLERS (Phase 1 - Storage Layer)
  // ==========================================================================

  /// POST /api/conscience/thoughts - Write a thought
  Future<Response> _handleWriteThought(Request request) async {
    if (conscienceStorage == null) {
      return Response.notFound('Conscience storage not available');
    }

    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      if (!data.containsKey('agent') ||
          !data.containsKey('thought_type') ||
          !data.containsKey('content')) {
        return Response.badRequest(
            body: 'Missing required fields: agent, thought_type, content');
      }

      final thought = await conscienceStorage!.writeThought(
        agent: data['agent'] as String,
        thoughtType: data['thought_type'] as String,
        content: data['content'] as String,
        channel: data['channel'] as String? ?? 'general',
        metadata: data['metadata'] as Map<String, dynamic>? ?? {},
      );

      return Response.ok(
        jsonEncode({'status': 'success', 'thought': thought}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return _safeErrorResponse(e, statusCode: HttpStatus.internalServerError);
    }
  }

  /// GET /api/conscience/thoughts - Read thoughts
  Future<Response> _handleGetThoughts(Request request) async {
    if (conscienceStorage == null) {
      return Response.notFound('Conscience storage not available');
    }

    try {
      final agent = request.url.queryParameters['agent'];
      final channel = request.url.queryParameters['channel'];
      final thoughtType = request.url.queryParameters['thought_type'];
      final limit =
          int.tryParse(request.url.queryParameters['limit'] ?? '50') ?? 50;

      final thoughts = await conscienceStorage!.getThoughts(
        agent: agent,
        channel: channel,
        thoughtType: thoughtType,
        limit: limit,
      );

      return Response.ok(
        jsonEncode({'thoughts': thoughts}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return _safeErrorResponse(e, statusCode: HttpStatus.internalServerError);
    }
  }

  /// POST /api/conscience/decisions - Submit a decision for review
  Future<Response> _handleWriteDecision(Request request) async {
    if (conscienceStorage == null) {
      return Response.notFound('Conscience storage not available');
    }

    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      if (!data.containsKey('action') || !data.containsKey('risk_level')) {
        return Response.badRequest(
            body: 'Missing required fields: action, risk_level');
      }

      final reviewer = data['reviewer'];
      final verdict = data['verdict'];
      if ((reviewer != null && reviewer is! String) ||
          (verdict != null && verdict is! String)) {
        return Response.badRequest(body: 'reviewer and verdict must be text');
      }

      // writeDecision refuses the user's reserved reviewer name and unknown
      // verdicts; only in-process code records the user's own decisions.
      final decision = await conscienceStorage!.writeDecision(
        action: data['action'] as String,
        riskLevel: data['risk_level'] as String,
        verdict: verdict as String?,
        reviewer: reviewer as String?,
        reasoning: data['reasoning'] as String?,
      );

      return Response.ok(
        jsonEncode({'status': 'success', 'decision': decision}),
        headers: {'Content-Type': 'application/json'},
      );
    } on ConscienceIntegrityException catch (e) {
      return _integrityRefusal(e);
    } catch (e) {
      return _safeErrorResponse(e, statusCode: HttpStatus.internalServerError);
    }
  }

  /// GET /api/conscience/decisions - Get decisions
  Future<Response> _handleGetDecisions(Request request) async {
    if (conscienceStorage == null) {
      return Response.notFound('Conscience storage not available');
    }

    try {
      final status = request.url.queryParameters['status'];
      final riskLevel = request.url.queryParameters['risk_level'];
      final limit =
          int.tryParse(request.url.queryParameters['limit'] ?? '50') ?? 50;

      final decisions = await conscienceStorage!.getDecisions(
        status: status,
        riskLevel: riskLevel,
        limit: limit,
      );

      return Response.ok(
        jsonEncode({'decisions': decisions}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return _safeErrorResponse(e, statusCode: HttpStatus.internalServerError);
    }
  }

  /// PUT /api/conscience/decisions/verdict - Submit a verdict
  Future<Response> _handleSubmitVerdict(Request request) async {
    if (conscienceStorage == null) {
      return Response.notFound('Conscience storage not available');
    }

    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      if (!data.containsKey('decision_id') ||
          !data.containsKey('verdict') ||
          !data.containsKey('reviewer') ||
          !data.containsKey('reasoning')) {
        return Response.badRequest(
            body: 'Missing required fields: '
                'decision_id, verdict, reviewer, reasoning');
      }

      // submitDecisionVerdict refuses unknown verdicts, the user's reserved
      // reviewer name, and any decision that is final or was made by the user.
      final decision = await conscienceStorage!.submitDecisionVerdict(
        decisionId: data['decision_id'] as String,
        verdict: data['verdict'] as String,
        reviewer: data['reviewer'] as String,
        reasoning: data['reasoning'] as String,
      );

      return Response.ok(
        jsonEncode({'status': 'success', 'decision': decision}),
        headers: {'Content-Type': 'application/json'},
      );
    } on ConscienceIntegrityException catch (e) {
      return _integrityRefusal(e);
    } catch (e) {
      return _safeErrorResponse(e, statusCode: HttpStatus.internalServerError);
    }
  }

  static Response _integrityRefusal(ConscienceIntegrityException e) {
    final status = e.violation == ConscienceIntegrityViolation.invalidVerdict
        ? HttpStatus.badRequest
        : HttpStatus.forbidden;
    return Response(
      status,
      body: jsonEncode({
        'error': {
          'code': 'conscience_${e.violation.name}',
          'message': e.message
        }
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }
}
