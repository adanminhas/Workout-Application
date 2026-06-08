import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

/// The on-device SQLite database (Phase 2). Stored as a single file in the
/// app's private documents directory on the phone — fully offline, no backend.
///
/// Schema is intentionally a superset of what Phase 2 reads: `WorkoutSessions`
/// and `CompletedSets` are created now but only written/read once history and
/// the calendar arrive in Phase 6.

/// Library movement (an exercise or a stretch). Mirrors `models/Exercise`.
@DataClassName('ExerciseRow')
class Exercises extends Table {
  /// Stable string id (e.g. `crunches`) — also used to seed idempotently.
  TextColumn get id => text()();
  TextColumn get name => text()();

  /// `TrackingType.name` (e.g. `reps`, `timedEachSide`). Parsed back with
  /// `TrackingType.values.byName(...)`.
  TextColumn get trackingType => text()();
  BoolColumn get isStretch => boolean().withDefault(const Constant(false))();
  TextColumn get instructions => text().nullable()();
  TextColumn get formCues => text().nullable()();
  TextColumn get muscleGroup => text().nullable()();

  /// Display order in the library.
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// A workout "day". Mirrors `models/Workout` (its items live in [WorkoutItems]).
@DataClassName('WorkoutRow')
class Workouts extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get focus => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// One exercise placed inside a workout, with per-workout target overrides.
/// Mirrors `models/WorkoutItem`. Ordered within a workout by [position].
@DataClassName('WorkoutItemRow')
class WorkoutItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get workoutId =>
      text().references(Workouts, #id, onDelete: KeyAction.cascade)();
  TextColumn get exerciseId => text().references(Exercises, #id)();
  IntColumn get position => integer()();
  IntColumn get sets => integer()();
  IntColumn get minReps => integer().nullable()();
  IntColumn get maxReps => integer().nullable()();
  IntColumn get minSeconds => integer().nullable()();
  IntColumn get maxSeconds => integer().nullable()();
  IntColumn get restSeconds => integer().withDefault(const Constant(60))();
  BoolColumn get isFinisher => boolean().withDefault(const Constant(false))();
  TextColumn get notes => text().nullable()();
}

/// One guided run of a workout. Written in Phase 6.
@DataClassName('WorkoutSessionRow')
class WorkoutSessions extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Nullable so history survives the workout being deleted later (Phase 4).
  TextColumn get workoutId => text().nullable()();

  /// Snapshot of the workout's name at run time, for stable history display.
  TextColumn get workoutName => text()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();
}

/// One completed set within a session. Written in Phase 6.
@DataClassName('CompletedSetRow')
class CompletedSets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get sessionId =>
      integer().references(WorkoutSessions, #id, onDelete: KeyAction.cascade)();
  TextColumn get exerciseId => text()();
  TextColumn get exerciseName => text()();
  IntColumn get setIndex => integer()();

  /// `left` / `right` for each-side movements, otherwise null.
  TextColumn get side => text().nullable()();
  IntColumn get repsDone => integer().nullable()();
  IntColumn get secondsDone => integer().nullable()();
  DateTimeColumn get completedAt => dateTime()();
}

@DriftDatabase(
  tables: [Exercises, Workouts, WorkoutItems, WorkoutSessions, CompletedSets],
)
class AppDatabase extends _$AppDatabase {
  /// Opens the on-device database file. Tests pass an in-memory executor.
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? driftDatabase(name: 'setflow'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (details) async {
          // Enforce the foreign keys declared above (off by default in SQLite).
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
