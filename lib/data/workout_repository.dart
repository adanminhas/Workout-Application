import 'package:drift/drift.dart';

import '../models/exercise.dart';
import '../models/tracking_type.dart';
import '../models/workout.dart';
import 'db/app_database.dart';
import 'sample_data.dart';

/// Immutable snapshot of the library + workouts loaded from the database.
///
/// Screens read from this. Phase 2 has no editing, so a one-shot load at
/// startup is enough; reactive Drift streams arrive alongside editing in
/// Phases 3–4.
class AppData {
  const AppData({required this.exercises, required this.workouts});

  final List<Exercise> exercises;
  final List<Workout> workouts;

  Workout? workoutById(String id) {
    for (final workout in workouts) {
      if (workout.id == id) return workout;
    }
    return null;
  }
}

/// Reads/writes the workout domain to the on-device database, and seeds it from
/// [SampleData] on first launch.
class WorkoutRepository {
  WorkoutRepository(this._db);

  final AppDatabase _db;

  /// Seeds the hardcoded [SampleData] into an empty database. Idempotent — once
  /// any exercise exists this is a no-op, so it's safe to call every launch.
  Future<void> seedIfEmpty() async {
    final existing = await (_db.select(_db.exercises)..limit(1)).get();
    if (existing.isNotEmpty) return;

    await _db.batch((batch) {
      for (var i = 0; i < SampleData.exercises.length; i++) {
        batch.insert(_db.exercises, _exerciseCompanion(SampleData.exercises[i], i));
      }
      for (var w = 0; w < SampleData.workouts.length; w++) {
        final workout = SampleData.workouts[w];
        batch.insert(
          _db.workouts,
          WorkoutsCompanion.insert(
            id: workout.id,
            name: workout.name,
            focus: Value(workout.focus),
            sortOrder: Value(w),
          ),
        );
        for (var p = 0; p < workout.items.length; p++) {
          batch.insert(_db.workoutItems, _itemCompanion(workout.id, p, workout.items[p]));
        }
      }
    });
  }

  /// Loads the full library + workouts into an in-memory [AppData] snapshot.
  Future<AppData> loadAll() async {
    final exerciseRows = await (_db.select(_db.exercises)
          ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]))
        .get();
    final exercises = exerciseRows.map(_toExercise).toList();
    final exerciseById = {for (final e in exercises) e.id: e};

    final workoutRows = await (_db.select(_db.workouts)
          ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]))
        .get();
    final itemRows = await (_db.select(_db.workoutItems)
          ..orderBy([
            (t) => OrderingTerm(expression: t.workoutId),
            (t) => OrderingTerm(expression: t.position),
          ]))
        .get();

    final itemsByWorkout = <String, List<WorkoutItem>>{};
    for (final row in itemRows) {
      final exercise = exerciseById[row.exerciseId];
      if (exercise == null) continue; // defensive: orphaned item
      itemsByWorkout
          .putIfAbsent(row.workoutId, () => [])
          .add(_toItem(row, exercise));
    }

    final workouts = workoutRows
        .map((row) => Workout(
              id: row.id,
              name: row.name,
              focus: row.focus,
              items: itemsByWorkout[row.id] ?? const [],
            ))
        .toList();

    return AppData(exercises: exercises, workouts: workouts);
  }

  // --- row <-> domain mapping ---------------------------------------------

  static ExercisesCompanion _exerciseCompanion(Exercise e, int sortOrder) {
    return ExercisesCompanion.insert(
      id: e.id,
      name: e.name,
      trackingType: e.trackingType.name,
      isStretch: Value(e.isStretch),
      instructions: Value(e.instructions),
      formCues: Value(e.formCues),
      muscleGroup: Value(e.muscleGroup),
      sortOrder: Value(sortOrder),
    );
  }

  static WorkoutItemsCompanion _itemCompanion(
      String workoutId, int position, WorkoutItem item) {
    return WorkoutItemsCompanion.insert(
      workoutId: workoutId,
      exerciseId: item.exercise.id,
      position: position,
      sets: item.sets,
      minReps: Value(item.minReps),
      maxReps: Value(item.maxReps),
      minSeconds: Value(item.minSeconds),
      maxSeconds: Value(item.maxSeconds),
      restSeconds: Value(item.restSeconds),
      isFinisher: Value(item.isFinisher),
      notes: Value(item.notes),
    );
  }

  // --- reactive watching --------------------------------------------------

  /// Reactively watches all exercises ordered by sortOrder.
  Stream<List<Exercise>> watchExercises() {
    return (_db.select(_db.exercises)
          ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]))
        .watch()
        .map((rows) => rows.map(_toExercise).toList());
  }

  // --- create / update / delete -------------------------------------------

  Future<void> createExercise(Exercise exercise) async {
    final order = await _nextSortOrder();
    await _db.into(_db.exercises).insert(_exerciseCompanion(exercise, order));
  }

  Future<void> updateExercise(Exercise exercise) async {
    final existing = await (_db.select(_db.exercises)
          ..where((t) => t.id.equals(exercise.id)))
        .getSingleOrNull();
    final order = existing?.sortOrder ?? await _nextSortOrder();
    await _db
        .into(_db.exercises)
        .insertOnConflictUpdate(_exerciseCompanion(exercise, order));
  }

  /// How many workout items reference this exercise.
  Future<int> countExerciseUsages(String exerciseId) async {
    final rows = await (_db.select(_db.workoutItems)
          ..where((t) => t.exerciseId.equals(exerciseId)))
        .get();
    return rows.length;
  }

  /// Deletes workout items that reference the exercise first (FK enforcement),
  /// then deletes the exercise itself.
  Future<void> deleteExercise(String id) async {
    await (_db.delete(_db.workoutItems)
          ..where((t) => t.exerciseId.equals(id)))
        .go();
    await (_db.delete(_db.exercises)..where((t) => t.id.equals(id))).go();
  }

  Future<int> _nextSortOrder() async {
    final rows = await (_db.select(_db.exercises)
          ..orderBy([(t) => OrderingTerm(
                expression: t.sortOrder,
                mode: OrderingMode.desc)])
          ..limit(1))
        .get();
    return rows.isEmpty ? 0 : rows.first.sortOrder + 1;
  }

  static Exercise _toExercise(ExerciseRow row) {
    return Exercise(
      id: row.id,
      name: row.name,
      trackingType: TrackingType.values.byName(row.trackingType),
      isStretch: row.isStretch,
      instructions: row.instructions,
      formCues: row.formCues,
      muscleGroup: row.muscleGroup,
    );
  }

  static WorkoutItem _toItem(WorkoutItemRow row, Exercise exercise) {
    return WorkoutItem(
      exercise: exercise,
      sets: row.sets,
      minReps: row.minReps,
      maxReps: row.maxReps,
      minSeconds: row.minSeconds,
      maxSeconds: row.maxSeconds,
      restSeconds: row.restSeconds,
      isFinisher: row.isFinisher,
      notes: row.notes,
    );
  }
}
