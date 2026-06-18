import 'package:flutter/material.dart';

import '../data/workout_repository.dart';
import '../models/workout_session.dart';
import '../widgets/month_calendar.dart';
import 'session_detail_screen.dart';

/// History tab: a month calendar marking days with completed workouts, and the
/// list of sessions for the selected day. Reads sessions reactively.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, required this.repository});

  final WorkoutRepository repository;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late final Stream<List<WorkoutSessionSummary>> _sessions =
      widget.repository.watchSessions();

  late DateTime _month;
  late DateTime _selectedDay;

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _selectedDay = MonthCalendar.dateOnly(now);
  }

  Future<void> _confirmClearAll(int count) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear all history?'),
        content: Text(
          'All $count recorded ${count == 1 ? 'session' : 'sessions'} will be '
          'permanently deleted. This cannot be undone.',
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
            child: const Text('Clear all'),
          ),
        ],
      ),
    );
    if (confirmed == true) await widget.repository.clearAllSessions();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<WorkoutSessionSummary>>(
      stream: _sessions,
      builder: (context, snapshot) {
        final sessions = snapshot.data ?? const <WorkoutSessionSummary>[];
        final marked = {
          for (final s in sessions) MonthCalendar.dateOnly(s.startedAt),
        };
        final daySessions = sessions
            .where(
                (s) => MonthCalendar.dateOnly(s.startedAt) == _selectedDay)
            .toList();

        return Scaffold(
          appBar: AppBar(
            title: const Text('History'),
            actions: [
              if (sessions.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.delete_sweep_outlined),
                  tooltip: 'Clear all history',
                  onPressed: () => _confirmClearAll(sessions.length),
                ),
            ],
          ),
          body: !snapshot.hasData
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    MonthCalendar(
                      month: _month,
                      selectedDay: _selectedDay,
                      markedDays: marked,
                      onSelectDay: (d) => setState(() => _selectedDay = d),
                      onChangeMonth: (delta) => setState(() {
                        _month = DateTime(_month.year, _month.month + delta);
                      }),
                    ),
                    const Divider(height: 32),
                    Text(
                      _dayHeader(_selectedDay),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (daySessions.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            'No workouts on this day.',
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.outline),
                          ),
                        ),
                      )
                    else
                      for (final s in daySessions)
                        _SessionTile(
                            session: s, repository: widget.repository),
                  ],
                ),
        );
      },
    );
  }

  String _dayHeader(DateTime d) =>
      '${_weekdays[d.weekday - 1]} ${d.day} ${_months[d.month - 1]} ${d.year}';
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session, required this.repository});

  final WorkoutSessionSummary session;
  final WorkoutRepository repository;

  String _time(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  String _subtitle() {
    final parts = <String>[_time(session.startedAt)];
    final dur = session.duration;
    if (dur != null) {
      parts.add(dur.inMinutes >= 1 ? '${dur.inMinutes} min' : '${dur.inSeconds}s');
    }
    parts.add('${session.setCount} '
        '${session.setCount == 1 ? 'set' : 'sets'}');
    return parts.join(' · ');
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this log?'),
        content: Text(
          'The "${session.workoutName}" session from ${_time(session.startedAt)} '
          'will be permanently removed.',
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
    if (confirmed == true) await repository.deleteSession(session.id);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.fitness_center)),
        title: Text(session.workoutName,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(_subtitle()),
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'delete') _confirmDelete(context);
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) =>
              SessionDetailScreen(session: session, repository: repository),
        )),
      ),
    );
  }
}
