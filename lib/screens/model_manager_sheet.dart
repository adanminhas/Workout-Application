import 'package:flutter/material.dart';

import '../data/llm_client.dart';

/// Bottom sheet for managing models on the configured Ollama server from
/// inside the app: shows installed models (tap to make one active) and
/// downloads new ones with streamed progress. Hidden value: the user never
/// has to touch the PC — the phone drives the server.
Future<void> showModelManagerSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _ModelManagerSheet(),
  );
}

class _ModelManagerSheet extends StatefulWidget {
  const _ModelManagerSheet();

  @override
  State<_ModelManagerSheet> createState() => _ModelManagerSheetState();
}

class _ModelManagerSheetState extends State<_ModelManagerSheet> {
  final _pullCtrl = TextEditingController();

  Future<List<OllamaModel>?>? _models;
  OllamaPullProgress? _progress;
  String? _pullError;
  bool _pulling = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _pullCtrl.dispose();
    super.dispose();
  }

  void _refresh() {
    // Braces matter: an arrow closure would *return* the Future, which
    // setState asserts against.
    setState(() {
      _models = OllamaAdmin.listModels();
    });
  }

  Future<void> _pull() async {
    final name = _pullCtrl.text.trim();
    if (name.isEmpty || _pulling) return;
    setState(() {
      _pulling = true;
      _pullError = null;
      _progress = null;
    });
    try {
      await for (final p in OllamaAdmin.pull(name)) {
        if (!mounted) return;
        setState(() => _progress = p);
      }
      if (!mounted) return;
      // Success: make it the active model and refresh the list.
      setState(() {
        LlmSettings.model = name;
        _pullCtrl.clear();
      });
      _refresh();
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$name downloaded and selected')));
    } on LlmException catch (e) {
      if (mounted) setState(() => _pullError = e.message);
    } finally {
      if (mounted) {
        setState(() {
          _pulling = false;
          _progress = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Models on ${LlmSettings.serverRoot()}',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            FutureBuilder<List<OllamaModel>?>(
              future: _models,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final models = snapshot.data;
                if (models == null) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Server unreachable (or not an Ollama server). Model '
                      'management needs Ollama; chat still works with any '
                      'OpenAI-compatible server.',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.error),
                    ),
                  );
                }
                if (models.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text('No models installed yet — download one below.',
                        style: theme.textTheme.bodySmall),
                  );
                }
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final m in models)
                      ListTile(
                        leading: Icon(
                          m.name == LlmSettings.model
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          color: m.name == LlmSettings.model
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outline,
                        ),
                        title: Text(m.name),
                        subtitle: Text(m.sizeLabel),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        onTap: () =>
                            setState(() => LlmSettings.model = m.name),
                      ),
                  ],
                );
              },
            ),
            const Divider(height: 24),
            Text('Download a model', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              'Any name from ollama.com/library — e.g. qwen2.5:7b (better '
              'plans), llama3.2:3b, qwen2.5:3b (small/fast).',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _pullCtrl,
                    enabled: !_pulling,
                    decoration: const InputDecoration(
                      hintText: 'model:tag',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _pull(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _pulling ? null : _pull,
                  icon: const Icon(Icons.download),
                  label: const Text('Pull'),
                ),
              ],
            ),
            if (_pulling) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(value: _progress?.fraction),
              const SizedBox(height: 4),
              Text(
                _progress == null
                    ? 'Starting…'
                    : '${_progress!.status}'
                        '${_progress!.fraction != null ? ' · ${(_progress!.fraction! * 100).toStringAsFixed(0)}%' : ''}',
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (_pullError != null) ...[
              const SizedBox(height: 8),
              Text(_pullError!,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.error)),
            ],
          ],
        ),
      ),
    );
  }
}
