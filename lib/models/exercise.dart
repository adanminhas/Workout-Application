import 'tracking_type.dart';

/// Kind of demo media attached to an exercise (Phase 5).
enum MediaType { image, video }

/// A movement in the library (an exercise or a stretch).
///
/// Persisted to on-device SQLite; the user can create/edit their own and attach
/// a demo image or video (stored as a file path, never a blob).
class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.trackingType,
    this.isStretch = false,
    this.instructions,
    this.formCues,
    this.muscleGroup,
    this.mediaPath,
    this.mediaType,
  });

  final String id;
  final String name;
  final TrackingType trackingType;

  /// Stretches are just exercises with a stretch category, kept simple.
  final bool isStretch;

  final String? instructions;
  final String? formCues;
  final String? muscleGroup;

  /// Absolute path to a demo image/video in app storage, or null.
  final String? mediaPath;
  final MediaType? mediaType;

  bool get hasMedia => mediaPath != null && mediaType != null;
}
