import 'package:flutter/material.dart';

import '../data/workout_repository.dart';
import '../models/workout.dart';
import 'generate_workout_screen.dart';
import 'workout_builder_screen.dart';
import 'workout_detail_screen.dart';
import 'workout_meta_dialog.dart';

/// Lists every workout reactively. Tapping one opens its detail/preview;
/// the FAB creates a new workout, and each card can be renamed or deleted.
class WorkoutsScreen extends StatefulWidget {
  const WorkoutsScreen({super.key, required this.repository});

  final WorkoutRepository repository;

  @override
  State<WorkoutsScreen> createState() => _WorkoutsScreenState();
}

class _WorkoutsScreenState extends State<WorkoutsScreen> {
  late final Stream<List<Workout>> _workouts =
      widget.repository.watchWorkouts();

  void _openDetail(String id) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => WorkoutDetailScreen(
        repository: widget.repository,
        workoutId: id,
      ),
    ));
  }

  Future<void> _create() async {
    final meta = await showWorkoutMetaDialog(context, title: 'New Workout');
    if (meta == null) return;
    final id = await widget.repository
        .createWorkout(name: meta.name, focus: meta.focus);
    if (!mounted) return;
    // Jump straight into the builder so the user can add exercises.
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => WorkoutBuilderScreen(
        repository: widget.repository,
        workoutId: id,
      ),
    ));
  }

  Future<void> _rename(Workout workout) async {
    final meta = await showWorkoutMetaDialog(
      context,
      title: 'Edit Workout',
      initialName: workout.name,
      initialFocus: workout.focus,
    );
    if (meta == null) return;
    await widget.repository.updateWorkoutMeta(
      id: workout.id,
      name: meta.name,
      focus: meta.focus,
    );
  }

  Future<void> _confirmDelete(Workout workout) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete workout?'),
        content: Text(
          '"${workout.name}" and its ${workout.exerciseCount} '
          '${workout.exerciseCount == 1 ? 'item' : 'items'} '
          'will be permanently deleted.',
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
      await widget.repository.deleteWorkout(workout.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Workouts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            tooltip: 'Generate workout',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) =>
                  GenerateWorkoutScreen(repository: widget.repository),
            )),
          ),
        ],
      ),
      body: StreamBuilder<List<Workout>>(
        stream: _workouts,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final workouts = snapshot.data!;
          if (workouts.isEmpty) {
            return const Center(
              child: Text('No workouts yet. Tap + to create one.'),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: workouts.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final workout = workouts[i];
              return Card(
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  title: Text(workout.name,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${workout.focus ?? ''}\n'
                      '${workout.exerciseCount} exercises · '
                      '~${workout.estimatedMinutes} min',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  isThreeLine: true,
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') _rename(workout);
                      if (value == 'delete') _confirmDelete(workout);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Rename')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                  onTap: () => _openDetail(workout.id),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _create,
        child: const Icon(Icons.add),
      ),
    );
  }
}
