import 'package:flutter/material.dart';

import '../data/sample_data.dart';
import 'workout_detail_screen.dart';

/// Lists every workout. Tapping one opens its detail/preview with a Start
/// button. Editing/creating workouts arrives in Phase 4.
class WorkoutsScreen extends StatelessWidget {
  const WorkoutsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Workouts')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: SampleData.workouts.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final workout = SampleData.workouts[i];
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
                  '${workout.exerciseCount} exercises · ~${workout.estimatedMinutes} min',
                  style: theme.textTheme.bodySmall,
                ),
              ),
              isThreeLine: true,
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => WorkoutDetailScreen(workout: workout),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
