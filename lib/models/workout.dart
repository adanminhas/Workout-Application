import 'exercise.dart';
import 'tracking_type.dart';

/// One exercise placed inside a workout, with workout-specific targets that
/// override the exercise's defaults (sets, reps/seconds range, rest).
class WorkoutItem {
  const WorkoutItem({
    this.id,
    required this.exercise,
    required this.sets,
    this.minReps,
    this.maxReps,
    this.minSeconds,
    this.maxSeconds,
    this.restSeconds = 60,
    this.isFinisher = false,
    this.notes,
  });

  /// Row id when this item is persisted (null for seed/in-memory templates).
  /// Lets the workout builder address a specific item to edit/remove/reorder.
  final int? id;

  final Exercise exercise;
  final int sets;

  // Rep targets (used for rep-based tracking types).
  final int? minReps;
  final int? maxReps;

  // Time targets in seconds (used for timed tracking types).
  final int? minSeconds;
  final int? maxSeconds;

  /// Rest after completing a full set of this item.
  final int restSeconds;

  /// Burnout / "max reps" style item shown with a Finisher badge.
  final bool isFinisher;

  final String? notes;

  TrackingType get trackingType => exercise.trackingType;

  /// Human-readable target, e.g. "15–20 reps", "30–45 sec", "3×20".
  String get targetLabel {
    if (trackingType.isTimed) {
      return _rangeLabel(minSeconds, maxSeconds, 'sec');
    }
    if (trackingType == TrackingType.maxReps) {
      return 'Max reps';
    }
    return _rangeLabel(minReps, maxReps, 'reps');
  }

  /// Compact "sets×target" summary used in workout/exercise lists.
  String get summary {
    if (trackingType == TrackingType.maxReps) {
      return '$sets × max reps';
    }
    if (trackingType.isTimed) {
      return '$sets × ${_rangeLabel(minSeconds, maxSeconds, 'sec')}';
    }
    return '$sets × ${_rangeLabel(minReps, maxReps, 'reps')}';
  }

  static String _rangeLabel(int? min, int? max, String unit) {
    if (min == null && max == null) return unit;
    if (max == null || min == max) return '$min $unit';
    if (min == null) return '$max $unit';
    return '$min–$max $unit';
  }
}

/// An ordered collection of workout items (a "day").
class Workout {
  const Workout({
    required this.id,
    required this.name,
    required this.items,
    this.focus,
  });

  final String id;
  final String name;
  final String? focus;
  final List<WorkoutItem> items;

  int get exerciseCount => items.length;

  int get totalSets => items.fold(0, (sum, item) => sum + item.sets);

  /// Rough estimate: work + rest across all sets, in whole minutes.
  int get estimatedMinutes {
    var seconds = 0;
    for (final item in items) {
      final perSetWork = item.trackingType.isTimed
          ? (item.maxSeconds ?? item.minSeconds ?? 30)
          : 40; // assume ~40s to perform a rep-based set
      final sideMultiplier = item.trackingType.isEachSide ? 2 : 1;
      seconds += item.sets * (perSetWork * sideMultiplier + item.restSeconds);
    }
    return (seconds / 60).round();
  }
}
