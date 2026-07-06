import 'dart:convert';

import '../models/exercise.dart';
import '../models/tracking_type.dart';
import '../models/workout.dart';
import 'workout_repository.dart';

/// The structured things the assistant can propose in a reply. Parsed from a
/// fenced ```json block; nothing touches the database until the user taps
/// Save, and then it goes through the normal repository methods.
class AssistantProposal {
  const AssistantProposal({this.newExercises = const [], this.workout});

  final List<Exercise> newExercises;
  final ProposedWorkout? workout;

  bool get isEmpty => newExercises.isEmpty && workout == null;
}

class ProposedWorkout {
  const ProposedWorkout({
    required this.name,
    this.focus,
    required this.items,
  });

  final String name;
  final String? focus;
  final List<ProposedItem> items;
}

class ProposedItem {
  const ProposedItem({
    required this.exerciseRef,
    required this.sets,
    this.minReps,
    this.maxReps,
    this.minSeconds,
    this.maxSeconds,
    this.restSeconds = 60,
    this.isFinisher = false,
    this.notes,
  });

  /// Library id, library name, or the name of one of the new exercises.
  final String exerciseRef;
  final int sets;
  final int? minReps;
  final int? maxReps;
  final int? minSeconds;
  final int? maxSeconds;
  final int restSeconds;
  final bool isFinisher;
  final String? notes;
}

/// System prompt: tells the model what it is, what the user's library holds,
/// and the exact JSON contract for creating things.
String buildSystemPrompt(List<Exercise> library) {
  final lines = [
    for (final e in library.take(80))
      '- ${e.id} | ${e.name} | ${e.trackingType.name}'
          '${e.muscleGroup == null ? '' : ' | ${e.muscleGroup}'}',
  ];
  return '''
You are the workout assistant inside SetFlow, a local-first workout app. You help the user plan workouts and design exercises. Be concise and practical.

The user's exercise library (id | name | tracking type | muscle group):
${lines.join('\n')}

Valid tracking types: reps, repsEachSide, timed, timedEachSide, hold, maxReps, stretch.
- reps/repsEachSide/maxReps items use minReps/maxReps (maxReps type = burnout, no targets).
- timed/timedEachSide/hold/stretch items use minSeconds/maxSeconds.

ONLY when the user asks you to create a workout and/or new exercises, end your reply with exactly one fenced json block in this shape (omit "workout" or "newExercises" if not needed):
```json
{
  "newExercises": [
    {"name": "Pike Push-up", "trackingType": "reps", "muscleGroup": "Shoulders", "formCues": "...", "instructions": "..."}
  ],
  "workout": {
    "name": "Shoulder Day",
    "focus": "Shoulders & core",
    "items": [
      {"exercise": "crunches", "sets": 3, "minReps": 10, "maxReps": 15, "restSeconds": 60},
      {"exercise": "Pike Push-up", "sets": 3, "minReps": 8, "maxReps": 12, "restSeconds": 90, "isFinisher": false}
    ]
  }
}
```
Rules for the json:
- use EXACTLY the field names shown above (sets, minReps, maxReps, minSeconds, maxSeconds, restSeconds, isFinisher) — never invent field names.
- BEFORE adding anything to newExercises, check the library list for the same movement under a slightly different name (plural/singular, hyphenation — "Push-ups" vs "Push-Up") and reuse its id instead.
- each item's "exercise" value must be EXACTLY a library id or a newExercises name — nothing else. Never append annotations like "(chest/shoulders)" to it; put such detail in "notes".
- workouts should be mostly working sets — stretches only as a short cooldown at the end; keep 3-8 working items for a normal session.
For ordinary questions or advice, reply normally WITHOUT a json block.''';
}

/// Extracts the proposal JSON from a model reply, or null if the reply has no
/// json block. Throws [FormatException] (displayable message) when a block
/// exists but cannot be parsed.
AssistantProposal? extractProposal(String reply) {
  final fence =
      RegExp(r'```(?:json)?\s*([\s\S]*?)```', multiLine: true).allMatches(reply);
  String? raw;
  for (final m in fence) {
    final body = m.group(1)!.trim();
    if (body.startsWith('{')) raw = body; // last json-looking block wins
  }
  if (raw == null) return null;

  final dynamic decoded;
  try {
    decoded = jsonDecode(raw);
  } catch (_) {
    throw const FormatException(
        'The model produced an invalid JSON block — ask it to try again.');
  }
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('The JSON block was not an object.');
  }
  return parseProposal(decoded);
}

/// Lenient parse of the proposal object (tolerates missing optionals,
/// sloppy tracking-type spellings, swapped ranges, string numbers).
AssistantProposal parseProposal(Map<String, dynamic> json) {
  final newExercises = <Exercise>[];
  final rawNew = json['newExercises'];
  if (rawNew is List) {
    var i = 0;
    for (final e in rawNew) {
      if (e is! Map<String, dynamic>) continue;
      final name = (e['name'] as String?)?.trim();
      if (name == null || name.isEmpty) continue;
      final type = parseTrackingType(e['trackingType']?.toString());
      newExercises.add(Exercise(
        id: 'ex_${DateTime.now().millisecondsSinceEpoch}_${i++}',
        name: name,
        trackingType: type,
        isStretch: type == TrackingType.stretch,
        muscleGroup: _optString(e['muscleGroup']),
        formCues: _optString(e['formCues']),
        instructions: _optString(e['instructions']),
      ));
    }
  }

  ProposedWorkout? workout;
  final rawWorkout = json['workout'];
  if (rawWorkout is Map<String, dynamic>) {
    final items = <ProposedItem>[];
    final rawItems = rawWorkout['items'];
    if (rawItems is List) {
      for (final it in rawItems) {
        if (it is! Map<String, dynamic>) continue;
        final ref = (it['exercise'] ?? it['exerciseId'] ?? it['name'])
            ?.toString()
            .trim();
        if (ref == null || ref.isEmpty) continue;
        final t = _fuzzyTargets(it);
        var minReps = t.minReps;
        var maxReps = t.maxReps;
        var minSeconds = t.minSeconds;
        var maxSeconds = t.maxSeconds;
        if (minReps != null && maxReps != null && minReps > maxReps) {
          (minReps, maxReps) = (maxReps, minReps);
        }
        if (minSeconds != null && maxSeconds != null && minSeconds > maxSeconds) {
          (minSeconds, maxSeconds) = (maxSeconds, minSeconds);
        }
        items.add(ProposedItem(
          exerciseRef: ref,
          sets: (_optInt(it['sets']) ?? 3).clamp(1, 20),
          minReps: minReps,
          maxReps: maxReps,
          minSeconds: minSeconds,
          maxSeconds: maxSeconds,
          restSeconds: (t.restSeconds ?? 60).clamp(0, 600),
          isFinisher: it['isFinisher'] == true,
          notes: _optString(it['notes']),
        ));
      }
    }
    final name = (rawWorkout['name'] as String?)?.trim();
    if (items.isNotEmpty) {
      workout = ProposedWorkout(
        name: (name == null || name.isEmpty) ? 'AI Workout' : name,
        focus: _optString(rawWorkout['focus']),
        items: items,
      );
    }
  }

  return AssistantProposal(newExercises: newExercises, workout: workout);
}

/// Maps sloppy model spellings onto [TrackingType]. Defaults to reps.
TrackingType parseTrackingType(String? raw) {
  final t = (raw ?? '').toLowerCase().replaceAll(RegExp(r'[\s_-]'), '');
  for (final v in TrackingType.values) {
    if (v.name.toLowerCase() == t) return v;
  }
  if (t.contains('stretch')) return TrackingType.stretch;
  if (t.contains('hold') || t.contains('isometric')) return TrackingType.hold;
  if (t.contains('side')) {
    return t.contains('rep')
        ? TrackingType.repsEachSide
        : TrackingType.timedEachSide;
  }
  if (t.contains('time') || t.contains('duration') || t.contains('second')) {
    return TrackingType.timed;
  }
  if (t.contains('max') || t.contains('amrap') || t.contains('burnout')) {
    return TrackingType.maxReps;
  }
  return TrackingType.reps;
}

class AppliedProposal {
  const AppliedProposal({this.workoutId, required this.createdExercises});

  final String? workoutId;
  final int createdExercises;
}

/// Canonical form for matching exercise names/refs: lowercase, parentheticals
/// removed ("push-up (chest only)" → push-up), non-alphanumerics dropped, and
/// a trailing plural "s" stripped ("Push-ups" == "Push-Up").
String canonicalExerciseName(String raw) {
  var s = raw.toLowerCase().replaceAll(RegExp(r'\([^)]*\)'), ' ');
  s = s.replaceAll(RegExp(r'[^a-z0-9]'), '');
  if (s.length > 3 && s.endsWith('s')) s = s.substring(0, s.length - 1);
  return s;
}

/// Resolves a model-written exercise reference against [pool] (library +
/// newly created). Tries exact id, then canonical-name matching: exact beats
/// prefix beats substring; ties go to the closest name length. Models write
/// refs like "push-up (chest/shoulders/triceps)" for an exercise declared as
/// "Push-Up" — strict equality would reject perfectly usable plans.
Exercise? resolveExerciseRef(String ref, List<Exercise> pool) {
  for (final e in pool) {
    if (e.id == ref.trim()) return e;
  }
  final canon = canonicalExerciseName(ref);
  if (canon.isEmpty) return null;

  Exercise? best;
  var bestScore = 0;
  var bestDiff = 1 << 30;
  for (final e in pool) {
    final name = canonicalExerciseName(e.name);
    if (name.isEmpty) continue;
    final int score;
    if (name == canon) {
      score = 3;
    } else if (name.startsWith(canon) || canon.startsWith(name)) {
      score = 2;
    } else if (name.contains(canon) || canon.contains(name)) {
      score = 1;
    } else {
      score = 0;
    }
    if (score == 0) continue;
    final diff = (name.length - canon.length).abs();
    if (score > bestScore || (score == bestScore && diff < bestDiff)) {
      best = e;
      bestScore = score;
      bestDiff = diff;
    }
  }
  return best;
}

/// Applies a proposal through the normal repository methods: creates the new
/// exercises (reusing same-name library entries instead of duplicating), then
/// the workout with its items. Throws [FormatException] when an item
/// references an unknown exercise.
Future<AppliedProposal> applyProposal(
  WorkoutRepository repository,
  List<Exercise> library,
  AssistantProposal proposal,
) async {
  final pool = [...library];

  // Create genuinely new exercises; a canonical name match in the library
  // means "already have it" (Push-Up vs Push-ups), so reuse instead.
  var created = 0;
  final pending = <Exercise>[];
  for (final e in proposal.newExercises) {
    final canon = canonicalExerciseName(e.name);
    final exists =
        pool.any((x) => canonicalExerciseName(x.name) == canon);
    if (!exists) pending.add(e);
  }

  String? workoutId;
  final workout = proposal.workout;

  // Resolve every item BEFORE writing anything (all-or-nothing), against the
  // library + the to-be-created exercises.
  final resolvePool = [...pool, ...pending];
  final resolved = <(ProposedItem, Exercise)>[];
  if (workout != null) {
    for (final item in workout.items) {
      final exercise = resolveExerciseRef(item.exerciseRef, resolvePool);
      if (exercise == null) {
        throw FormatException(
            'The plan references "${item.exerciseRef}", which is neither in '
            'the library nor in newExercises. Ask the model to fix the plan.');
      }
      resolved.add((item, exercise));
    }
  }

  for (final e in pending) {
    await repository.createExercise(e);
    created++;
  }

  if (workout != null) {

    workoutId = await repository.createWorkout(
        name: workout.name, focus: workout.focus);
    for (final (item, exercise) in resolved) {
      final timed = exercise.trackingType.isTimed;
      await repository.addWorkoutItem(
        workoutId,
        WorkoutItem(
          exercise: exercise,
          sets: item.sets,
          minReps: timed ? null : item.minReps,
          maxReps: timed ? null : item.maxReps,
          minSeconds: timed ? (item.minSeconds ?? item.minReps) : null,
          maxSeconds: timed ? (item.maxSeconds ?? item.maxReps) : null,
          restSeconds: item.restSeconds,
          isFinisher: item.isFinisher,
          notes: item.notes,
        ),
      );
    }
  }

  return AppliedProposal(workoutId: workoutId, createdExercises: created);
}

class _Targets {
  int? minReps, maxReps, minSeconds, maxSeconds, restSeconds;
}

/// Small local models routinely invent field names (`minRepsEachSide`,
/// `restSecondsPerSet`, `holdDurationSeconds`, `timedEachSide: 30`, plain
/// `reps: 12`…). Scan every numeric field and classify it by keywords so
/// those targets aren't silently dropped. Exact schema keys still win.
_Targets _fuzzyTargets(Map<String, dynamic> item) {
  final t = _Targets();
  int? repsSingle;
  int? secondsSingle;

  for (final entry in item.entries) {
    final value = _optInt(entry.value);
    if (value == null) continue;
    final key = entry.key.toLowerCase().replaceAll(RegExp(r'[\s_-]'), '');
    if (key == 'sets' || key == 'isfinisher') continue;

    if (key.contains('rest')) {
      t.restSeconds ??= value;
    } else if (key.contains('rep')) {
      if (key.contains('min')) {
        t.minReps ??= value;
      } else if (key.contains('max')) {
        t.maxReps ??= value;
      } else {
        repsSingle ??= value;
      }
    } else if (key.contains('sec') ||
        key.contains('duration') ||
        key.contains('hold') ||
        key.contains('time')) {
      if (key.contains('min') && !key.contains('minute')) {
        t.minSeconds ??= value;
      } else if (key.contains('max')) {
        t.maxSeconds ??= value;
      } else {
        secondsSingle ??= value;
      }
    }
  }

  // A single "reps"/"seconds"-style value is a fixed target.
  if (t.minReps == null && t.maxReps == null && repsSingle != null) {
    t.minReps = repsSingle;
    t.maxReps = repsSingle;
  }
  if (t.minSeconds == null && t.maxSeconds == null && secondsSingle != null) {
    t.minSeconds = secondsSingle;
    t.maxSeconds = secondsSingle;
  }
  return t;
}

String? _optString(dynamic v) {
  if (v is! String) return null;
  final t = v.trim();
  return t.isEmpty ? null : t;
}

int? _optInt(dynamic v) {
  if (v is int) return v;
  if (v is double) return v.round();
  if (v is String) return int.tryParse(v.trim());
  return null;
}
