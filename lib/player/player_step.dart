import '../models/tracking_type.dart';
import '../models/workout.dart';

/// Which side a step targets (for each-side exercises).
enum StepSide { none, left, right }

/// A single thing the user does in the player: one set (or one side of one
/// set) of one exercise, plus the rest that follows it.
class PlayerStep {
  const PlayerStep({
    required this.exerciseName,
    required this.trackingType,
    required this.setNumber,
    required this.totalSets,
    required this.side,
    required this.isFinisher,
    required this.restAfterSeconds,
    required this.isSetEnd,
    this.targetMinReps,
    this.targetMaxReps,
    this.targetMinSeconds,
    this.targetMaxSeconds,
    this.formCues,
  });

  final String exerciseName;
  final TrackingType trackingType;
  final int setNumber;
  final int totalSets;
  final StepSide side;
  final bool isFinisher;

  /// Rest shown after this step. 0 means advance immediately.
  final int restAfterSeconds;

  /// True when this step completes a full set (used to count completed sets).
  final bool isSetEnd;

  final int? targetMinReps;
  final int? targetMaxReps;
  final int? targetMinSeconds;
  final int? targetMaxSeconds;
  final String? formCues;

  bool get isTimed => trackingType.isTimed;

  /// Seconds the countdown should run for a timed step (upper bound of range).
  int get timerSeconds => targetMaxSeconds ?? targetMinSeconds ?? 30;

  /// "Set 2 of 3" line.
  String get setLabel => 'Set $setNumber of $totalSets';

  String? get sideLabel => switch (side) {
        StepSide.left => 'Left side',
        StepSide.right => 'Right side',
        StepSide.none => null,
      };

  /// Target line, e.g. "15–20 reps", "30 sec", "Max reps".
  String get targetLabel {
    if (trackingType == TrackingType.maxReps) return 'Max reps';
    if (isTimed) return _range(targetMinSeconds, targetMaxSeconds, 'sec');
    return _range(targetMinReps, targetMaxReps, 'reps');
  }

  static String _range(int? min, int? max, String unit) {
    if (min == null && max == null) return unit;
    if (max == null || min == max) return '$min $unit';
    if (min == null) return '$max $unit';
    return '$min–$max $unit';
  }
}

/// Expands a [Workout] into the flat, ordered list of [PlayerStep]s the player
/// walks through. Each-side exercises become left + right steps; rest is
/// attached to the final step of each set, and suppressed after the very last
/// step of the workout.
List<PlayerStep> expandWorkout(Workout workout) {
  final steps = <PlayerStep>[];

  for (final item in workout.items) {
    for (var set = 1; set <= item.sets; set++) {
      if (item.trackingType.isEachSide) {
        // Left then right with no rest between sides; rest after the right.
        steps.add(_step(item, set, StepSide.left,
            restAfter: 0, isSetEnd: false));
        steps.add(_step(item, set, StepSide.right,
            restAfter: item.restSeconds, isSetEnd: true));
      } else {
        steps.add(_step(item, set, StepSide.none,
            restAfter: item.restSeconds, isSetEnd: true));
      }
    }
  }

  // No rest after the final step of the whole workout.
  if (steps.isNotEmpty) {
    final last = steps.removeLast();
    steps.add(PlayerStep(
      exerciseName: last.exerciseName,
      trackingType: last.trackingType,
      setNumber: last.setNumber,
      totalSets: last.totalSets,
      side: last.side,
      isFinisher: last.isFinisher,
      restAfterSeconds: 0,
      isSetEnd: last.isSetEnd,
      targetMinReps: last.targetMinReps,
      targetMaxReps: last.targetMaxReps,
      targetMinSeconds: last.targetMinSeconds,
      targetMaxSeconds: last.targetMaxSeconds,
      formCues: last.formCues,
    ));
  }

  return steps;
}

PlayerStep _step(
  WorkoutItem item,
  int setNumber,
  StepSide side, {
  required int restAfter,
  required bool isSetEnd,
}) {
  return PlayerStep(
    exerciseName: item.exercise.name,
    trackingType: item.trackingType,
    setNumber: setNumber,
    totalSets: item.sets,
    side: side,
    isFinisher: item.isFinisher,
    restAfterSeconds: restAfter,
    isSetEnd: isSetEnd,
    targetMinReps: item.minReps,
    targetMaxReps: item.maxReps,
    targetMinSeconds: item.minSeconds,
    targetMaxSeconds: item.maxSeconds,
    formCues: item.exercise.formCues,
  );
}
