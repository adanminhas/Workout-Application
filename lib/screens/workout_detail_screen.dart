import 'package:flutter/material.dart';

import '../data/workout_repository.dart';
import '../models/workout.dart';
import '../player/workout_player_screen.dart';
import 'workout_builder_screen.dart';

/// Shows a workout's ordered items and a Start button that launches the player.
/// Reads the workout reactively so edits made in the builder show immediately.
class WorkoutDetailScreen extends StatefulWidget {
  const WorkoutDetailScreen({
    super.key,
    required this.repository,
    required this.workoutId,
  });

  final WorkoutRepository repository;
  final String workoutId;

  @override
  State<WorkoutDetailScreen> createState() => _WorkoutDetailScreenState();
}

class _WorkoutDetailScreenState extends State<WorkoutDetailScreen> {
  late final Stream<Workout?> _workout =
      widget.repository.watchWorkout(widget.workoutId);

  void _start(Workout workout) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => WorkoutPlayerScreen(workout: workout),
    ));
  }

  void _edit() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => WorkoutBuilderScreen(
        repository: widget.repository,
        workoutId: widget.workoutId,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StreamBuilder<Workout?>(
      stream: _workout,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final workout = snapshot.data;
        if (workout == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.of(context).maybePop();
          });
          return const Scaffold(body: SizedBox.shrink());
        }

        final canStart = workout.items.isNotEmpty;
        return Scaffold(
          appBar: AppBar(
            title: Text(workout.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit workout',
                onPressed: _edit,
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              if (workout.focus != null)
                Text(workout.focus!,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(color: theme.colorScheme.outline)),
              const SizedBox(height: 8),
              Text(
                '${workout.exerciseCount} exercises · ${workout.totalSets} sets '
                '· ~${workout.estimatedMinutes} min',
                style: theme.textTheme.bodyMedium,
              ),
              const Divider(height: 32),
              if (workout.items.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'This workout has no exercises yet. Tap the edit icon to '
                    'add some.',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.outline),
                  ),
                ),
              for (var i = 0; i < workout.items.length; i++)
                _ItemTile(index: i + 1, item: workout.items[i]),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: canStart ? () => _start(workout) : null,
            backgroundColor: canStart ? null : theme.disabledColor,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start Workout'),
          ),
        );
      },
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.index, required this.item});

  final int index;
  final WorkoutItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(child: Text('$index')),
      title: Row(
        children: [
          Flexible(child: Text(item.exercise.name)),
          if (item.isFinisher) ...[
            const SizedBox(width: 8),
            Icon(Icons.local_fire_department,
                size: 16, color: Colors.deepOrange),
          ],
          if (item.exercise.isStretch) ...[
            const SizedBox(width: 8),
            Icon(Icons.self_improvement,
                size: 16, color: theme.colorScheme.tertiary),
          ],
        ],
      ),
      subtitle: Text(item.summary),
      trailing: Text(
        'rest ${item.restSeconds}s',
        style: theme.textTheme.bodySmall
            ?.copyWith(color: theme.colorScheme.outline),
      ),
    );
  }
}
