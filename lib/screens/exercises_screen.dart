import 'package:flutter/material.dart';

import '../data/workout_repository.dart';
import '../models/exercise.dart';

/// The exercise + stretch library. Phase 1 is read-only; creating/editing and
/// attaching media arrive in Phases 3 and 5.
class ExercisesScreen extends StatelessWidget {
  const ExercisesScreen({super.key, required this.appData});

  final AppData appData;

  @override
  Widget build(BuildContext context) {
    final exercises = appData.exercises;
    return Scaffold(
      appBar: AppBar(title: const Text('Exercises')),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: exercises.length,
        itemBuilder: (context, i) => _ExerciseTile(exercise: exercises[i]),
      ),
    );
  }
}

class _ExerciseTile extends StatelessWidget {
  const _ExerciseTile({required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: exercise.isStretch
            ? theme.colorScheme.tertiaryContainer
            : theme.colorScheme.secondaryContainer,
        child: Icon(
          exercise.isStretch ? Icons.self_improvement : Icons.fitness_center,
          color: exercise.isStretch
              ? theme.colorScheme.onTertiaryContainer
              : theme.colorScheme.onSecondaryContainer,
        ),
      ),
      title: Text(exercise.name),
      subtitle: Text(
        [
          exercise.trackingType.label,
          if (exercise.muscleGroup != null) exercise.muscleGroup,
        ].join(' · '),
      ),
    );
  }
}
