import 'dart:convert';

import 'package:http/http.dart' as http;

import 'media_store.dart';

/// One searchable catalog entry: a wger exercise that has a demo image.
class WgerResult {
  const WgerResult({
    required this.exerciseId,
    required this.name,
    required this.imageUrl,
    this.thumbUrl,
    this.description = '',
  });

  final int exerciseId;
  final String name;

  /// Full-size image URL (what gets downloaded on pick).
  final String imageUrl;

  /// Small thumbnail for result tiles, when wger provides one.
  final String? thumbUrl;

  /// Plain-text exercise description (HTML already stripped); may be empty.
  final String description;
}

/// Error with a message fit for direct display in the UI.
class WgerException implements Exception {
  const WgerException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Client for the wger exercise database (wger.de) — open source, Creative
/// Commons media, **no API key or account**. This backs the opt-in
/// "Find online" flow; everything else in the app stays offline.
///
/// wger ≥ 2.7 has no server-side name search, so on first use per session we
/// load a catalog (one image-index request + a few translation pages, a few
/// MB total), keep only exercises that actually have an image (~260), and
/// search that in memory — instant search-as-you-type afterwards.
class WgerApi {
  WgerApi._();

  static const _host = 'wger.de';
  static const _englishLanguageId = 2;
  static const _timeout = Duration(seconds: 25);
  static const _headers = {
    // wger asks API clients to identify themselves.
    'User-Agent': 'SetFlow/1.0 (local-first workout app)',
  };

  /// Session cache of the searchable catalog.
  static List<WgerResult>? _catalog;

  static Future<dynamic> _getJson(Uri uri) async {
    late final http.Response res;
    try {
      res = await http.get(uri, headers: _headers).timeout(_timeout);
    } catch (_) {
      throw const WgerException(
          'Could not reach wger.de. Check your internet connection.');
    }
    if (res.statusCode != 200) {
      throw WgerException('wger.de returned an error (HTTP ${res.statusCode}).');
    }
    return jsonDecode(res.body);
  }

  /// Loads (once per session) the catalog of imaged exercises with their
  /// English names + descriptions.
  static Future<List<WgerResult>> catalog() async {
    final cached = _catalog;
    if (cached != null) return cached;

    // 1) Image index — a single page covers the whole set.
    final imagesJson = await _getJson(Uri.https(
        _host, '/api/v2/exerciseimage/', {'format': 'json', 'limit': '500'}));

    // 2) English translations (names + descriptions), paged.
    final translations = <dynamic>[];
    Uri? next = Uri.https(_host, '/api/v2/exercise-translation/', {
      'language': '$_englishLanguageId',
      'format': 'json',
      'limit': '500',
    });
    while (next != null) {
      final page = await _getJson(next) as Map<String, dynamic>;
      translations.addAll(page['results'] as List? ?? const []);
      final n = page['next'] as String?;
      next = n == null ? null : Uri.parse(n);
    }

    return _catalog = buildCatalog(
      (imagesJson as Map<String, dynamic>)['results'] as List? ?? const [],
      translations,
    );
  }

  /// Pure assembly of the searchable catalog — kept separate for tests.
  /// [imagesJson]: exerciseimage rows; [translationsJson]: translation rows.
  static List<WgerResult> buildCatalog(
      List<dynamic> imagesJson, List<dynamic> translationsJson) {
    // Main image (or first seen) per exercise id, plus a small thumbnail.
    final imageByExercise = <int, (String, String?)>{};
    for (final row in imagesJson) {
      if (row is! Map<String, dynamic>) continue;
      final id = row['exercise'];
      final url = row['image'];
      if (id is! int || url is! String) continue;
      final thumb = (row['thumbnails'] is Map<String, dynamic>)
          ? (row['thumbnails'] as Map<String, dynamic>)['small'] as String?
          : null;
      final isMain = row['is_main'] == true;
      if (isMain || !imageByExercise.containsKey(id)) {
        imageByExercise[id] = (url, thumb);
      }
    }

    // First English translation per imaged exercise wins.
    final results = <int, WgerResult>{};
    for (final row in translationsJson) {
      if (row is! Map<String, dynamic>) continue;
      final id = row['exercise'];
      final name = row['name'];
      if (id is! int || name is! String || name.trim().isEmpty) continue;
      if (row['language'] != _englishLanguageId) continue;
      final image = imageByExercise[id];
      if (image == null || results.containsKey(id)) continue;
      results[id] = WgerResult(
        exerciseId: id,
        name: name.trim(),
        imageUrl: image.$1,
        thumbUrl: image.$2,
        description: plainDescription((row['description'] as String?) ?? ''),
      );
    }

    final list = results.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  /// Case-insensitive substring search over the session catalog.
  static Future<List<WgerResult>> search(String query) async {
    final all = await catalog();
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return [
      for (final r in all)
        if (r.name.toLowerCase().contains(q)) r,
    ];
  }

  /// Downloads a result's image into app storage and returns the local path.
  static Future<String> downloadImage(WgerResult result) async {
    late final http.Response res;
    try {
      res = await http
          .get(Uri.parse(result.imageUrl), headers: _headers)
          .timeout(_timeout);
    } catch (_) {
      throw const WgerException('Downloading the image failed.');
    }
    if (res.statusCode != 200 || res.bodyBytes.isEmpty) {
      throw WgerException(
          'Downloading the image failed (HTTP ${res.statusCode}).');
    }
    return MediaStore.saveBytes(res.bodyBytes,
        extension: _extensionOf(result.imageUrl));
  }

  static String _extensionOf(String url) {
    final path = Uri.tryParse(url)?.path ?? url;
    final dot = path.lastIndexOf('.');
    if (dot == -1 || dot < path.lastIndexOf('/')) return '.png';
    final ext = path.substring(dot).toLowerCase();
    return const {'.png', '.jpg', '.jpeg', '.gif', '.webp'}.contains(ext)
        ? ext
        : '.png';
  }

  /// Strips HTML tags/entities from a wger description for the Instructions
  /// field. Good enough for wger's simple markup (<p>, <li>, <strong>…).
  static String plainDescription(String html) {
    var text = html
        .replaceAll(RegExp(r'</(p|li|ul|ol|div|br)>', caseSensitive: false),
            '\n')
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '');
    const entities = {
      '&nbsp;': ' ',
      '&amp;': '&',
      '&lt;': '<',
      '&gt;': '>',
      '&quot;': '"',
      '&#39;': "'",
    };
    entities.forEach((k, v) => text = text.replaceAll(k, v));
    // Single line breaks read best in the Instructions field.
    return text
        .replaceAll(RegExp(r'[ \t]*\n[ \t]*'), '\n')
        .replaceAll(RegExp(r'\n{2,}'), '\n')
        .trim();
  }
}
