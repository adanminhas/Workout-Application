import 'package:flutter/material.dart';

import '../data/workout_repository.dart';
import '../models/exercise.dart';

/// Pick an exercise from the library to add to a workout. Pops with the chosen
/// [Exercise], or null if cancelled. Reads the library reactively so newly
/// created exercises appear without a reload.
class ExercisePickerScreen extends StatefulWidget {
  const ExercisePickerScreen({super.key, required this.repository});

  final WorkoutRepository repository;

  @override
  State<ExercisePickerScreen> createState() => _ExercisePickerScreenState();
}

class _ExercisePickerScreenState extends State<ExercisePickerScreen> {
  late final Stream<List<Exercise>> _exercises =
      widget.repository.watchExercises();
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose Exercise')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search exercises',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Exercise>>(
              stream: _exercises,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final all = snapshot.data!;
                final exercises = _query.isEmpty
                    ? all
                    : all
                        .where((e) =>
                            e.name.toLowerCase().contains(_query) ||
                            (e.muscleGroup ?? '')
                                .toLowerCase()
                                .contains(_query))
                        .toList();
                if (exercises.isEmpty) {
                  return const Center(child: Text('No matching exercises.'));
                }
                return ListView.builder(
                  itemCount: exercises.length,
                  itemBuilder: (context, i) {
                    final e = exercises[i];
                    final theme = Theme.of(context);
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: e.isStretch
                            ? theme.colorScheme.tertiaryContainer
                            : theme.colorScheme.secondaryContainer,
                        child: Icon(e.isStretch
                            ? Icons.self_improvement
                            : Icons.fitness_center),
                      ),
                      title: Text(e.name),
                      subtitle: Text(
                        [
                          e.trackingType.label,
                          if (e.muscleGroup != null) e.muscleGroup,
                        ].join(' · '),
                      ),
                      onTap: () => Navigator.pop(context, e),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
