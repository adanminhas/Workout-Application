import '../models/exercise.dart';
import '../models/tracking_type.dart';
import '../models/workout.dart';

/// Hardcoded Phase 1 data: an exercise library plus the rotating ab program
/// (Day A / B / C) and a reusable cooldown stretch routine.
///
/// In Phase 2 this is replaced by data loaded from the local SQLite database;
/// the same objects will be seeded from here.
class SampleData {
  SampleData._();

  // --- Exercise library ---------------------------------------------------

  static const crunches = Exercise(
    id: 'crunches',
    name: 'Crunches',
    trackingType: TrackingType.reps,
    muscleGroup: 'Upper abs',
    formCues: 'Curl the ribcage toward the hips. Keep the lower back grounded.',
  );

  static const bicycleCrunches = Exercise(
    id: 'bicycle_crunches',
    name: 'Bicycle Crunches',
    trackingType: TrackingType.reps,
    muscleGroup: 'Abs / obliques',
    formCues: 'Opposite elbow to knee. Move with control, not speed.',
  );

  static const heelTouches = Exercise(
    id: 'heel_touches',
    name: 'Heel Touches',
    trackingType: TrackingType.reps,
    muscleGroup: 'Obliques',
    formCues: 'Reach side to side, tapping each heel.',
  );

  static const tuckUps = Exercise(
    id: 'tuck_ups',
    name: 'Tuck-ups',
    trackingType: TrackingType.reps,
    muscleGroup: 'Lower abs',
    formCues: 'Draw knees and chest together, then extend long.',
  );

  static const lowerBodyHold = Exercise(
    id: 'lower_body_hold',
    name: 'Lower Body Hold',
    trackingType: TrackingType.hold,
    muscleGroup: 'Lower abs',
    formCues: 'Legs straight, heels low, lower back pressed down.',
  );

  static const sitUps = Exercise(
    id: 'sit_ups',
    name: 'Sit-ups',
    trackingType: TrackingType.maxReps,
    muscleGroup: 'Abs',
    formCues: 'Full controlled range. Stop when form breaks.',
  );

  static const russianTwists = Exercise(
    id: 'russian_twists',
    name: 'Russian Twists',
    trackingType: TrackingType.timed,
    muscleGroup: 'Obliques',
    formCues: 'Rotate from the trunk. Keep chest tall.',
  );

  static const windshieldWipers = Exercise(
    id: 'windshield_wipers',
    name: 'Windshield Wipers',
    trackingType: TrackingType.reps,
    muscleGroup: 'Obliques',
    formCues: 'Lower legs side to side under control.',
  );

  static const sidePlank = Exercise(
    id: 'side_plank',
    name: 'Side Plank',
    trackingType: TrackingType.timedEachSide,
    muscleGroup: 'Obliques / core',
    formCues: 'Stack the hips. Drive the bottom hip up.',
  );

  static const sideBridges = Exercise(
    id: 'side_bridges',
    name: 'Side Bridges',
    trackingType: TrackingType.repsEachSide,
    muscleGroup: 'Obliques',
    formCues: 'Lift and lower the hip with control.',
  );

  static const hangingLegRaises = Exercise(
    id: 'hanging_leg_raises',
    name: 'Hanging Leg Raises',
    trackingType: TrackingType.reps,
    muscleGroup: 'Lower abs',
    formCues: 'No swinging. Raise legs from the abs, not momentum.',
  );

  static const lSits = Exercise(
    id: 'l_sits',
    name: 'L-sits',
    trackingType: TrackingType.hold,
    muscleGroup: 'Core',
    formCues: 'Press the floor down, lift legs to an L.',
  );

  static const dragonFlags = Exercise(
    id: 'dragon_flags',
    name: 'Dragon Flags',
    trackingType: TrackingType.reps,
    muscleGroup: 'Full core',
    formCues: 'Keep the body rigid. Lower slowly.',
  );

  // --- Stretches ----------------------------------------------------------

  static const cobraStretch = Exercise(
    id: 'cobra_stretch',
    name: 'Cobra Stretch',
    trackingType: TrackingType.stretch,
    isStretch: true,
    muscleGroup: 'Spine / abs',
    formCues: 'Press chest up, relax the glutes, breathe.',
  );

  static const childsPose = Exercise(
    id: 'childs_pose',
    name: "Child's Pose",
    trackingType: TrackingType.stretch,
    isStretch: true,
    muscleGroup: 'Back / hips',
    formCues: 'Sink hips to heels, reach long, breathe into the back.',
  );

  static const hipFlexorStretch = Exercise(
    id: 'hip_flexor_stretch',
    name: 'Kneeling Hip Flexor Stretch',
    trackingType: TrackingType.stretch,
    isStretch: true,
    muscleGroup: 'Hip flexors',
    formCues: 'Tuck the pelvis, gently shift forward.',
  );

  static const seatedForwardFold = Exercise(
    id: 'seated_forward_fold',
    name: 'Seated Forward Fold',
    trackingType: TrackingType.stretch,
    isStretch: true,
    muscleGroup: 'Hamstrings / back',
    formCues: 'Hinge from the hips, soft knees are fine.',
  );

  static const spinalTwist = Exercise(
    id: 'spinal_twist',
    name: 'Spinal Twist',
    trackingType: TrackingType.stretch,
    isStretch: true,
    muscleGroup: 'Spine',
    formCues: 'Twist gently, keep both shoulders grounded.',
  );

  /// Everything in the library, in display order.
  static const List<Exercise> exercises = [
    crunches,
    bicycleCrunches,
    heelTouches,
    tuckUps,
    lowerBodyHold,
    sitUps,
    russianTwists,
    windshieldWipers,
    sidePlank,
    sideBridges,
    hangingLegRaises,
    lSits,
    dragonFlags,
    cobraStretch,
    childsPose,
    hipFlexorStretch,
    seatedForwardFold,
    spinalTwist,
  ];

  // --- Reusable cooldown stretch block ------------------------------------

  /// Cooldown stretches appended to each workout day.
  static const List<WorkoutItem> _stretchRoutine = [
    WorkoutItem(
      exercise: cobraStretch,
      sets: 2,
      minSeconds: 20,
      maxSeconds: 30,
      restSeconds: 10,
    ),
    WorkoutItem(
      exercise: childsPose,
      sets: 1,
      minSeconds: 30,
      maxSeconds: 45,
      restSeconds: 10,
    ),
    WorkoutItem(
      exercise: hipFlexorStretch,
      sets: 1,
      minSeconds: 30,
      maxSeconds: 30,
      restSeconds: 10,
    ),
    WorkoutItem(
      exercise: seatedForwardFold,
      sets: 1,
      minSeconds: 30,
      maxSeconds: 30,
      restSeconds: 10,
    ),
    WorkoutItem(
      exercise: spinalTwist,
      sets: 1,
      minSeconds: 20,
      maxSeconds: 30,
      restSeconds: 0,
    ),
  ];

  /// A standalone stretch-only workout.
  static const stretchWorkout = Workout(
    id: 'stretch_routine',
    name: 'Core-Saving Stretch Routine',
    focus: 'Cooldown & spinal decompression',
    items: _stretchRoutine,
  );

  // --- The rotating ab program --------------------------------------------

  static const dayA = Workout(
    id: 'day_a',
    name: 'Day A — Spine Flexion Focus',
    focus: 'Upper/lower abs through flexion',
    items: [
      WorkoutItem(
        exercise: crunches,
        sets: 3,
        minReps: 15,
        maxReps: 20,
        restSeconds: 60,
      ),
      WorkoutItem(
        exercise: bicycleCrunches,
        sets: 3,
        minReps: 20,
        maxReps: 20,
        restSeconds: 60,
      ),
      WorkoutItem(
        exercise: heelTouches,
        sets: 3,
        minReps: 20,
        maxReps: 20,
        restSeconds: 45,
      ),
      WorkoutItem(
        exercise: tuckUps,
        sets: 3,
        minReps: 12,
        maxReps: 15,
        restSeconds: 60,
      ),
      WorkoutItem(
        exercise: lowerBodyHold,
        sets: 3,
        minSeconds: 20,
        maxSeconds: 40,
        restSeconds: 60,
      ),
      WorkoutItem(
        exercise: sitUps,
        sets: 2,
        restSeconds: 60,
        isFinisher: true,
      ),
      ..._stretchRoutine,
    ],
  );

  static const dayB = Workout(
    id: 'day_b',
    name: 'Day B — Rotation + Obliques',
    focus: 'Rotational strength & obliques',
    items: [
      WorkoutItem(
        exercise: russianTwists,
        sets: 3,
        minSeconds: 30,
        maxSeconds: 45,
        restSeconds: 60,
      ),
      WorkoutItem(
        exercise: windshieldWipers,
        sets: 3,
        minReps: 8,
        maxReps: 12,
        restSeconds: 60,
      ),
      WorkoutItem(
        exercise: sidePlank,
        sets: 3,
        minSeconds: 30,
        maxSeconds: 45,
        restSeconds: 45,
      ),
      WorkoutItem(
        exercise: sideBridges,
        sets: 3,
        minReps: 12,
        maxReps: 12,
        restSeconds: 45,
      ),
      WorkoutItem(
        exercise: bicycleCrunches,
        sets: 2,
        minReps: 20,
        maxReps: 20,
        restSeconds: 60,
      ),
      ..._stretchRoutine,
    ],
  );

  static const dayC = Workout(
    id: 'day_c',
    name: 'Day C — Advanced Strength + Stability',
    focus: 'Advanced strength & stability',
    items: [
      WorkoutItem(
        exercise: hangingLegRaises,
        sets: 3,
        minReps: 10,
        maxReps: 15,
        restSeconds: 75,
      ),
      WorkoutItem(
        exercise: lSits,
        sets: 3,
        minSeconds: 15,
        maxSeconds: 30,
        restSeconds: 75,
      ),
      WorkoutItem(
        exercise: dragonFlags,
        sets: 3,
        minReps: 4,
        maxReps: 8,
        restSeconds: 90,
      ),
      WorkoutItem(
        exercise: lowerBodyHold,
        sets: 3,
        minSeconds: 30,
        maxSeconds: 45,
        restSeconds: 60,
      ),
      WorkoutItem(
        exercise: crunches,
        sets: 2,
        minReps: 15,
        maxReps: 15,
        restSeconds: 60,
        isFinisher: true,
      ),
      ..._stretchRoutine,
    ],
  );

  /// All selectable workouts, in display order.
  static const List<Workout> workouts = [dayA, dayB, dayC, stretchWorkout];
}
