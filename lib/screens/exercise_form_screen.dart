import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/media_store.dart';
import '../models/exercise.dart';
import '../models/tracking_type.dart';
import '../widgets/exercise_media_view.dart';
import 'exercisedb_search_screen.dart';

/// Create or edit an exercise. Pops with the resulting [Exercise] on save,
/// or null if the user cancels.
class ExerciseFormScreen extends StatefulWidget {
  const ExerciseFormScreen({super.key, this.exercise});

  /// Null → create mode. Non-null → edit mode (preserves the existing id).
  final Exercise? exercise;

  @override
  State<ExerciseFormScreen> createState() => _ExerciseFormScreenState();
}

class _ExerciseFormScreenState extends State<ExerciseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _muscleCtrl;
  late final TextEditingController _cuesCtrl;
  late final TextEditingController _instructionsCtrl;
  late TrackingType _trackingType;
  String? _mediaPath;
  MediaType? _mediaType;
  bool _pickingMedia = false;

  bool get _isEditing => widget.exercise != null;

  @override
  void initState() {
    super.initState();
    final e = widget.exercise;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _muscleCtrl = TextEditingController(text: e?.muscleGroup ?? '');
    _cuesCtrl = TextEditingController(text: e?.formCues ?? '');
    _instructionsCtrl = TextEditingController(text: e?.instructions ?? '');
    _trackingType = e?.trackingType ?? TrackingType.reps;
    _mediaPath = e?.mediaPath;
    _mediaType = e?.mediaType;
  }

  Future<void> _pickMedia(MediaType type) async {
    final picker = ImagePicker();
    final XFile? file = type == MediaType.video
        ? await picker.pickVideo(source: ImageSource.gallery)
        : await picker.pickImage(source: ImageSource.gallery);
    if (file == null || !mounted) return;
    setState(() => _pickingMedia = true);
    try {
      final saved = await MediaStore.save(file.path, type: type);
      if (!mounted) return;
      setState(() {
        _mediaPath = saved;
        _mediaType = type;
      });
    } finally {
      if (mounted) setState(() => _pickingMedia = false);
    }
  }

  void _removeMedia() {
    setState(() {
      _mediaPath = null;
      _mediaType = null;
    });
  }

  /// Search ExerciseDB and download a demo GIF (opt-in online feature).
  /// A GIF is stored as [MediaType.image] — Image.file animates GIFs.
  Future<void> _findOnline() async {
    final pick = await Navigator.push<ExerciseDbPick>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ExerciseDbSearchScreen(initialQuery: _nameCtrl.text.trim()),
      ),
    );
    if (pick == null || !mounted) return;
    setState(() {
      _mediaPath = pick.path;
      _mediaType = MediaType.image;
      // Bonus: fill empty instructions from the catalog's step list.
      if (_instructionsCtrl.text.trim().isEmpty &&
          pick.instructions.isNotEmpty) {
        _instructionsCtrl.text = pick.instructions.join('\n');
      }
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _muscleCtrl.dispose();
    _cuesCtrl.dispose();
    _instructionsCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final id = _isEditing
        ? widget.exercise!.id
        : 'ex_${DateTime.now().millisecondsSinceEpoch}';
    final exercise = Exercise(
      id: id,
      name: _nameCtrl.text.trim(),
      trackingType: _trackingType,
      // A stretch is simply an exercise whose tracking type is "Stretch".
      isStretch: _trackingType == TrackingType.stretch,
      muscleGroup:
          _muscleCtrl.text.trim().isEmpty ? null : _muscleCtrl.text.trim(),
      formCues: _cuesCtrl.text.trim().isEmpty ? null : _cuesCtrl.text.trim(),
      instructions: _instructionsCtrl.text.trim().isEmpty
          ? null
          : _instructionsCtrl.text.trim(),
      mediaPath: _mediaPath,
      mediaType: _mediaType,
    );
    Navigator.pop(context, exercise);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Exercise' : 'New Exercise'),
        actions: [
          TextButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Name *',
                hintText: 'e.g. Push-ups',
              ),
              textCapitalization: TextCapitalization.words,
              autofocus: !_isEditing,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<TrackingType>(
              initialValue: _trackingType,
              decoration: const InputDecoration(labelText: 'Tracking type'),
              items: TrackingType.values
                  .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() => _trackingType = v);
              },
            ),
            const SizedBox(height: 24),
            Text('Demonstration (optional)',
                style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            if (_mediaPath != null && _mediaType != null) ...[
              ExerciseMediaView(
                key: ValueKey(_mediaPath),
                path: _mediaPath!,
                type: _mediaType!,
                height: 180,
              ),
              const SizedBox(height: 8),
            ],
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed:
                      _pickingMedia ? null : () => _pickMedia(MediaType.image),
                  icon: const Icon(Icons.image_outlined),
                  label: Text(_mediaType == MediaType.image
                      ? 'Replace image'
                      : 'Add image'),
                ),
                OutlinedButton.icon(
                  onPressed:
                      _pickingMedia ? null : () => _pickMedia(MediaType.video),
                  icon: const Icon(Icons.videocam_outlined),
                  label: Text(_mediaType == MediaType.video
                      ? 'Replace video'
                      : 'Add video'),
                ),
                OutlinedButton.icon(
                  onPressed: _pickingMedia ? null : _findOnline,
                  icon: const Icon(Icons.travel_explore),
                  label: const Text('Find online'),
                ),
                if (_mediaPath != null)
                  TextButton.icon(
                    onPressed: _pickingMedia ? null : _removeMedia,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Remove'),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _muscleCtrl,
              decoration: const InputDecoration(
                labelText: 'Muscle group (optional)',
                hintText: 'e.g. Abs / obliques',
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _cuesCtrl,
              decoration: const InputDecoration(
                labelText: 'Form cues (optional)',
                hintText: 'e.g. Keep lower back pressed down.',
              ),
              textCapitalization: TextCapitalization.sentences,
              maxLines: 3,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _instructionsCtrl,
              decoration: const InputDecoration(
                labelText: 'Instructions (optional)',
                hintText: 'Step-by-step guide…',
              ),
              textCapitalization: TextCapitalization.sentences,
              maxLines: 4,
            ),
          ],
        ),
      ),
    );
  }
}
