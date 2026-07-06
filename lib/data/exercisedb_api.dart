import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'media_store.dart';

/// One search hit from ExerciseDB.
class ExerciseDbResult {
  const ExerciseDbResult({
    required this.name,
    required this.bodyPart,
    required this.target,
    required this.equipment,
    required this.gifUrl,
    this.instructions = const [],
  });

  final String name;
  final String bodyPart;
  final String target;
  final String equipment;
  final String gifUrl;
  final List<String> instructions;
}

/// Error with a message fit for direct display in the UI.
class ExerciseDbException implements Exception {
  const ExerciseDbException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Thin client for the ExerciseDB catalog on RapidAPI (~1,300 exercises, each
/// with an animated demo GIF). Requires a personal RapidAPI key, which the
/// user pastes once and we keep in SharedPreferences — a key is never bundled
/// with the app. This backs the opt-in "Find online" flow; everything else in
/// the app stays offline.
class ExerciseDbApi {
  ExerciseDbApi._();

  static const _host = 'exercisedb.p.rapidapi.com';
  static const _kApiKey = 'exercisedb_api_key';
  static const _timeout = Duration(seconds: 20);

  static SharedPreferences? _prefs;

  /// Caches the SharedPreferences instance. Call once during startup.
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static String? get apiKey {
    final k = _prefs?.getString(_kApiKey)?.trim();
    return (k == null || k.isEmpty) ? null : k;
  }

  static set apiKey(String? value) {
    final v = value?.trim();
    if (v == null || v.isEmpty) {
      _prefs?.remove(_kApiKey);
    } else {
      _prefs?.setString(_kApiKey, v);
    }
  }

  static bool get hasKey => apiKey != null;

  static Map<String, String> get _headers => {
        'X-RapidAPI-Key': apiKey ?? '',
        'X-RapidAPI-Host': _host,
      };

  /// Headers for fetching [url] — the RapidAPI key is only ever sent to the
  /// RapidAPI host, not to the CDN that serves the GIFs.
  static Map<String, String>? headersFor(String url) =>
      Uri.tryParse(url)?.host == _host ? _headers : null;

  /// Searches the catalog by (partial) exercise name.
  static Future<List<ExerciseDbResult>> search(String query,
      {int limit = 20}) async {
    if (!hasKey) {
      throw const ExerciseDbException('No API key set.');
    }
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];

    final uri = Uri.https(
        _host, '/exercises/name/${Uri.encodeComponent(q)}', {'limit': '$limit'});
    late final http.Response res;
    try {
      res = await http.get(uri, headers: _headers).timeout(_timeout);
    } catch (_) {
      throw const ExerciseDbException(
          'Could not reach ExerciseDB. Check your internet connection.');
    }

    switch (res.statusCode) {
      case 200:
        break;
      case 401 || 403:
        throw const ExerciseDbException(
            'API key rejected. Check the key in Settings.');
      case 429:
        throw const ExerciseDbException(
            'Rate limit reached. Try again in a little while.');
      default:
        throw ExerciseDbException(
            'ExerciseDB returned an error (HTTP ${res.statusCode}).');
    }

    final decoded = jsonDecode(res.body);
    if (decoded is! List) return const [];
    return [
      for (final e in decoded)
        if (e is Map<String, dynamic> && e['gifUrl'] is String)
          ExerciseDbResult(
            name: (e['name'] as String?) ?? 'Unknown',
            bodyPart: (e['bodyPart'] as String?) ?? '',
            target: (e['target'] as String?) ?? '',
            equipment: (e['equipment'] as String?) ?? '',
            gifUrl: e['gifUrl'] as String,
            instructions: [
              if (e['instructions'] is List)
                for (final s in e['instructions'] as List)
                  if (s is String) s,
            ],
          ),
    ];
  }

  /// Downloads a result's GIF into app storage and returns the local path.
  static Future<String> downloadGif(ExerciseDbResult result) async {
    late final http.Response res;
    try {
      res = await http
          .get(Uri.parse(result.gifUrl), headers: headersFor(result.gifUrl))
          .timeout(_timeout);
    } catch (_) {
      throw const ExerciseDbException('Downloading the GIF failed.');
    }
    if (res.statusCode != 200 || res.bodyBytes.isEmpty) {
      throw ExerciseDbException(
          'Downloading the GIF failed (HTTP ${res.statusCode}).');
    }
    return MediaStore.saveBytes(res.bodyBytes);
  }
}
