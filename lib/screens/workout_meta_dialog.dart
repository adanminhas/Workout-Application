import 'package:flutter/material.dart';

/// Result of the workout name/focus dialog.
class WorkoutMeta {
  const WorkoutMeta({required this.name, this.focus});

  final String name;
  final String? focus;
}

/// Shows a dialog to enter/edit a workout's name and (optional) focus.
/// Returns the entered [WorkoutMeta], or null if cancelled.
Future<WorkoutMeta?> showWorkoutMetaDialog(
  BuildContext context, {
  required String title,
  String? initialName,
  String? initialFocus,
}) {
  final nameCtrl = TextEditingController(text: initialName ?? '');
  final focusCtrl = TextEditingController(text: initialFocus ?? '');
  final formKey = GlobalKey<FormState>();

  return showDialog<WorkoutMeta>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: nameCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Name *',
                hintText: 'e.g. Day A — Push',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: focusCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Focus (optional)',
                hintText: 'e.g. Chest & triceps',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!formKey.currentState!.validate()) return;
            Navigator.pop(
              ctx,
              WorkoutMeta(
                name: nameCtrl.text.trim(),
                focus: focusCtrl.text.trim().isEmpty
                    ? null
                    : focusCtrl.text.trim(),
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}
