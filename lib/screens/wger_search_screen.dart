import 'package:flutter/material.dart';

import '../data/wger_api.dart';

/// What the search screen hands back after a successful download.
class WgerPick {
  const WgerPick({required this.path, this.instructions = ''});

  /// Local path of the downloaded image (already in app storage).
  final String path;

  /// Plain-text description from the catalog; may be empty.
  final String instructions;
}

/// Searches the wger exercise catalog (open source, CC media, no key) and
/// downloads a demo image. Pops with a [WgerPick], or null if cancelled.
class WgerSearchScreen extends StatefulWidget {
  const WgerSearchScreen({super.key, this.initialQuery = ''});

  final String initialQuery;

  @override
  State<WgerSearchScreen> createState() => _WgerSearchScreenState();
}

class _WgerSearchScreenState extends State<WgerSearchScreen> {
  late final TextEditingController _queryCtrl =
      TextEditingController(text: widget.initialQuery);

  late Future<List<WgerResult>> _catalog = WgerApi.catalog();
  String _query = '';
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery.trim().toLowerCase();
  }

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  Future<void> _pick(WgerResult result) async {
    if (_downloading) return;
    setState(() => _downloading = true);
    try {
      final path = await WgerApi.downloadImage(result);
      if (!mounted) return;
      Navigator.pop(
          context, WgerPick(path: path, instructions: result.description));
    } on WgerException catch (e) {
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
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _queryCtrl,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Filter exercises (e.g. crunch)',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) =>
                  setState(() => _query = v.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<WgerResult>>(
              future: _catalog,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          'Loading the wger catalog…\n(once per session)',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.colorScheme.outline),
                        ),
                      ],
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: theme.colorScheme.error),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () => setState(
                                () => _catalog = WgerApi.catalog()),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                final all = snapshot.data!;
                final results = _query.isEmpty
                    ? all
                    : [
                        for (final r in all)
                          if (r.name.toLowerCase().contains(_query)) r,
                      ];
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
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.result, required this.onTap});

  final WgerResult result;
  final ValueChanged<WgerResult> onTap;

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
            result.thumbUrl ?? result.imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              color: theme.colorScheme.surfaceContainerHighest,
              child: Icon(Icons.fitness_center,
                  color: theme.colorScheme.outline),
            ),
          ),
        ),
      ),
      title: Text(result.name),
      subtitle: result.description.isEmpty
          ? null
          : Text(result.description,
              maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.download_outlined),
      onTap: () => onTap(result),
    );
  }
}
