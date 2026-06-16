import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/exercise.dart';
import '../models/tracking_type.dart';
import '../models/workout.dart';

/// Create or edit a [WorkoutItem] for a fixed [exercise]. The fields shown
/// adapt to the exercise's tracking type (reps vs. seconds vs. max-reps).
///
/// Pops with the resulting [WorkoutItem] on save (preserving the row id when
/// editing), or null if the user cancels.
class WorkoutItemFormScreen extends StatefulWidget {
  const WorkoutItemFormScreen({
    super.key,
    required this.exercise,
    this.item,
  });

  final Exercise exercise;

  /// Null → add mode. Non-null → edit mode (preserves [WorkoutItem.id]).
  final WorkoutItem? item;

  @override
  State<WorkoutItemFormScreen> createState() => _WorkoutItemFormScreenState();
}

class _WorkoutItemFormScreenState extends State<WorkoutItemFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _setsCtrl;
  late final TextEditingController _minCtrl;
  late final TextEditingController _maxCtrl;
  late final TextEditingController _restCtrl;
  late final TextEditingController _notesCtrl;
  late bool _isFinisher;

  bool get _isEditing => widget.item != null;
  TrackingType get _tracking => widget.exercise.trackingType;
  bool get _isTimed => _tracking.isTimed;
  bool get _hasTarget => _tracking != TrackingType.maxReps;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _setsCtrl = TextEditingController(text: (item?.sets ?? 3).toString());
    _minCtrl = TextEditingController(
        text: (_isTimed ? item?.minSeconds : item?.minReps)?.toString() ?? '');
    _maxCtrl = TextEditingController(
        text: (_isTimed ? item?.maxSeconds : item?.maxReps)?.toString() ?? '');
    _restCtrl = TextEditingController(text: (item?.restSeconds ?? 60).toString());
    _notesCtrl = TextEditingController(text: item?.notes ?? '');
    _isFinisher = item?.isFinisher ?? false;
  }

  @override
  void dispose() {
    _setsCtrl.dispose();
    _minCtrl.dispose();
    _maxCtrl.dispose();
    _restCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  int? _parseInt(TextEditingController c) {
    final t = c.text.trim();
    return t.isEmpty ? null : int.tryParse(t);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final min = _parseInt(_minCtrl);
    final max = _parseInt(_maxCtrl);
    final item = WorkoutItem(
      id: widget.item?.id,
      exercise: widget.exercise,
      sets: _parseInt(_setsCtrl) ?? 1,
      minReps: !_isTimed && _hasTarget ? min : null,
      maxReps: !_isTimed && _hasTarget ? max : null,
      minSeconds: _isTimed ? min : null,
      maxSeconds: _isTimed ? max : null,
      restSeconds: _parseInt(_restCtrl) ?? 0,
      isFinisher: _isFinisher,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    );
    Navigator.pop(context, item);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unit = _isTimed ? 'sec' : 'reps';
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Item' : 'Add Item'),
        actions: [
          TextButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: widget.exercise.isStretch
                    ? theme.colorScheme.tertiaryContainer
                    : theme.colorScheme.secondaryContainer,
                child: Icon(widget.exercise.isStretch
                    ? Icons.self_improvement
                    : Icons.fitness_center),
              ),
              title: Text(widget.exercise.name,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(_tracking.label),
            ),
            const Divider(height: 24),
            TextFormField(
              controller: _setsCtrl,
              decoration: const InputDecoration(labelText: 'Sets *'),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) {
                final n = int.tryParse((v ?? '').trim());
                return (n == null || n < 1) ? 'Enter 1 or more' : null;
              },
            ),
            if (_hasTarget) ...[
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _minCtrl,
                      decoration: InputDecoration(labelText: 'Min $unit'),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _maxCtrl,
                      decoration: InputDecoration(labelText: 'Max $unit'),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Leave both blank for no fixed target. '
                  'Set only Min for a single value.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
              ),
            ] else
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  'Max-reps item — no target; go as far as form holds.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
              ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _restCtrl,
              decoration:
                  const InputDecoration(labelText: 'Rest after each set (sec)'),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Finisher'),
              subtitle: const Text('Burnout set, shown with a flame badge'),
              value: _isFinisher,
              onChanged: (v) => setState(() => _isFinisher = v),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'e.g. slow tempo, pause at bottom',
              ),
              textCapitalization: TextCapitalization.sentences,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}
