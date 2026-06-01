/// How a single set of an exercise is performed and measured.
///
/// This drives what the workout player shows: a "Done" button for rep-based
/// work, or a countdown timer for time-based work, and whether the set is
/// split into a left/right side.
enum TrackingType {
  /// Fixed rep target, single side. Shows a Done button.
  reps,

  /// Rep target performed on each side. Splits into left + right Done steps.
  repsEachSide,

  /// Hold/movement for a number of seconds. Shows a countdown timer.
  timed,

  /// Timed effort performed on each side. Splits into left + right timers.
  timedEachSide,

  /// Static hold for time (e.g. lower-body hold). Shows a countdown timer.
  hold,

  /// "As many as you can" finisher. Shows a Done button.
  maxReps,

  /// Cooldown stretch held for time. Shows a countdown timer.
  stretch;

  /// True when this set is measured by a countdown timer rather than reps.
  bool get isTimed =>
      this == timed || this == timedEachSide || this == hold || this == stretch;

  /// True when a single set is split into separate left and right efforts.
  bool get isEachSide => this == repsEachSide || this == timedEachSide;

  /// Short human label used in editors / summaries.
  String get label => switch (this) {
        TrackingType.reps => 'Reps',
        TrackingType.repsEachSide => 'Reps (each side)',
        TrackingType.timed => 'Timed',
        TrackingType.timedEachSide => 'Timed (each side)',
        TrackingType.hold => 'Hold',
        TrackingType.maxReps => 'Max reps',
        TrackingType.stretch => 'Stretch',
      };
}
