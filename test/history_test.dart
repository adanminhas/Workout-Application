import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:setflow/data/db/app_database.dart';
import 'package:setflow/data/workout_repository.dart';
import 'package:setflow/models/exercise.dart';
import 'package:setflow/models/tracking_type.dart';
import 'package:setflow/models/workout.dart';
import 'package:setflow/models/workout_session.dart';

void main() {
  test('recordSession persists a session + sets, and deleteSession removes them',
      () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = WorkoutRepository(db);

    const exercise =
        Exercise(id: 'e1', name: 'Crunches', trackingType: TrackingType.reps);
    const workout = Workout(id: 'w1', name: 'Day A', items: [
      WorkoutItem(exercise: exercise, sets: 2, minReps: 15, maxReps: 20),
    ]);
    final start = DateTime(2026, 6, 18, 10);

    await repo.recordSession(
      workout: workout,
      startedAt: start,
      completedAt: start.add(const Duration(minutes: 12)),
      sets: [
        CompletedSetRecord(
            exerciseId: 'e1',
            exerciseName: 'Crunches',
            setIndex: 1,
            repsDone: 20,
            completedAt: start),
        CompletedSetRecord(
            exerciseId: 'e1',
            exerciseName: 'Crunches',
            setIndex: 2,
            repsDone: 20,
            completedAt: start),
      ],
    );

    final sessions = await repo.watchSessions().first;
    expect(sessions, hasLength(1));
    expect(sessions.first.workoutName, 'Day A');
    expect(sessions.first.setCount, 2);
    expect(sessions.first.duration, const Duration(minutes: 12));

    final sets = await repo.getSessionSets(sessions.first.id);
    expect(sets, hasLength(2));
    expect(sets.first.exerciseName, 'Crunches');
    expect(sets.first.repsDone, 20);

    await repo.deleteSession(sessions.first.id);
    expect(await repo.watchSessions().first, isEmpty);
    // Cascade removed the completed sets too.
    expect(await repo.getSessionSets(sessions.first.id), isEmpty);
  });

  test('clearAllSessions wipes every session and completed set', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = WorkoutRepository(db);

    const exercise =
        Exercise(id: 'e1', name: 'Crunches', trackingType: TrackingType.reps);
    const workout = Workout(id: 'w1', name: 'Day A', items: [
      WorkoutItem(exercise: exercise, sets: 1),
    ]);

    for (var i = 0; i < 3; i++) {
      final start = DateTime(2026, 6, 10 + i, 9);
      await repo.recordSession(
        workout: workout,
        startedAt: start,
        completedAt: start.add(const Duration(minutes: 5)),
        sets: [
          CompletedSetRecord(
              exerciseId: 'e1',
              exerciseName: 'Crunches',
              setIndex: 1,
              completedAt: start),
        ],
      );
    }
    expect(await repo.watchSessions().first, hasLength(3));

    await repo.clearAllSessions();
    expect(await repo.watchSessions().first, isEmpty);
  });
}
