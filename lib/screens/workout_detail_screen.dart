import 'package:flutter/material.dart';

import '../models/workout.dart';
import '../player/workout_player_screen.dart';

/// Shows a workout's ordered items and a Start button that launches the player.
class WorkoutDetailScreen extends StatelessWidget {
  const WorkoutDetailScreen({super.key, required this.workout});

  final Workout workout;

  void _start(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => WorkoutPlayerScreen(workout: workout),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(workout.name)),
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
          for (var i = 0; i < workout.items.length; i++)
            _ItemTile(index: i + 1, item: workout.items[i]),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _start(context),
        icon: const Icon(Icons.play_arrow),
        label: const Text('Start Workout'),
      ),
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
