import 'package:drift/drift.dart';

import '../models/exercise.dart';
import '../models/tracking_type.dart';
import '../models/workout.dart';
import 'db/app_database.dart';
import 'sample_data.dart';

/// Reads/writes the workout domain to the on-device database, and seeds it from
/// [SampleData] on first launch.
///
/// Screens read reactively via the `watch*` streams (Phases 3–4), so edits show
/// live; there is no startup snapshot anymore.
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

  // --- reactive workout watching ------------------------------------------

  /// Watches every workout (ordered by sortOrder) with its items joined to
  /// their exercises (ordered by position). Re-emits when any of the three
  /// tables change, so workout/item/exercise edits all show live.
  Stream<List<Workout>> watchWorkouts() {
    final query = _db.select(_db.workouts).join([
      leftOuterJoin(_db.workoutItems,
          _db.workoutItems.workoutId.equalsExp(_db.workouts.id)),
      leftOuterJoin(
          _db.exercises, _db.exercises.id.equalsExp(_db.workoutItems.exerciseId)),
    ])
      ..orderBy([
        OrderingTerm(expression: _db.workouts.sortOrder),
        OrderingTerm(expression: _db.workoutItems.position),
      ]);
    return query.watch().map(_assembleWorkouts);
  }

  /// Watches a single workout (with items), or null if it no longer exists.
  Stream<Workout?> watchWorkout(String id) {
    final query = _db.select(_db.workouts).join([
      leftOuterJoin(_db.workoutItems,
          _db.workoutItems.workoutId.equalsExp(_db.workouts.id)),
      leftOuterJoin(
          _db.exercises, _db.exercises.id.equalsExp(_db.workoutItems.exerciseId)),
    ])
      ..where(_db.workouts.id.equals(id))
      ..orderBy([OrderingTerm(expression: _db.workoutItems.position)]);
    return query.watch().map((rows) {
      final workouts = _assembleWorkouts(rows);
      return workouts.isEmpty ? null : workouts.first;
    });
  }

  /// Groups joined rows into ordered [Workout]s. A workout with no items still
  /// produces one row (left join) and yields an empty item list.
  List<Workout> _assembleWorkouts(List<TypedResult> rows) {
    final order = <String>[];
    final workoutRows = <String, WorkoutRow>{};
    final itemsByWorkout = <String, List<WorkoutItem>>{};

    for (final row in rows) {
      final workout = row.readTable(_db.workouts);
      if (!workoutRows.containsKey(workout.id)) {
        workoutRows[workout.id] = workout;
        itemsByWorkout[workout.id] = [];
        order.add(workout.id);
      }
      final itemRow = row.readTableOrNull(_db.workoutItems);
      final exerciseRow =
          itemRow == null ? null : row.readTableOrNull(_db.exercises);
      if (itemRow != null && exerciseRow != null) {
        itemsByWorkout[workout.id]!
            .add(_toItem(itemRow, _toExercise(exerciseRow)));
      }
    }

    return [
      for (final id in order)
        Workout(
          id: id,
          name: workoutRows[id]!.name,
          focus: workoutRows[id]!.focus,
          items: itemsByWorkout[id]!,
        ),
    ];
  }

  // --- workout create / update / delete -----------------------------------

  /// Creates an empty workout and returns its generated id.
  Future<String> createWorkout({required String name, String? focus}) async {
    final id = 'wk_${DateTime.now().millisecondsSinceEpoch}';
    final order = await _nextWorkoutSortOrder();
    await _db.into(_db.workouts).insert(WorkoutsCompanion.insert(
          id: id,
          name: name,
          focus: Value(focus),
          sortOrder: Value(order),
        ));
    return id;
  }

  Future<void> updateWorkoutMeta({
    required String id,
    required String name,
    String? focus,
  }) async {
    await (_db.update(_db.workouts)..where((t) => t.id.equals(id))).write(
      WorkoutsCompanion(name: Value(name), focus: Value(focus)),
    );
  }

  /// Deletes a workout; its items are removed by the FK cascade.
  Future<void> deleteWorkout(String id) async {
    await (_db.delete(_db.workouts)..where((t) => t.id.equals(id))).go();
  }

  // --- workout item create / update / delete / reorder --------------------

  Future<void> addWorkoutItem(String workoutId, WorkoutItem item) async {
    final position = await _nextItemPosition(workoutId);
    await _db
        .into(_db.workoutItems)
        .insert(_itemCompanion(workoutId, position, item));
  }

  Future<void> updateWorkoutItem(int itemId, WorkoutItem item) async {
    await (_db.update(_db.workoutItems)..where((t) => t.id.equals(itemId)))
        .write(WorkoutItemsCompanion(
      sets: Value(item.sets),
      minReps: Value(item.minReps),
      maxReps: Value(item.maxReps),
      minSeconds: Value(item.minSeconds),
      maxSeconds: Value(item.maxSeconds),
      restSeconds: Value(item.restSeconds),
      isFinisher: Value(item.isFinisher),
      notes: Value(item.notes),
    ));
  }

  Future<void> removeWorkoutItem(int itemId) async {
    await (_db.delete(_db.workoutItems)..where((t) => t.id.equals(itemId))).go();
  }

  /// Persists a new item order. [orderedItemIds] is the full list of item ids
  /// in their desired order; each row's position is set to its index.
  Future<void> reorderWorkoutItems(List<int> orderedItemIds) async {
    await _db.batch((batch) {
      for (var i = 0; i < orderedItemIds.length; i++) {
        batch.update(
          _db.workoutItems,
          WorkoutItemsCompanion(position: Value(i)),
          where: (t) => t.id.equals(orderedItemIds[i]),
        );
      }
    });
  }

  Future<int> _nextWorkoutSortOrder() async {
    final rows = await (_db.select(_db.workouts)
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.sortOrder, mode: OrderingMode.desc)
          ])
          ..limit(1))
        .get();
    return rows.isEmpty ? 0 : rows.first.sortOrder + 1;
  }

  Future<int> _nextItemPosition(String workoutId) async {
    final rows = await (_db.select(_db.workoutItems)
          ..where((t) => t.workoutId.equals(workoutId))
          ..orderBy([
            (t) => OrderingTerm(expression: t.position, mode: OrderingMode.desc)
          ])
          ..limit(1))
        .get();
    return rows.isEmpty ? 0 : rows.first.position + 1;
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
      id: row.id,
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
