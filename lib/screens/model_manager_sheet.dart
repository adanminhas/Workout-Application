import 'package:flutter/material.dart';

import '../data/llm_client.dart';
import '../data/local_llm.dart';

/// Bottom sheet for choosing where the assistant's brain runs and which model
/// it uses:
/// - **Server**: an Ollama server managed from the phone (list via /api/tags,
///   download via streamed /api/pull, tap to switch).
/// - **On-device**: models that run inside the app (flutter_gemma / LiteRT) —
///   downloaded once from the public litert-community catalog, then fully
///   offline.
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

  // Server state.
  Future<List<OllamaModel>?>? _models;
  OllamaPullProgress? _progress;
  String? _pullError;
  bool _pulling = false;

  // On-device state.
  final Map<String, bool> _installed = {};
  String? _downloading;
  int _downloadPct = 0;
  String? _localError;

  @override
  void initState() {
    super.initState();
    _refresh();
    _refreshInstalled();
  }

  @override
  void dispose() {
    _pullCtrl.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _models = OllamaAdmin.listModels();
    });
  }

  Future<void> _refreshInstalled() async {
    for (final m in localModelCatalog) {
      final ok = await LocalLlm.isInstalled(m);
      if (!mounted) return;
      setState(() => _installed[m.name] = ok);
    }
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

  Future<void> _downloadLocal(LocalModelInfo info) async {
    if (_downloading != null) return;
    setState(() {
      _downloading = info.name;
      _downloadPct = 0;
      _localError = null;
    });
    try {
      await for (final pct in LocalLlm.download(info)) {
        if (!mounted) return;
        setState(() => _downloadPct = pct);
      }
      if (!mounted) return;
      setState(() {
        _installed[info.name] = true;
        LlmSettings.localModelName = info.name;
      });
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${info.name} ready — runs on this device')));
    } on LlmException catch (e) {
      if (mounted) setState(() => _localError = e.message);
    } finally {
      if (mounted) setState(() => _downloading = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLocal = LlmSettings.isLocal;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'remote',
                      icon: Icon(Icons.dns_outlined),
                      label: Text('Server'),
                    ),
                    ButtonSegment(
                      value: 'local',
                      icon: Icon(Icons.smartphone),
                      label: Text('On-device'),
                    ),
                  ],
                  selected: {LlmSettings.backend},
                  onSelectionChanged: (s) =>
                      setState(() => LlmSettings.backend = s.first),
                ),
              ),
              const SizedBox(height: 16),
              if (!isLocal) ..._serverSection(theme) else ..._localSection(theme),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _serverSection(ThemeData theme) => [
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
                    onTap: () => setState(() => LlmSettings.model = m.name),
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
      ];

  List<Widget> _localSection(ThemeData theme) => [
        Text('Runs inside the app — no server needed',
            style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'One-time download (Wi-Fi recommended), then fully offline. '
          'Expect slower, simpler plans than a PC model.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.outline),
        ),
        const SizedBox(height: 8),
        for (final m in localModelCatalog)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              _installed[m.name] == true
                  ? (m.name == LlmSettings.localModelName
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off)
                  : Icons.cloud_download_outlined,
              color: m.name == LlmSettings.localModelName &&
                      _installed[m.name] == true
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline,
            ),
            title: Text('${m.name} · ${m.sizeLabel}'),
            subtitle: Text(
              _downloading == m.name
                  ? 'Downloading… $_downloadPct%'
                  : '${m.note}${_installed[m.name] == true ? ' · installed' : ''}',
            ),
            trailing: _downloading == m.name
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      value: _downloadPct > 0 ? _downloadPct / 100 : null,
                    ),
                  )
                : null,
            onTap: _downloading != null
                ? null
                : () {
                    if (_installed[m.name] == true) {
                      setState(() => LlmSettings.localModelName = m.name);
                    } else {
                      _downloadLocal(m);
                    }
                  },
          ),
        if (_localError != null) ...[
          const SizedBox(height: 8),
          Text(_localError!,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.error)),
        ],
      ];
}
