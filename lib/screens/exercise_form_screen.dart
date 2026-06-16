import 'package:flutter/material.dart';

import '../models/exercise.dart';
import '../models/tracking_type.dart';

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
    );
    Navigator.pop(context, exercise);
  }

  @override
  Widget build(BuildContext context) {
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
