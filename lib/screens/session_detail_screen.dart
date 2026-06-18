import 'package:flutter/material.dart';

import '../data/workout_repository.dart';
import '../models/workout_session.dart';

/// Shows one recorded session: when/how long it ran and the completed sets,
/// grouped by exercise. Allows deleting the session from history.
class SessionDetailScreen extends StatefulWidget {
  const SessionDetailScreen({
    super.key,
    required this.session,
    required this.repository,
  });

  final WorkoutSessionSummary session;
  final WorkoutRepository repository;

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  late final Future<List<CompletedSetRecord>> _sets =
      widget.repository.getSessionSets(widget.session.id);

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _dateTime(DateTime d) =>
      '${d.day} ${_months[d.month - 1]} ${d.year}, '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this session?'),
        content: const Text('This history entry will be permanently removed.'),
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
    if (confirmed != true) return;
    await widget.repository.deleteSession(widget.session.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = widget.session;
    final dur = session.duration;
    return Scaffold(
      appBar: AppBar(
        title: Text(session.workoutName),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete session',
            onPressed: _confirmDelete,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(_dateTime(session.startedAt),
              style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            [
              if (dur != null)
                dur.inMinutes >= 1
                    ? '${dur.inMinutes} min'
                    : '${dur.inSeconds}s',
              '${session.setCount} ${session.setCount == 1 ? 'set' : 'sets'}',
            ].join(' · '),
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.outline),
          ),
          const Divider(height: 32),
          FutureBuilder<List<CompletedSetRecord>>(
            future: _sets,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final groups = _groupByExercise(snapshot.data!);
              if (groups.isEmpty) {
                return Text('No sets were recorded for this session.',
                    style: TextStyle(color: theme.colorScheme.outline));
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final g in groups)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        child: Text('${g.sets.length}'),
                      ),
                      title: Text(g.name),
                      subtitle: Text(
                        '${g.sets.length} '
                        '${g.sets.length == 1 ? 'set' : 'sets'} · '
                        '${g.sets.first.doneLabel}',
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  /// Groups consecutive sets of the same exercise.
  List<_ExerciseGroup> _groupByExercise(List<CompletedSetRecord> sets) {
    final groups = <_ExerciseGroup>[];
    for (final s in sets) {
      if (groups.isNotEmpty && groups.last.exerciseId == s.exerciseId) {
        groups.last.sets.add(s);
      } else {
        groups.add(_ExerciseGroup(s.exerciseId, s.exerciseName)..sets.add(s));
      }
    }
    return groups;
  }
}

class _ExerciseGroup {
  _ExerciseGroup(this.exerciseId, this.name);

  final String exerciseId;
  final String name;
  final List<CompletedSetRecord> sets = [];
}
