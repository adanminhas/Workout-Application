import 'package:flutter/material.dart';

import '../data/exercisedb_api.dart';

/// What the search screen hands back after a successful download.
class ExerciseDbPick {
  const ExerciseDbPick({required this.path, this.instructions = const []});

  /// Local path of the downloaded GIF (already in app storage).
  final String path;
  final List<String> instructions;
}

/// Searches the ExerciseDB catalog and downloads a demo GIF for an exercise.
/// Pops with an [ExerciseDbPick], or null if cancelled. Prompts for the
/// RapidAPI key inline when none is stored yet.
class ExerciseDbSearchScreen extends StatefulWidget {
  const ExerciseDbSearchScreen({super.key, this.initialQuery = ''});

  final String initialQuery;

  @override
  State<ExerciseDbSearchScreen> createState() => _ExerciseDbSearchScreenState();
}

class _ExerciseDbSearchScreenState extends State<ExerciseDbSearchScreen> {
  late final TextEditingController _queryCtrl =
      TextEditingController(text: widget.initialQuery);
  final TextEditingController _keyCtrl = TextEditingController();

  Future<List<ExerciseDbResult>>? _results;
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    if (ExerciseDbApi.hasKey && widget.initialQuery.trim().isNotEmpty) {
      _search();
    }
  }

  @override
  void dispose() {
    _queryCtrl.dispose();
    _keyCtrl.dispose();
    super.dispose();
  }

  void _search() {
    if (!ExerciseDbApi.hasKey) return;
    setState(() => _results = ExerciseDbApi.search(_queryCtrl.text));
  }

  void _saveKey() {
    final key = _keyCtrl.text.trim();
    if (key.isEmpty) return;
    setState(() => ExerciseDbApi.apiKey = key);
    _search();
  }

  Future<void> _pick(ExerciseDbResult result) async {
    if (_downloading) return;
    setState(() => _downloading = true);
    try {
      final path = await ExerciseDbApi.downloadGif(result);
      if (!mounted) return;
      Navigator.pop(
          context, ExerciseDbPick(path: path, instructions: result.instructions));
    } on ExerciseDbException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Find Exercise Media')),
      body: Column(
        children: [
          if (!ExerciseDbApi.hasKey)
            Card(
              margin: const EdgeInsets.all(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ExerciseDB API key needed',
                        style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(
                      'Get a free key at rapidapi.com (search for '
                      '"ExerciseDB", subscribe to the free plan, copy your '
                      'X-RapidAPI-Key). It is stored only on this device.',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.outline),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _keyCtrl,
                      decoration: const InputDecoration(
                        labelText: 'X-RapidAPI-Key',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(
                        onPressed: _saveKey,
                        child: const Text('Save key'),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _queryCtrl,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Search exercises (e.g. crunch)',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.arrow_forward),
                    onPressed: _search,
                  ),
                ),
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _search(),
              ),
            ),
            Expanded(
              child: _results == null
                  ? Center(
                      child: Text(
                        'Search the ExerciseDB catalog\n(~1,300 exercises with '
                        'demo GIFs).',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: theme.colorScheme.outline),
                      ),
                    )
                  : FutureBuilder<List<ExerciseDbResult>>(
                      future: _results,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState !=
                            ConnectionState.done) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                '${snapshot.error}',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.error),
                              ),
                            ),
                          );
                        }
                        final results = snapshot.data!;
                        if (results.isEmpty) {
                          return const Center(
                              child: Text('No matches. Try a shorter term.'));
                        }
                        return ListView.builder(
                          itemCount: results.length,
                          itemBuilder: (context, i) =>
                              _ResultTile(result: results[i], onTap: _pick),
                        );
                      },
                    ),
            ),
            if (_downloading) const LinearProgressIndicator(),
          ],
        ],
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.result, required this.onTap});

  final ExerciseDbResult result;
  final ValueChanged<ExerciseDbResult> onTap;

  String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 56,
          height: 56,
          child: Image.network(
            result.gifUrl,
            headers: ExerciseDbApi.headersFor(result.gifUrl),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              color: theme.colorScheme.surfaceContainerHighest,
              child: Icon(Icons.fitness_center,
                  color: theme.colorScheme.outline),
            ),
          ),
        ),
      ),
      title: Text(_cap(result.name)),
      subtitle: Text(
        [
          if (result.target.isNotEmpty) _cap(result.target),
          if (result.bodyPart.isNotEmpty) result.bodyPart,
          if (result.equipment.isNotEmpty) result.equipment,
        ].join(' · '),
      ),
      trailing: const Icon(Icons.download_outlined),
      onTap: () => onTap(result),
    );
  }
}
