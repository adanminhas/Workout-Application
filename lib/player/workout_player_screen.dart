import 'dart:async';

import 'package:flutter/material.dart';

import '../models/workout.dart';
import '../screens/workout_complete_screen.dart';
import 'player_step.dart';

/// The guided workout experience: walks the user through every set with a Done
/// button for rep work, a countdown for timed work, and automatic rest timers
/// in between. Phase 1 keeps all state local to this widget.
class WorkoutPlayerScreen extends StatefulWidget {
  const WorkoutPlayerScreen({super.key, required this.workout});

  final Workout workout;

  @override
  State<WorkoutPlayerScreen> createState() => _WorkoutPlayerScreenState();
}

enum _Phase { exercise, rest }

class _WorkoutPlayerScreenState extends State<WorkoutPlayerScreen> {
  late final List<PlayerStep> _steps;
  late final DateTime _startedAt;

  int _index = 0;
  int _completedSets = 0;
  _Phase _phase = _Phase.exercise;

  // Countdown state, reused for both exercise timers and rest timers.
  Timer? _ticker;
  int _remaining = 0;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _steps = expandWorkout(widget.workout);
    _startedAt = DateTime.now();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  PlayerStep get _step => _steps[_index];

  // --- Countdown helpers --------------------------------------------------

  void _startCountdown(int seconds, VoidCallback onDone) {
    _ticker?.cancel();
    setState(() {
      _remaining = seconds;
      _running = true;
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remaining <= 1) {
        _ticker?.cancel();
        setState(() {
          _remaining = 0;
          _running = false;
        });
        onDone();
      } else {
        setState(() => _remaining--);
      }
    });
  }

  void _adjustRest(int delta) {
    setState(() => _remaining = (_remaining + delta).clamp(0, 3599));
  }

  // --- Flow ---------------------------------------------------------------

  /// Called when the current exercise step is finished (Done pressed or its
  /// timer elapsed). Counts the set, then either rests or advances.
  void _completeStep() {
    if (_step.isSetEnd) _completedSets++;

    final rest = _step.restAfterSeconds;
    if (rest > 0) {
      setState(() => _phase = _Phase.rest);
      _startCountdown(rest, _advance);
    } else {
      _advance();
    }
  }

  void _advance() {
    _ticker?.cancel();
    if (_index >= _steps.length - 1) {
      _finish();
      return;
    }
    setState(() {
      _index++;
      _phase = _Phase.exercise;
      _running = false;
      _remaining = 0;
    });
  }

  void _skipRest() {
    _ticker?.cancel();
    _advance();
  }

  void _finish() {
    _ticker?.cancel();
    final duration = DateTime.now().difference(_startedAt);
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => WorkoutCompleteScreen(
        workoutName: widget.workout.name,
        duration: duration,
        completedSets: _completedSets,
      ),
    ));
  }

  Future<void> _confirmQuit() async {
    final quit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quit workout?'),
        content: const Text('Your progress in this session will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep going'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Quit'),
          ),
        ],
      ),
    );
    if (quit == true && mounted) Navigator.of(context).pop();
  }

  // --- UI -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final progress = _steps.isEmpty ? 0.0 : (_index + 1) / _steps.length;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmQuit();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.workout.name, overflow: TextOverflow.ellipsis),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _confirmQuit,
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: LinearProgressIndicator(value: progress),
          ),
        ),
        body: SafeArea(
          child: _phase == _Phase.rest ? _buildRest() : _buildExercise(),
        ),
      ),
    );
  }

  Widget _buildExercise() {
    final step = _step;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          if (step.isFinisher)
            const _Badge(label: 'FINISHER', color: Colors.deepOrange),
          Text(
            step.exerciseName,
            style: theme.textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(step.setLabel, style: theme.textTheme.titleMedium),
              if (step.sideLabel != null) ...[
                const SizedBox(width: 12),
                _Badge(
                  label: step.sideLabel!.toUpperCase(),
                  color: theme.colorScheme.primary,
                ),
              ],
            ],
          ),
          const SizedBox(height: 24),

          // Media placeholder (real video/GIF arrives in Phase 5).
          Expanded(
            child: Center(
              child: step.isTimed && (_running || _remaining > 0)
                  ? _TimerDial(
                      remaining: _remaining,
                      total: step.timerSeconds,
                    )
                  : _MediaPlaceholder(target: step.targetLabel),
            ),
          ),

          if (step.formCues != null) ...[
            const SizedBox(height: 8),
            Text(
              step.formCues!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
          ],
          const SizedBox(height: 24),
          _buildExerciseAction(step),
        ],
      ),
    );
  }

  Widget _buildExerciseAction(PlayerStep step) {
    if (step.isTimed) {
      if (_running) {
        return OutlinedButton.icon(
          onPressed: _completeStep, // let the user finish early
          icon: const Icon(Icons.check),
          style: _bigButtonStyle,
          label: const Text('Finish early'),
        );
      }
      return FilledButton.icon(
        onPressed: () => _startCountdown(step.timerSeconds, _completeStep),
        icon: const Icon(Icons.play_arrow),
        style: _bigButtonStyle,
        label: Text('Start ${step.sideLabel ?? 'timer'}'),
      );
    }

    return FilledButton.icon(
      onPressed: _completeStep,
      icon: const Icon(Icons.check),
      style: _bigButtonStyle,
      label: const Text('Done'),
    );
  }

  Widget _buildRest() {
    final theme = Theme.of(context);
    final next = _index < _steps.length - 1 ? _steps[_index + 1] : null;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Text('Rest', style: theme.textTheme.titleLarge),
          Expanded(
            child: Center(
              child: _TimerDial(
                remaining: _remaining,
                total: _step.restAfterSeconds,
                accent: theme.colorScheme.tertiary,
              ),
            ),
          ),
          if (next != null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.skip_next),
                title: const Text('Next up'),
                subtitle: Text(
                  '${next.exerciseName} · ${next.setLabel}'
                  '${next.sideLabel != null ? ' · ${next.sideLabel}' : ''}',
                ),
              ),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _adjustRest(-15),
                  child: const Text('−15s'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _adjustRest(15),
                  child: const Text('+15s'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _skipRest,
            icon: const Icon(Icons.fast_forward),
            style: _bigButtonStyle,
            label: const Text('Skip rest'),
          ),
        ],
      ),
    );
  }

  static final ButtonStyle _bigButtonStyle = FilledButton.styleFrom(
    minimumSize: const Size.fromHeight(56),
    textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
  );
}

/// Circular countdown with the remaining seconds in the centre.
class _TimerDial extends StatelessWidget {
  const _TimerDial({
    required this.remaining,
    required this.total,
    this.accent,
  });

  final int remaining;
  final int total;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = total == 0 ? 0.0 : remaining / total;
    return SizedBox(
      width: 220,
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: value,
              strokeWidth: 12,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor:
                  AlwaysStoppedAnimation(accent ?? theme.colorScheme.primary),
            ),
          ),
          Text(
            _format(remaining),
            style: theme.textTheme.displayMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  static String _format(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m == 0) return '$s';
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

/// Stand-in for the exercise media that arrives in Phase 5.
class _MediaPlaceholder extends StatelessWidget {
  const _MediaPlaceholder({required this.target});

  final String target;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 220,
          height: 160,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            Icons.fitness_center,
            size: 64,
            color: theme.colorScheme.outline,
          ),
        ),
        const SizedBox(height: 24),
        Text('Target', style: theme.textTheme.labelLarge),
        Text(
          target,
          style:
              theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
          letterSpacing: 1,
        ),
      ),
    );
  }
}
