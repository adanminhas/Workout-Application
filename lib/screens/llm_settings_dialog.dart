import 'package:flutter/material.dart';

import '../data/llm_client.dart';

/// Dialog for the AI assistant's endpoint (shared by Settings and the
/// assistant screen). Returns true when saved.
Future<bool> showLlmSettingsDialog(BuildContext context) async {
  final saved = await showDialog<bool>(
    context: context,
    builder: (_) => const _LlmSettingsDialog(),
  );
  return saved == true;
}

/// Owns its text controllers so they are disposed with the route (disposing
/// them right after showDialog returns crashes during the exit animation).
class _LlmSettingsDialog extends StatefulWidget {
  const _LlmSettingsDialog();

  @override
  State<_LlmSettingsDialog> createState() => _LlmSettingsDialogState();
}

class _LlmSettingsDialogState extends State<_LlmSettingsDialog> {
  late final TextEditingController _urlCtrl =
      TextEditingController(text: LlmSettings.baseUrl);
  late final TextEditingController _modelCtrl = TextEditingController(
      text: LlmSettings.model.isEmpty ? 'qwen2.5:3b' : LlmSettings.model);
  late final TextEditingController _keyCtrl =
      TextEditingController(text: LlmSettings.apiKey);

  @override
  void dispose() {
    _urlCtrl.dispose();
    _modelCtrl.dispose();
    _keyCtrl.dispose();
    super.dispose();
  }

  void _save() {
    LlmSettings.baseUrl = _urlCtrl.text;
    LlmSettings.model = _modelCtrl.text;
    LlmSettings.apiKey = _keyCtrl.text;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('AI endpoint'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Any OpenAI-compatible server. Easiest: install Ollama on your '
              'PC, run `ollama pull qwen2.5:3b`, and point this at the PC.\n'
              '• Phone → PC: http://<pc-ip>:11434\n'
              '• Emulator → this PC: http://10.0.2.2:11434',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _urlCtrl,
              autofocus: LlmSettings.baseUrl.isEmpty,
              decoration: const InputDecoration(
                labelText: 'Server URL',
                hintText: 'http://192.168.1.201:11434',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _modelCtrl,
              decoration: const InputDecoration(
                labelText: 'Model',
                hintText: 'qwen2.5:3b',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _keyCtrl,
              decoration: const InputDecoration(
                labelText: 'API key (optional)',
                hintText: 'Leave empty for Ollama',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
