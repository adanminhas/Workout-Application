/// A recorded run of a workout (Phase 6 history). Mirrors a `WorkoutSessions`
/// row; the workout name is snapshotted so history reads stay stable even if
/// the workout is later renamed or deleted.
class WorkoutSessionSummary {
  const WorkoutSessionSummary({
    required this.id,
    required this.workoutName,
    required this.startedAt,
    this.workoutId,
    this.completedAt,
    this.setCount = 0,
  });

  final int id;
  final String? workoutId;
  final String workoutName;
  final DateTime startedAt;
  final DateTime? completedAt;

  /// Number of completed sets recorded for this session.
  final int setCount;

  Duration? get duration => completedAt?.difference(startedAt);
}

/// One completed set within a session — used both to record (draft) and to
/// read back (history detail). Mirrors a `CompletedSets` row.
class CompletedSetRecord {
  const CompletedSetRecord({
    required this.exerciseId,
    required this.exerciseName,
    required this.setIndex,
    required this.completedAt,
    this.side,
    this.repsDone,
    this.secondsDone,
  });

  final String exerciseId;
  final String exerciseName;
  final int setIndex;
  final String? side;
  final int? repsDone;
  final int? secondsDone;
  final DateTime completedAt;

  /// Human label for the work done, e.g. "20 reps", "30 sec", or "done".
  String get doneLabel {
    if (secondsDone != null) return '$secondsDone sec';
    if (repsDone != null) return '$repsDone reps';
    return 'done';
  }
}
