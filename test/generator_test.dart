import 'package:flutter_test/flutter_test.dart';

import 'package:setflow/data/workout_generator.dart';
import 'package:setflow/models/exercise.dart';
import 'package:setflow/models/tracking_type.dart';

Exercise _ex(String id, TrackingType type, String muscle,
        {bool stretch = false}) =>
    Exercise(
      id: id,
      name: id,
      trackingType: type,
      muscleGroup: muscle,
      isStretch: stretch,
    );

/// A library big enough to fill any target length, across three buckets,
/// with one max-reps candidate and a few stretches.
final List<Exercise> _library = [
  for (var i = 0; i < 6; i++) _ex('abs_$i', TrackingType.reps, 'Upper abs'),
  for (var i = 0; i < 6; i++)
    _ex('obl_$i', TrackingType.timedEachSide, 'Obliques'),
  for (var i = 0; i < 6; i++) _ex('core_$i', TrackingType.hold, 'Core'),
  _ex('burnout', TrackingType.maxReps, 'Abs'),
  for (var i = 0; i < 4; i++)
    _ex('str_$i', TrackingType.stretch, 'Spine', stretch: true),
];

void main() {
  test('hits the target length within tolerance and never repeats an exercise',
      () {
    final w = WorkoutGenerator.generate(
      _library,
      const GeneratorOptions(targetMinutes: 25, seed: 42),
    );
    expect(w.isEmpty, isFalse);
    expect(w.estimatedMinutes, inInclusiveRange(18, 32));

    final ids = w.items.map((i) => i.exercise.id).toList();
    expect(ids.toSet().length, ids.length, reason: 'no duplicate exercises');
  });

  test('cooldown stretches come last; finisher sits between work and cooldown',
      () {
    final w = WorkoutGenerator.generate(
      _library,
      const GeneratorOptions(targetMinutes: 30, seed: 7),
    );
    final items = w.items;
    final firstStretch = items.indexWhere((i) => i.exercise.isStretch);
    expect(firstStretch, greaterThan(0));
    // Everything from the first stretch on is a stretch.
    expect(items.skip(firstStretch).every((i) => i.exercise.isStretch), isTrue);

    final finisherIndex = items.indexWhere((i) => i.isFinisher);
    expect(finisherIndex, greaterThanOrEqualTo(0));
    expect(finisherIndex, lessThan(firstStretch));
    // The finisher is the last non-stretch item.
    expect(finisherIndex, firstStretch - 1);
  });

  test('bucket filter restricts picks (stretch cooldown still allowed)', () {
    final w = WorkoutGenerator.generate(
      _library,
      const GeneratorOptions(
          buckets: {'obliques'}, targetMinutes: 15, seed: 3),
    );
    final work = w.items.where((i) => !i.exercise.isStretch);
    expect(work, isNotEmpty);
    expect(
      work.every(
          (i) => WorkoutGenerator.bucketFor(i.exercise.muscleGroup) ==
              'obliques'),
      isTrue,
    );
  });

  test('no cooldown when disabled; empty library yields an empty draft', () {
    final w = WorkoutGenerator.generate(
      _library,
      const GeneratorOptions(targetMinutes: 20, includeCooldown: false, seed: 1),
    );
    expect(w.items.any((i) => i.exercise.isStretch), isFalse);

    final empty =
        WorkoutGenerator.generate(const [], const GeneratorOptions(seed: 1));
    expect(empty.isEmpty, isTrue);
  });

  test('cooldown never outnumbers the work (small pools stay balanced)', () {
    // One matching work exercise + plenty of stretches: the old behavior
    // produced 1 work + 4 stretches ("mostly stretches" bug).
    final tiny = [
      _ex('only_work', TrackingType.reps, 'Upper abs'),
      for (var i = 0; i < 5; i++)
        _ex('s_$i', TrackingType.stretch, 'Spine', stretch: true),
    ];
    final w = WorkoutGenerator.generate(
      tiny,
      const GeneratorOptions(targetMinutes: 20, seed: 5),
    );
    final work = w.items.where((i) => !i.exercise.isStretch).length;
    final cool = w.items.where((i) => i.exercise.isStretch).length;
    expect(work, greaterThan(0));
    expect(cool, lessThanOrEqualTo(work));
  });

  test('same seed reproduces the same draft', () {
    final a = WorkoutGenerator.generate(
        _library, const GeneratorOptions(targetMinutes: 20, seed: 99));
    final b = WorkoutGenerator.generate(
        _library, const GeneratorOptions(targetMinutes: 20, seed: 99));
    expect(a.items.map((i) => i.exercise.id).toList(),
        b.items.map((i) => i.exercise.id).toList());
  });
}
