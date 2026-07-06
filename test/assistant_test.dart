import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:setflow/data/assistant_actions.dart';
import 'package:setflow/data/db/app_database.dart';
import 'package:setflow/data/workout_repository.dart';
import 'package:setflow/models/exercise.dart';
import 'package:setflow/models/tracking_type.dart';

const _reply = '''
Here's a plan that mixes your crunches with a new move.

```json
{
  "newExercises": [
    {"name": "Pike Push-up", "trackingType": "Reps", "muscleGroup": "Shoulders"}
  ],
  "workout": {
    "name": "Core & Shoulders",
    "focus": "Push + core",
    "items": [
      {"exercise": "crunches", "sets": 3, "minReps": 15, "maxReps": 10},
      {"exercise": "Pike Push-up", "sets": "4", "restSeconds": 90},
      {"exercise": "plank_x", "sets": 3, "minSeconds": 30, "maxSeconds": 45}
    ]
  }
}
```
Enjoy!
''';

void main() {
  test('extractProposal parses fenced json leniently', () {
    final p = extractProposal(_reply)!;
    expect(p.newExercises, hasLength(1));
    expect(p.newExercises.first.trackingType, TrackingType.reps);
    final w = p.workout!;
    expect(w.name, 'Core & Shoulders');
    expect(w.items, hasLength(3));
    //

    // Swapped range gets fixed; string sets parsed.
    expect(w.items[0].minReps, 10);
    expect(w.items[0].maxReps, 15);
    expect(w.items[1].sets, 4);
  });

  test('extractProposal returns null without a json block and throws on junk',
      () {
    expect(extractProposal('Just advice, no plan.'), isNull);
    expect(() => extractProposal('```json\n{broken\n```'),
        throwsFormatException);
  });

  test('parseTrackingType tolerates sloppy spellings', () {
    expect(parseTrackingType('reps_each_side'), TrackingType.repsEachSide);
    expect(parseTrackingType('Timed Each Side'), TrackingType.timedEachSide);
    expect(parseTrackingType('isometric hold'), TrackingType.hold);
    expect(parseTrackingType('AMRAP'), TrackingType.maxReps);
    expect(parseTrackingType('Stretching'), TrackingType.stretch);
    expect(parseTrackingType('duration'), TrackingType.timed);
    expect(parseTrackingType(null), TrackingType.reps);
  });

  test('fuzzy targets: survives invented field names from small models', () {
    // Verbatim structure from a live qwen2.5:3b reply.
    final p = parseProposal({
      'workout': {
        'name': 'Core Fusion',
        'items': [
          {
            'exercise': 'crunches',
            'sets': 4,
            'minRepsEachSide': 10,
            'maxRepsEachSide': 20,
            'restSecondsPerSet': 60,
          },
          {'exercise': 'side_plank', 'sets': 3, 'timedEachSide': 30},
          {'exercise': 'lower_body_hold', 'sets': 2, 'holdDurationSeconds': 5},
          {'exercise': 'sit_ups', 'sets': 2, 'reps': 12},
        ],
      },
    });
    final items = p.workout!.items;
    expect(items[0].minReps, 10);
    expect(items[0].maxReps, 20);
    expect(items[0].restSeconds, 60);
    expect(items[1].minSeconds, 30);
    expect(items[1].maxSeconds, 30);
    expect(items[2].minSeconds, 5);
    expect(items[3].minReps, 12);
    expect(items[3].maxReps, 12);
  });

  test('resolveExerciseRef survives annotated/plural/hyphenated refs', () {
    const pushUp = Exercise(
        id: 'ex_1', name: 'Push-Up', trackingType: TrackingType.reps);
    const closeGrip = Exercise(
        id: 'ex_2',
        name: 'Close-Grip Push-Up (GHR)',
        trackingType: TrackingType.reps);
    const decline = Exercise(
        id: 'ex_3', name: 'Decline Push-Up', trackingType: TrackingType.reps);
    const pool = [pushUp, closeGrip, decline];

    // The exact refs from a live qwen2.5:3b plan that used to be rejected.
    expect(resolveExerciseRef('push-up (chest/shoulders/triceps)', pool),
        pushUp);
    expect(resolveExerciseRef('close-grip push-up (triceps only)', pool),
        closeGrip);
    expect(resolveExerciseRef('decline push-up (chest/shoulders/triceps)',
        pool), decline);
    // Plural + spacing variants.
    expect(resolveExerciseRef('Push ups', pool), pushUp);
    expect(resolveExerciseRef('ex_2', pool), closeGrip);
    expect(resolveExerciseRef('bench press', pool), isNull);
  });

  test('applyProposal reuses a canonically-equal library exercise', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = WorkoutRepository(db);
    const pushUps = Exercise(
        id: 'push_ups', name: 'Push-ups', trackingType: TrackingType.reps);
    await repo.createExercise(pushUps);

    // Model re-declares "Push-Up" as new — must be deduped, not duplicated.
    final proposal = parseProposal({
      'newExercises': [
        {'name': 'Push-Up', 'trackingType': 'reps'},
      ],
      'workout': {
        'name': 'Push Day',
        'items': [
          {'exercise': 'push-up (chest)', 'sets': 3, 'minReps': 8},
        ],
      },
    });
    final applied = await applyProposal(repo, [pushUps], proposal);
    expect(applied.createdExercises, 0);
    final workouts = await repo.watchWorkouts().first;
    expect(workouts.single.items.single.exercise.id, 'push_ups');
    expect(await repo.watchExercises().first, hasLength(1));
  });

  test('applyProposal creates exercises + workout; unknown refs throw',
      () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = WorkoutRepository(db);
    const crunches = Exercise(
        id: 'crunches', name: 'Crunches', trackingType: TrackingType.reps);
    await repo.createExercise(crunches);

    final good = parseProposal({
      'newExercises': [
        {'name': 'Pike Push-up', 'trackingType': 'reps'},
      ],
      'workout': {
        'name': 'Test Day',
        'items': [
          {'exercise': 'crunches', 'sets': 3, 'minReps': 10, 'maxReps': 15},
          {'exercise': 'pike push-up', 'sets': 2},
        ],
      },
    });
    final applied = await applyProposal(repo, [crunches], good);
    expect(applied.createdExercises, 1);
    expect(applied.workoutId, isNotNull);

    final workouts = await repo.watchWorkouts().first;
    final saved = workouts.singleWhere((w) => w.name == 'Test Day');
    expect(saved.items, hasLength(2));
    expect(saved.items[1].exercise.name, 'Pike Push-up');

    final bad = parseProposal({
      'workout': {
        'name': 'Broken',
        'items': [
          {'exercise': 'does-not-exist', 'sets': 3},
        ],
      },
    });
    final library = await repo.watchExercises().first;
    await expectLater(
        applyProposal(repo, library, bad), throwsFormatException);
    // The broken workout must not have been half-created.
    final after = await repo.watchWorkouts().first;
    expect(after.where((w) => w.name == 'Broken'), isEmpty);
  });
}
