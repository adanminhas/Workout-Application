import 'dart:math';

import '../models/exercise.dart';
import '../models/tracking_type.dart';
import '../models/workout.dart';

/// Options for [WorkoutGenerator.generate].
class GeneratorOptions {
  const GeneratorOptions({
    this.buckets = const {},
    this.targetMinutes = 20,
    this.includeCooldown = true,
    this.seed,
  });

  /// Muscle buckets to draw from (see [WorkoutGenerator.bucketFor]).
  /// Empty means "use everything".
  final Set<String> buckets;

  /// Rough total length to aim for, including the cooldown.
  final int targetMinutes;

  /// Append a short stretch cooldown at the end (if the library has stretches).
  final bool includeCooldown;

  /// Fixes the random pick order — used by tests; null = fresh shuffle.
  final int? seed;
}

/// A generated draft: not persisted until the user saves it.
class GeneratedWorkout {
  const GeneratedWorkout({
    required this.name,
    required this.focus,
    required this.items,
    required this.estimatedMinutes,
  });

  final String name;
  final String focus;
  final List<WorkoutItem> items;
  final int estimatedMinutes;

  bool get isEmpty => items.isEmpty;
}

/// Builds a balanced workout from the user's own exercise library — fully
/// offline, no AI/network. Picks round-robin across muscle buckets for
/// variety, gives each pick sensible set/rep/time defaults from its tracking
/// type, reserves max-reps movements as a finisher, and closes with stretches.
class WorkoutGenerator {
  WorkoutGenerator._();

  /// Keyword → bucket mapping, checked in order (first hit wins).
  static const List<(String, List<String>)> _bucketKeywords = [
    ('obliques', ['oblique', 'rotation']),
    ('abs', ['ab']),
    ('core', ['core']),
    ('back', ['back', 'spine', 'lat']),
    ('legs', ['hip', 'leg', 'glute', 'hamstring', 'quad', 'calf', 'calves']),
    ('upper body', ['chest', 'shoulder', 'arm', 'bicep', 'tricep', 'delt']),
  ];

  static const String otherBucket = 'other';

  /// Coarse muscle bucket for a free-text muscle group.
  static String bucketFor(String? muscleGroup) {
    final m = (muscleGroup ?? '').toLowerCase();
    for (final (bucket, keywords) in _bucketKeywords) {
      if (keywords.any(m.contains)) return bucket;
    }
    return otherBucket;
  }

  /// Display label for a bucket id.
  static String bucketLabel(String bucket) => switch (bucket) {
        'abs' => 'Abs',
        'obliques' => 'Obliques',
        'core' => 'Core',
        'back' => 'Back & spine',
        'legs' => 'Hips & legs',
        'upper body' => 'Upper body',
        _ => 'Other',
      };

  /// Buckets that actually occur in the (non-stretch) library, in a stable
  /// display order — drives the filter chips.
  static List<String> bucketsIn(List<Exercise> library) {
    final present = {
      for (final e in library.where((e) => !e.isStretch))
        bucketFor(e.muscleGroup),
    };
    final order = [for (final (b, _) in _bucketKeywords) b, otherBucket];
    return [
      for (final b in order)
        if (present.contains(b)) b,
    ];
  }

  static GeneratedWorkout generate(
      List<Exercise> library, GeneratorOptions options) {
    final rng = Random(options.seed);

    bool inScope(Exercise e) =>
        options.buckets.isEmpty ||
        options.buckets.contains(bucketFor(e.muscleGroup));

    final work =
        library.where((e) => !e.isStretch && inScope(e)).toList();
    final stretches = library.where((e) => e.isStretch).toList()..shuffle(rng);
    final finishers = work
        .where((e) => e.trackingType == TrackingType.maxReps)
        .toList()
      ..shuffle(rng);
    final mainPool =
        work.where((e) => e.trackingType != TrackingType.maxReps).toList();

    // Group by bucket, then shuffle within and across buckets so repeated
    // generates give different-but-balanced mixes.
    final byBucket = <String, List<Exercise>>{};
    for (final e in mainPool) {
      byBucket.putIfAbsent(bucketFor(e.muscleGroup), () => []).add(e);
    }
    for (final list in byBucket.values) {
      list.shuffle(rng);
    }
    final bucketOrder = byBucket.keys.toList()..shuffle(rng);

    final hasCooldown = options.includeCooldown && stretches.isNotEmpty;
    final cooldownBudget = hasCooldown ? 4 : 0;
    // Reserve room so the finisher is part of the plan, not leftover space.
    final finisherBudget = finishers.isEmpty ? 0 : 3;
    final mainTarget =
        max(5, options.targetMinutes - cooldownBudget - finisherBudget);

    final items = <WorkoutItem>[];
    var est = 0;
    var added = true;
    while (added && est < mainTarget) {
      added = false;
      for (final bucket in bucketOrder) {
        if (est >= mainTarget) break;
        final list = byBucket[bucket]!;
        if (list.isEmpty) continue;
        items.add(_itemFor(list.removeLast()));
        est = _estimate(items);
        added = true;
      }
    }

    // One burnout finisher whenever the library offers one (room was reserved).
    if (items.isNotEmpty && finishers.isNotEmpty) {
      items.add(WorkoutItem(
        exercise: finishers.first,
        sets: 2,
        restSeconds: 60,
        isFinisher: true,
      ));
      est = _estimate(items);
    }

    if (hasCooldown && items.isNotEmpty) {
      for (final s in stretches.take(4)) {
        items.add(WorkoutItem(
          exercise: s,
          sets: 1,
          minSeconds: 20,
          maxSeconds: 30,
          restSeconds: 10,
        ));
      }
      est = _estimate(items);
    }

    final label = options.buckets.isEmpty
        ? 'Mixed'
        : options.buckets.map(bucketLabel).join(' + ');
    return GeneratedWorkout(
      name: '$label Workout',
      focus: 'Auto-generated',
      items: items,
      estimatedMinutes: est,
    );
  }

  /// Sensible per-set defaults by tracking type (mirrors the seed program).
  static WorkoutItem _itemFor(Exercise e) => switch (e.trackingType) {
        TrackingType.reps => WorkoutItem(
            exercise: e, sets: 3, minReps: 10, maxReps: 15, restSeconds: 60),
        TrackingType.repsEachSide => WorkoutItem(
            exercise: e, sets: 3, minReps: 10, maxReps: 12, restSeconds: 60),
        TrackingType.timed => WorkoutItem(
            exercise: e,
            sets: 3,
            minSeconds: 30,
            maxSeconds: 45,
            restSeconds: 60),
        TrackingType.timedEachSide => WorkoutItem(
            exercise: e,
            sets: 3,
            minSeconds: 20,
            maxSeconds: 30,
            restSeconds: 45),
        TrackingType.hold => WorkoutItem(
            exercise: e,
            sets: 3,
            minSeconds: 20,
            maxSeconds: 30,
            restSeconds: 60),
        // maxReps is handled as the finisher; stretch as cooldown. Fallbacks
        // here keep the generator total if either sneaks into the main pool.
        TrackingType.maxReps =>
          WorkoutItem(exercise: e, sets: 2, restSeconds: 60, isFinisher: true),
        TrackingType.stretch => WorkoutItem(
            exercise: e,
            sets: 1,
            minSeconds: 20,
            maxSeconds: 30,
            restSeconds: 10),
      };

  static int _estimate(List<WorkoutItem> items) =>
      Workout(id: '_draft', name: '_', items: items).estimatedMinutes;
}
