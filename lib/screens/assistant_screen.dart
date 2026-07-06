import 'package:flutter/material.dart';

import '../data/assistant_actions.dart';
import '../data/llm_client.dart';
import '../data/workout_repository.dart';
import 'llm_settings_dialog.dart';
import 'workout_detail_screen.dart';

/// Chat with a local (or any OpenAI-compatible) model to design workouts and
/// exercises. When the model proposes a plan (a json block in its reply), a
/// preview card appears with a Save button — nothing is written until then.
class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key, required this.repository});

  final WorkoutRepository repository;

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _Bubble {
  _Bubble(this.role, this.text);

  final String role; // user | assistant
  String text;
  AssistantProposal? proposal;
  String? parseError;
  bool saved = false;
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<_Bubble> _chat = [];
  bool _busy = false;

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
      }
    });
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _busy) return;
    if (!LlmSettings.configured) {
      final ok = await showLlmSettingsDialog(context);
      if (!ok || !mounted) return;
      setState(() {}); // leave the setup state
    }

    _inputCtrl.clear();
    final reply = _Bubble('assistant', '');
    setState(() {
      _chat.add(_Bubble('user', text));
      _chat.add(reply);
      _busy = true;
    });
    _scrollToEnd();

    try {
      // Fresh library snapshot each turn so new exercises are known.
      final library = await widget.repository.watchExercises().first;
      final messages = [
        ChatMessage('system', buildSystemPrompt(library)),
        for (final b in _chat)
          if (b.text.isNotEmpty) ChatMessage(b.role, b.text),
      ];
      await for (final token in LlmClient.chatStream(messages)) {
        reply.text += token;
        setState(() {});
        _scrollToEnd();
      }
      try {
        reply.proposal = extractProposal(reply.text);
      } on FormatException catch (e) {
        reply.parseError = e.message;
      }
    } on LlmException catch (e) {
      reply.text = reply.text.isEmpty ? '⚠ ${e.message}' : reply.text;
      reply.parseError = reply.text.isEmpty ? null : e.message;
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _scrollToEnd();
      }
    }
  }

  Future<void> _saveProposal(_Bubble bubble) async {
    final proposal = bubble.proposal;
    if (proposal == null || bubble.saved) return;
    try {
      final library = await widget.repository.watchExercises().first;
      final applied =
          await applyProposal(widget.repository, library, proposal);
      if (!mounted) return;
      setState(() => bubble.saved = true);
      final workoutId = applied.workoutId;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text([
          if (applied.createdExercises > 0)
            '${applied.createdExercises} exercise'
                '${applied.createdExercises == 1 ? '' : 's'} added',
          if (workoutId != null) 'workout saved',
        ].join(' · ')),
        action: workoutId == null
            ? null
            : SnackBarAction(
                label: 'Open',
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => WorkoutDetailScreen(
                    repository: widget.repository,
                    workoutId: workoutId,
                  ),
                )),
              ),
      ));
    } on FormatException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  /// Reply text without the json block (the proposal card replaces it).
  String _displayText(_Bubble b) {
    if (b.proposal == null) return b.text;
    return b.text
        .replaceAll(RegExp(r'```(?:json)?\s*\{[\s\S]*?```'), '')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Assistant'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'AI endpoint',
            onPressed: () async {
              await showLlmSettingsDialog(context);
              if (mounted) setState(() {});
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _chat.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.smart_toy_outlined,
                              size: 48, color: theme.colorScheme.outline),
                          const SizedBox(height: 12),
                          Text(
                            LlmSettings.configured
                                ? 'Ask for a workout or a new exercise, e.g.\n'
                                    '"Make me a 25-minute core workout, no '
                                    'equipment" or "Add three shoulder '
                                    'exercises".'
                                : 'Connect a model first (⚙ top right).\n'
                                    'Easiest: Ollama on your PC — free and '
                                    'fully local.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.outline),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.all(12),
                    itemCount: _chat.length,
                    itemBuilder: (context, i) {
                      final b = _chat[i];
                      final isUser = b.role == 'user';
                      return Column(
                        crossAxisAlignment: isUser
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          if (_displayText(b).isNotEmpty || b.proposal == null)
                            Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.all(12),
                              constraints: BoxConstraints(
                                  maxWidth: MediaQuery.of(context).size.width *
                                      0.85),
                              decoration: BoxDecoration(
                                color: isUser
                                    ? theme.colorScheme.primaryContainer
                                    : theme.colorScheme.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                _displayText(b).isEmpty && !isUser
                                    ? (_busy && i == _chat.length - 1
                                        ? '…'
                                        : _displayText(b))
                                    : _displayText(b),
                                style: TextStyle(
                                  color: isUser
                                      ? theme.colorScheme.onPrimaryContainer
                                      : theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                          if (b.parseError != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                b.parseError!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.error),
                              ),
                            ),
                          if (b.proposal != null && !b.proposal!.isEmpty)
                            _ProposalCard(
                              proposal: b.proposal!,
                              saved: b.saved,
                              onSave: () => _saveProposal(b),
                            ),
                        ],
                      );
                    },
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputCtrl,
                      decoration: InputDecoration(
                        hintText: LlmSettings.configured
                            ? 'Describe the workout you want…'
                            : 'Set up the AI endpoint first (⚙)',
                        border: const OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      minLines: 1,
                      maxLines: 4,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    icon: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    onPressed: _busy ? null : _send,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProposalCard extends StatelessWidget {
  const _ProposalCard({
    required this.proposal,
    required this.saved,
    required this.onSave,
  });

  final AssistantProposal proposal;
  final bool saved;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final workout = proposal.workout;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (workout != null) ...[
              Text(workout.name,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              if (workout.focus != null)
                Text(workout.focus!,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline)),
              const SizedBox(height: 8),
              for (final item in workout.items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    '• ${item.exerciseRef} — ${item.sets}×'
                    '${_target(item)} · rest ${item.restSeconds}s'
                    '${item.isFinisher ? ' · finisher' : ''}',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
            ],
            if (proposal.newExercises.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final e in proposal.newExercises)
                    Chip(
                      label: Text('+ ${e.name}'),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: saved ? null : onSave,
                icon: Icon(saved ? Icons.check : Icons.save_outlined),
                label: Text(saved ? 'Saved' : 'Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _target(ProposedItem item) {
    if (item.minSeconds != null || item.maxSeconds != null) {
      final min = item.minSeconds, max = item.maxSeconds;
      return min != null && max != null && min != max
          ? '$min–$max sec'
          : '${max ?? min} sec';
    }
    if (item.minReps != null || item.maxReps != null) {
      final min = item.minReps, max = item.maxReps;
      return min != null && max != null && min != max
          ? '$min–$max reps'
          : '${max ?? min} reps';
    }
    return 'max reps';
  }
}
