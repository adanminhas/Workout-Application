import 'package:flutter/material.dart';

import '../data/workout_repository.dart';
import '../models/exercise.dart';
import 'exercise_form_screen.dart';

class ExercisesScreen extends StatefulWidget {
  const ExercisesScreen({super.key, required this.repository});

  final WorkoutRepository repository;

  @override
  State<ExercisesScreen> createState() => _ExercisesScreenState();
}

class _ExercisesScreenState extends State<ExercisesScreen> {
  // Created once so rebuilds don't re-subscribe (which would flash the spinner).
  late final Stream<List<Exercise>> _exercises =
      widget.repository.watchExercises();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Exercises')),
      body: StreamBuilder<List<Exercise>>(
        stream: _exercises,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final exercises = snapshot.data!;
          if (exercises.isEmpty) {
            return const Center(
              child: Text('No exercises yet. Tap + to add one.'),
            );
          }
          return ListView.builder(
            // Bottom inset so the last row's ⋮ menu clears the FAB.
            padding: const EdgeInsets.only(top: 8, bottom: 96),
            itemCount: exercises.length,
            itemBuilder: (context, i) => _ExerciseTile(
              exercise: exercises[i],
              onEdit: () => _openForm(context, exercises[i]),
              onDelete: () => _confirmDelete(context, exercises[i]),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(context, null),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _openForm(BuildContext context, Exercise? exercise) async {
    final result = await Navigator.push<Exercise>(
      context,
      MaterialPageRoute(
        builder: (_) => ExerciseFormScreen(exercise: exercise),
      ),
    );
    if (result == null || !context.mounted) return;
    if (exercise == null) {
      await widget.repository.createExercise(result);
    } else {
      await widget.repository.updateExercise(result);
    }
  }

  Future<void> _confirmDelete(BuildContext context, Exercise exercise) async {
    final usages = await widget.repository.countExerciseUsages(exercise.id);
    if (!context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete exercise?'),
        content: Text(
          usages == 0
              ? '"${exercise.name}" will be permanently deleted.'
              : '"${exercise.name}" is used in $usages workout '
                  '${usages == 1 ? 'item' : 'items'}. '
                  'It will be removed from those workouts too.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.repository.deleteExercise(exercise.id);
    }
  }
}

class _ExerciseTile extends StatelessWidget {
  const _ExerciseTile({
    required this.exercise,
    required this.onEdit,
    required this.onDelete,
  });

  final Exercise exercise;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

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
      onTap: onEdit,
      trailing: PopupMenuButton<String>(
        onSelected: (value) {
          if (value == 'edit') onEdit();
          if (value == 'delete') onDelete();
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'edit', child: Text('Edit')),
          PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
      ),
    );
  }
}
