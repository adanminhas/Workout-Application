import 'package:flutter/material.dart';

import '../data/sample_data.dart';
import '../models/workout.dart';
import '../player/workout_player_screen.dart';
import 'workout_detail_screen.dart';

/// Home tab: surfaces today's workout from the A → B → C rotation and a weekly
/// plan. Phase 1 picks the day by rotating on the day-of-year so it changes
/// over time without any scheduling UI.
class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  Workout get _todaysWorkout {
    final rotation = [SampleData.dayA, SampleData.dayB, SampleData.dayC];
    final dayOfYear =
        DateTime.now().difference(DateTime(DateTime.now().year)).inDays;
    return rotation[dayOfYear % rotation.length];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final workout = _todaysWorkout;

    return Scaffold(
      appBar: AppBar(title: const Text('Today')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 0,
            color: theme.colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Today's workout",
                      style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer)),
                  const SizedBox(height: 8),
                  Text(
                    workout.name,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (workout.focus != null) ...[
                    const SizedBox(height: 4),
                    Text(workout.focus!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer)),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    '${workout.exerciseCount} exercises · ~${workout.estimatedMinutes} min',
                    style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      FilledButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                WorkoutPlayerScreen(workout: workout),
                          ),
                        ),
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Start Workout'),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                WorkoutDetailScreen(workout: workout),
                          ),
                        ),
                        child: const Text('Preview'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('Weekly plan', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          const _PlanRow(day: 'Mon', label: 'Day A — Spine Flexion'),
          const _PlanRow(day: 'Wed', label: 'Day B — Rotation + Obliques'),
          const _PlanRow(day: 'Fri', label: 'Day C — Advanced Strength'),
          const _PlanRow(day: 'Sat', label: 'Light A / Stretch (optional)'),
        ],
      ),
    );
  }
}

class _PlanRow extends StatelessWidget {
  const _PlanRow({required this.day, required this.label});

  final String day;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: SizedBox(
        width: 44,
        child: Text(day,
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      title: Text(label),
    );
  }
}
