import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Where the AI assistant sends its requests: any **OpenAI-compatible**
/// chat-completions endpoint. In practice that means a local model server —
/// Ollama / LM Studio / llama.cpp on the user's PC (or even on the phone via
/// Termux) — but a cloud provider works too if the user pastes a key.
/// Stored in SharedPreferences; nothing is bundled with the app.
class LlmSettings {
  LlmSettings._();

  static const _kBaseUrl = 'llm_base_url';
  static const _kModel = 'llm_model';
  static const _kApiKey = 'llm_api_key';

  static SharedPreferences? _prefs;

  /// Caches the SharedPreferences instance. Call once during startup.
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static String get baseUrl => _prefs?.getString(_kBaseUrl)?.trim() ?? '';
  static set baseUrl(String v) => _prefs?.setString(_kBaseUrl, v.trim());

  static String get model => _prefs?.getString(_kModel)?.trim() ?? '';
  static set model(String v) => _prefs?.setString(_kModel, v.trim());

  static String get apiKey => _prefs?.getString(_kApiKey)?.trim() ?? '';
  static set apiKey(String v) => _prefs?.setString(_kApiKey, v.trim());

  static bool get configured => baseUrl.isNotEmpty && model.isNotEmpty;

  /// Server root with scheme and no trailing slash or /v1 suffix.
  /// Accepts "192.168.1.201:11434", "http://host:11434", or ".../v1".
  static String serverRoot() {
    var base = baseUrl;
    if (!base.startsWith('http://') && !base.startsWith('https://')) {
      base = 'http://$base';
    }
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    if (base.endsWith('/v1')) base = base.substring(0, base.length - 3);
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    return base;
  }

  /// Normalized ".../v1/chat/completions" endpoint derived from [baseUrl].
  static Uri chatEndpoint() => Uri.parse('${serverRoot()}/v1/chat/completions');
}

class ChatMessage {
  const ChatMessage(this.role, this.content);

  final String role; // system | user | assistant
  final String content;

  Map<String, String> toJson() => {'role': role, 'content': content};
}

/// Error with a message fit for direct display in the chat.
class LlmException implements Exception {
  const LlmException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Minimal streaming client for OpenAI-compatible /chat/completions.
class LlmClient {
  LlmClient._();

  /// Streams assistant tokens for [messages]. Emits content deltas as they
  /// arrive; throws [LlmException] with a displayable message on failure.
  static Stream<String> chatStream(List<ChatMessage> messages) async* {
    if (!LlmSettings.configured) {
      throw const LlmException('AI endpoint not configured.');
    }
    final request = http.Request('POST', LlmSettings.chatEndpoint())
      ..headers['Content-Type'] = 'application/json'
      ..body = jsonEncode({
        'model': LlmSettings.model,
        'messages': [for (final m in messages) m.toJson()],
        'stream': true,
      });
    if (LlmSettings.apiKey.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer ${LlmSettings.apiKey}';
    }

    final client = http.Client();
    try {
      late final http.StreamedResponse response;
      try {
        response =
            await client.send(request).timeout(const Duration(seconds: 30));
      } catch (_) {
        throw LlmException(
            'Could not reach ${LlmSettings.baseUrl}. Is the model server '
            'running and on the same network?');
      }
      if (response.statusCode != 200) {
        final body = await response.stream.bytesToString();
        throw LlmException(_errorFrom(response.statusCode, body));
      }

      // OpenAI-style SSE: lines of "data: {json}", ending with "data: [DONE]".
      final lines = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());
      await for (final line in lines) {
        final l = line.trim();
        if (!l.startsWith('data:')) continue;
        final payload = l.substring(5).trim();
        if (payload == '[DONE]') return;
        try {
          final json = jsonDecode(payload) as Map<String, dynamic>;
          final delta = ((json['choices'] as List?)?.firstOrNull
              as Map<String, dynamic>?)?['delta'] as Map<String, dynamic>?;
          final content = delta?['content'];
          if (content is String && content.isNotEmpty) yield content;
        } catch (_) {
          // Skip malformed keep-alive/comment lines.
        }
      }
    } finally {
      client.close();
    }
  }

  static String _errorFrom(int status, String body) {
    String? detail;
    try {
      final json = jsonDecode(body);
      detail = ((json as Map<String, dynamic>)['error']
          as Map<String, dynamic>?)?['message'] as String?;
    } catch (_) {}
    if (status == 404 && (detail?.contains('model') ?? false)) {
      return 'Model "${LlmSettings.model}" not found on the server — '
          'download it via the Models sheet (⬇ in the assistant).';
    }
    return detail ?? 'The model server returned HTTP $status.';
  }
}

/// One model installed on the Ollama server.
class OllamaModel {
  const OllamaModel({required this.name, required this.sizeBytes});

  final String name;
  final int sizeBytes;

  String get sizeLabel =>
      '${(sizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}

/// Progress of an in-flight model download.
class OllamaPullProgress {
  const OllamaPullProgress(this.status, this.completed, this.total);

  final String status;
  final int completed;
  final int total;

  /// 0..1 when the layer size is known, else null (indeterminate).
  double? get fraction =>
      total > 0 ? (completed / total).clamp(0.0, 1.0) : null;
}

/// Ollama-specific admin endpoints (list/pull models). These are NOT part of
/// the OpenAI-compatible surface — [listModels] returning null means the
/// configured server isn't Ollama and the in-app model manager hides itself.
class OllamaAdmin {
  OllamaAdmin._();

  /// Models installed on the server, or null when unreachable / not Ollama.
  static Future<List<OllamaModel>?> listModels() async {
    try {
      final res = await http
          .get(Uri.parse('${LlmSettings.serverRoot()}/api/tags'))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final models = json['models'];
      if (models is! List) return null;
      return [
        for (final m in models)
          if (m is Map<String, dynamic> && m['name'] is String)
            OllamaModel(
              name: m['name'] as String,
              sizeBytes: (m['size'] as num?)?.toInt() ?? 0,
            ),
      ]..sort((a, b) => a.name.compareTo(b.name));
    } catch (_) {
      return null;
    }
  }

  /// Downloads [model] onto the server, streaming progress (NDJSON lines).
  static Stream<OllamaPullProgress> pull(String model) async* {
    final request =
        http.Request('POST', Uri.parse('${LlmSettings.serverRoot()}/api/pull'))
          ..headers['Content-Type'] = 'application/json'
          ..body = jsonEncode({'model': model});
    final client = http.Client();
    try {
      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        final body = await response.stream.bytesToString();
        throw LlmException(_pullError(body, model));
      }
      final lines = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());
      await for (final line in lines) {
        if (line.trim().isEmpty) continue;
        try {
          final json = jsonDecode(line) as Map<String, dynamic>;
          final error = json['error'];
          if (error is String) throw LlmException(error);
          yield OllamaPullProgress(
            (json['status'] as String?) ?? '…',
            (json['completed'] as num?)?.toInt() ?? 0,
            (json['total'] as num?)?.toInt() ?? 0,
          );
        } on LlmException {
          rethrow;
        } catch (_) {
          // Skip malformed lines.
        }
      }
    } on LlmException {
      rethrow;
    } catch (_) {
      throw const LlmException(
          'Download failed — could not reach the model server.');
    } finally {
      client.close();
    }
  }

  static String _pullError(String body, String model) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final e = json['error'];
      if (e is String) {
        return e.contains('file does not exist') || e.contains('not found')
            ? 'Model "$model" not found in the Ollama library — check the '
                'spelling on ollama.com/library.'
            : e;
      }
    } catch (_) {}
    return 'Download failed for "$model".';
  }
}
