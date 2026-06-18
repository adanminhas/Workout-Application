import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/exercise.dart';

/// Copies picked demo media into the app's private documents directory so the
/// stored path stays valid (image_picker hands back temporary/cache paths that
/// the OS may clear). We store FILE PATHS in the DB, never blobs.
class MediaStore {
  MediaStore._();

  static const _subdir = 'exercise_media';

  /// Copies [sourcePath] into app storage and returns the new absolute path.
  /// The filename is unique so replacing media never collides.
  static Future<String> save(
    String sourcePath, {
    required MediaType type,
  }) async {
    final dir = Directory('${(await getApplicationDocumentsDirectory()).path}'
        '/$_subdir');
    if (!await dir.exists()) await dir.create(recursive: true);

    final ext = _extension(sourcePath, type);
    final dest = '${dir.path}/${DateTime.now().millisecondsSinceEpoch}$ext';
    await File(sourcePath).copy(dest);
    return dest;
  }

  /// Best-effort delete of a file we previously [save]d. Safe to call with null
  /// or a path that no longer exists.
  static Future<void> delete(String? path) async {
    if (path == null) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Orphaned media is harmless; never let cleanup crash a save/delete.
    }
  }

  static String _extension(String source, MediaType type) {
    final dot = source.lastIndexOf('.');
    if (dot != -1 && dot > source.lastIndexOf('/')) {
      return source.substring(dot).toLowerCase();
    }
    return type == MediaType.video ? '.mp4' : '.jpg';
  }
}
