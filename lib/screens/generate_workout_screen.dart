import 'package:flutter/material.dart';

import '../data/workout_generator.dart';
import '../data/workout_repository.dart';
import '../models/exercise.dart';
import 'workout_detail_screen.dart';

/// Builds a workout automatically from the exercise library — fully offline.
/// Pick a focus + length, preview the draft, regenerate until it looks good,
/// then save it as a normal (fully editable) workout.
class GenerateWorkoutScreen extends StatefulWidget {
  const GenerateWorkoutScreen({super.key, required this.repository});

  final WorkoutRepository repository;

  @override
  State<GenerateWorkoutScreen> createState() => _GenerateWorkoutScreenState();
}

class _GenerateWorkoutScreenState extends State<GenerateWorkoutScreen> {
  late final Stream<List<Exercise>> _exercises =
      widget.repository.watchExercises();

  final Set<String> _buckets = {};
  double _minutes = 20;
  bool _cooldown = true;
  GeneratedWorkout? _draft;
  bool _saving = false;

  void _generate(List<Exercise> library) {
    setState(() {
      _draft = WorkoutGenerator.generate(
        library,
        GeneratorOptions(
          buckets: _buckets,
          targetMinutes: _minutes.round(),
          includeCooldown: _cooldown,
        ),
      );
    });
  }

  Future<void> _save() async {
    final draft = _draft;
    if (draft == null || draft.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      final id = await widget.repository
          .createWorkout(name: draft.name, focus: draft.focus);
      for (final item in draft.items) {
        await widget.repository.addWorkoutItem(id, item);
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => WorkoutDetailScreen(
          repository: widget.repository,
          workoutId: id,
        ),
      ));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Generate Workout')),
      body: StreamBuilder<List<Exercise>>(
        stream: _exercises,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final library = snapshot.data!;
          _lastLibrary = library;
          // First frame with data: produce a draft right away.
          if (_draft == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _draft == null) _generate(library);
            });
          }
          final buckets = WorkoutGenerator.bucketsIn(library);
          final draft = _draft;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (buckets.length > 1)
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final b in buckets)
                            FilterChip(
                              label: Text(WorkoutGenerator.bucketLabel(b)),
                              selected: _buckets.contains(b),
                              onSelected: (on) {
                                setState(() =>
                                    on ? _buckets.add(b) : _buckets.remove(b));
                                _generate(library);
                              },
                            ),
                        ],
                      ),
                    Row(
                      children: [
                        Text('Length', style: theme.textTheme.bodyMedium),
                        Expanded(
                          child: Slider(
                            value: _minutes,
                            min: 10,
                            max: 45,
                            divisions: 7,
                            label: '${_minutes.round()} min',
                            onChanged: (v) => setState(() => _minutes = v),
                            onChangeEnd: (_) => _generate(library),
                          ),
                        ),
                        Text('${_minutes.round()} min',
                            style: theme.textTheme.bodyMedium),
                      ],
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text('Stretch cooldown at the end'),
                      value: _cooldown,
                      onChanged: (v) {
                        setState(() => _cooldown = v);
                        _generate(library);
                      },
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: draft == null
                    ? const SizedBox.shrink()
                    : draft.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Text(
                                'No matching exercises. Widen the focus or add '
                                'exercises to the library first.',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                    color: theme.colorScheme.outline),
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                            itemCount: draft.items.length + 1,
                            itemBuilder: (context, i) {
                              if (i == draft.items.length) {
                                return Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text(
                                    '≈ ${draft.estimatedMinutes} min · '
                                    '${draft.items.length} exercises',
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodyMedium
                                        ?.copyWith(
                                            color:
                                                theme.colorScheme.outline),
                                  ),
                                );
                              }
                              final item = draft.items[i];
                              return ListTile(
                                leading: CircleAvatar(child: Text('${i + 1}')),
                                title: Row(
                                  children: [
                                    Flexible(child: Text(item.exercise.name)),
                                    if (item.isFinisher) ...[
                                      const SizedBox(width: 8),
                                      const Icon(Icons.local_fire_department,
                                          size: 16, color: Colors.deepOrange),
                                    ],
                                    if (item.exercise.isStretch) ...[
                                      const SizedBox(width: 8),
                                      Icon(Icons.self_improvement,
                                          size: 16,
                                          color: theme.colorScheme.tertiary),
                                    ],
                                  ],
                                ),
                                subtitle: Text(
                                    '${item.summary} · rest ${item.restSeconds}s'),
                              );
                            },
                          ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _lastLibrary == null
                      ? null
                      : () => _generate(_lastLibrary!),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Regenerate'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed:
                      (_draft?.isEmpty ?? true) || _saving ? null : _save,
                  icon: const Icon(Icons.check),
                  label: Text(_saving ? 'Saving…' : 'Save workout'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Latest stream value, captured in build, so the bottom-bar Regenerate
  // button (outside the StreamBuilder) can re-run the generator.
  List<Exercise>? _lastLibrary;
}
