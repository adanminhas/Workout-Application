import 'tracking_type.dart';

/// A movement in the library (an exercise or a stretch).
///
/// Phase 1 keeps this in memory and hardcoded. Later phases will persist this
/// to SQLite and let the user create/edit their own.
class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.trackingType,
    this.isStretch = false,
    this.instructions,
    this.formCues,
    this.muscleGroup,
  });

  final String id;
  final String name;
  final TrackingType trackingType;

  /// Stretches are just exercises with a stretch category, kept simple.
  final bool isStretch;

  final String? instructions;
  final String? formCues;
  final String? muscleGroup;
}
