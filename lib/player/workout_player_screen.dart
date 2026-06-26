import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../data/workout_prefs.dart';
import '../data/workout_repository.dart';
import '../models/exercise.dart';
import '../models/workout.dart';
import '../models/workout_session.dart';
import '../screens/workout_complete_screen.dart';
import '../widgets/exercise_media_view.dart';
import 'player_step.dart';

/// The guided workout experience: walks the user through every set with a Done
/// button for rep work, a countdown for timed work, and automatic rest timers
/// in between. On finish it records the session to history (Phase 6).
class WorkoutPlayerScreen extends StatefulWidget {
  const WorkoutPlayerScreen({
    super.key,
    required this.workout,
    required this.repository,
  });

  final Workout workout;
  final WorkoutRepository repository;

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

  // Completed sets recorded this session, kept in sync with _completedSets so
  // undo pops the matching record. Written to history on finish.
  final List<CompletedSetRecord> _done = [];

  // Countdown state, reused for both exercise timers and rest timers.
  Timer? _ticker;
  int _remaining = 0;
  bool _running = false;

  // Short safety window before Done / Finish-early can be pressed, so a quick
  // accidental tap doesn't skip a set. Counts 2 -> 0; 0 means the action is live.
  static const _armSeconds = 2;
  Timer? _armTimer;
  int _armRemaining = 0;

  final AudioPlayer _sfx = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _steps = expandWorkout(widget.workout);
    _startedAt = DateTime.now();
    // Keep the screen on during the workout (Phase 7), if enabled.
    if (WorkoutPrefs.keepAwake) WakelockPlus.enable();
    // Rep steps are completable on display, so arm them right away. Timed steps
    // arm when their countdown starts instead.
    if (_steps.isNotEmpty && !_step.isTimed) _arm();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _armTimer?.cancel();
    WakelockPlus.disable();
    _sfx.dispose();
    super.dispose();
  }

  // --- Sound + haptic cues (Phase 7), gated by user prefs -----------------

  Future<void> _playSound(String asset) async {
    if (!WorkoutPrefs.sound) return;
    try {
      await _sfx.stop();
      await _sfx.play(AssetSource(asset));
    } catch (_) {
      // Audio is a non-essential nicety; never let it break the workout.
    }
  }

  /// Countdown tick in the last few seconds of a timer/rest.
  void _tickCue() {
    _playSound('sounds/tick.wav');
    if (WorkoutPrefs.haptics) HapticFeedback.selectionClick();
  }

  /// A timer (exercise or rest) reaching zero.
  void _doneCue() {
    _playSound('sounds/done.wav');
    if (WorkoutPrefs.haptics) HapticFeedback.mediumImpact();
  }

  /// Light tap feedback for manual button presses.
  void _pressCue() {
    if (WorkoutPrefs.haptics) HapticFeedback.lightImpact();
  }

  /// The whole workout is finished.
  void _finishCue() {
    _playSound('sounds/done.wav');
    if (WorkoutPrefs.haptics) HapticFeedback.heavyImpact();
  }

  PlayerStep get _step => _steps[_index];

  /// True once the safety window has elapsed and the completion action is live.
  bool get _canComplete => _armRemaining == 0;

  /// True when there is a previous step (or rest) we can step back to.
  bool get _canGoBack => _phase == _Phase.rest || _running || _index > 0;

  /// Start the short safety window that briefly disables the completion action.
  void _arm() {
    _armTimer?.cancel();
    setState(() => _armRemaining = _armSeconds);
    _armTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_armRemaining <= 1) {
        _armTimer?.cancel();
        setState(() => _armRemaining = 0);
      } else {
        setState(() => _armRemaining--);
      }
    });
  }

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
        _doneCue();
        onDone();
      } else {
        setState(() => _remaining--);
        if (_remaining <= 3) _tickCue();
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
    if (_step.isSetEnd) {
      _completedSets++;
      _done.add(_recordFor(_step));
    }

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
    // Arm rep steps on display; timed steps arm when their countdown starts.
    if (!_step.isTimed) _arm();
  }

  /// Undo: step back to the previous exercise — used when Done / Finish-early
  /// was tapped by accident, or to restart a running timer.
  void _goBack() {
    _ticker?.cancel();
    _armTimer?.cancel();

    if (_phase == _Phase.rest) {
      // We just finished _step and are resting; return to re-do that set.
      if (_step.isSetEnd) {
        _completedSets = (_completedSets - 1).clamp(0, 1 << 30);
        if (_done.isNotEmpty) _done.removeLast();
      }
      setState(() {
        _phase = _Phase.exercise;
        _running = false;
        _remaining = 0;
        _armRemaining = 0;
      });
    } else if (_running) {
      // Mid-timer: cancel and re-show this step's Start button.
      setState(() {
        _running = false;
        _remaining = 0;
        _armRemaining = 0;
      });
      return;
    } else if (_index > 0) {
      // Return to the previous step to re-do it.
      setState(() {
        _index--;
        _phase = _Phase.exercise;
        _running = false;
        _remaining = 0;
        _armRemaining = 0;
      });
      if (_step.isSetEnd) {
        _completedSets = (_completedSets - 1).clamp(0, 1 << 30);
        if (_done.isNotEmpty) _done.removeLast();
      }
    } else {
      return;
    }

    if (!_step.isTimed) _arm();
  }

  void _skipRest() {
    _ticker?.cancel();
    _advance();
  }

  CompletedSetRecord _recordFor(PlayerStep step) {
    return CompletedSetRecord(
      exerciseId: step.exerciseId,
      exerciseName: step.exerciseName,
      setIndex: step.setNumber,
      repsDone: step.isTimed ? null : (step.targetMaxReps ?? step.targetMinReps),
      secondsDone: step.isTimed ? step.timerSeconds : null,
      completedAt: DateTime.now(),
    );
  }

  void _finish() {
    _ticker?.cancel();
    _finishCue();
    final completedAt = DateTime.now();
    final duration = completedAt.difference(_startedAt);
    // Persist this run to history. Fire-and-forget: the DB write outlives this
    // route, which we replace immediately below.
    unawaited(widget.repository.recordSession(
      workout: widget.workout,
      startedAt: _startedAt,
      completedAt: completedAt,
      sets: List.of(_done),
    ));
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
          actions: [
            IconButton(
              icon: const Icon(Icons.undo),
              tooltip: 'Go back a step',
              onPressed: _canGoBack ? _goBack : null,
            ),
          ],
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

          // Demo media (Phase 5), unless a timer is currently running.
          Expanded(
            child: Center(
              child: step.isTimed && (_running || _remaining > 0)
                  ? _TimerDial(
                      remaining: _remaining,
                      total: step.timerSeconds,
                    )
                  : (step.mediaPath != null && step.mediaType != null
                      ? _MediaWithTarget(
                          mediaPath: step.mediaPath!,
                          mediaType: step.mediaType!,
                          target: step.targetLabel,
                        )
                      : _MediaPlaceholder(target: step.targetLabel)),
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
        // Let the user finish early, but only after the safety window.
        return OutlinedButton.icon(
          onPressed: _canComplete
              ? () {
                  _pressCue();
                  _completeStep();
                }
              : null,
          icon: const Icon(Icons.check),
          style: _bigButtonStyle,
          label: Text(_canComplete ? 'Finish early' : 'Finish early ($_armRemaining)'),
        );
      }
      return FilledButton.icon(
        onPressed: () {
          _pressCue();
          _startCountdown(step.timerSeconds, _completeStep);
          _arm(); // gate "Finish early" for a moment after the timer starts
        },
        icon: const Icon(Icons.play_arrow),
        style: _bigButtonStyle,
        label: Text('Start ${step.sideLabel ?? 'timer'}'),
      );
    }

    return FilledButton.icon(
      onPressed: _canComplete
          ? () {
              _pressCue();
              _completeStep();
            }
          : null,
      icon: const Icon(Icons.check),
      style: _bigButtonStyle,
      label: Text(_canComplete ? 'Done' : 'Done ($_armRemaining)'),
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

/// Real demo media (image or video) above the target line.
class _MediaWithTarget extends StatelessWidget {
  const _MediaWithTarget({
    required this.mediaPath,
    required this.mediaType,
    required this.target,
  });

  final String mediaPath;
  final MediaType mediaType;
  final String target;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: ExerciseMediaView(
            key: ValueKey(mediaPath),
            path: mediaPath,
            type: mediaType,
            height: 220,
          ),
        ),
        const SizedBox(height: 24),
        Text('Target', style: theme.textTheme.labelLarge),
        Text(
          target,
          style: theme.textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

/// Placeholder shown when an exercise has no demo media attached.
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
