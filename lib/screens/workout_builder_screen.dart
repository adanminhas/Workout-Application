import 'package:flutter/material.dart';

import '../data/workout_repository.dart';
import '../models/exercise.dart';
import '../models/workout.dart';
import 'exercise_picker_screen.dart';
import 'workout_item_form_screen.dart';
import 'workout_meta_dialog.dart';

/// Edit a workout's items: add, edit per-item targets, reorder by dragging, and
/// remove. Reads the workout reactively so changes (and renames) show live.
class WorkoutBuilderScreen extends StatefulWidget {
  const WorkoutBuilderScreen({
    super.key,
    required this.repository,
    required this.workoutId,
  });

  final WorkoutRepository repository;
  final String workoutId;

  @override
  State<WorkoutBuilderScreen> createState() => _WorkoutBuilderScreenState();
}

class _WorkoutBuilderScreenState extends State<WorkoutBuilderScreen> {
  late final Stream<Workout?> _workout =
      widget.repository.watchWorkout(widget.workoutId);

  Future<void> _editMeta(Workout workout) async {
    final meta = await showWorkoutMetaDialog(
      context,
      title: 'Edit Workout',
      initialName: workout.name,
      initialFocus: workout.focus,
    );
    if (meta == null) return;
    await widget.repository.updateWorkoutMeta(
      id: workout.id,
      name: meta.name,
      focus: meta.focus,
    );
  }

  Future<void> _addItem() async {
    final exercise = await Navigator.push<Exercise>(
      context,
      MaterialPageRoute(
        builder: (_) => ExercisePickerScreen(repository: widget.repository),
      ),
    );
    if (exercise == null || !mounted) return;
    final item = await Navigator.push<WorkoutItem>(
      context,
      MaterialPageRoute(
        builder: (_) => WorkoutItemFormScreen(exercise: exercise),
      ),
    );
    if (item == null) return;
    await widget.repository.addWorkoutItem(widget.workoutId, item);
  }

  Future<void> _editItem(WorkoutItem item) async {
    final updated = await Navigator.push<WorkoutItem>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            WorkoutItemFormScreen(exercise: item.exercise, item: item),
      ),
    );
    if (updated == null || item.id == null) return;
    await widget.repository.updateWorkoutItem(item.id!, updated);
  }

  Future<void> _removeItem(WorkoutItem item) async {
    if (item.id == null) return;
    await widget.repository.removeWorkoutItem(item.id!);
  }

  // newIndex is already adjusted for the item removed at oldIndex
  // (ReorderableListView.onReorderItem semantics).
  Future<void> _onReorder(List<WorkoutItem> items, int oldIndex, int newIndex) {
    final reordered = [...items];
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);
    final ids = [for (final i in reordered) if (i.id != null) i.id!];
    return widget.repository.reorderWorkoutItems(ids);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StreamBuilder<Workout?>(
      stream: _workout,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final workout = snapshot.data;
        // The workout was deleted out from under us — leave the screen.
        if (workout == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.of(context).maybePop();
          });
          return const Scaffold(body: SizedBox.shrink());
        }

        final items = workout.items;
        return Scaffold(
          appBar: AppBar(
            title: Text(workout.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Rename / focus',
                onPressed: () => _editMeta(workout),
              ),
            ],
          ),
          body: items.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'No exercises yet.\nTap "Add exercise" to build this '
                      'workout.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(color: theme.colorScheme.outline),
                    ),
                  ),
                )
              : ReorderableListView.builder(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 96),
                  itemCount: items.length,
                  onReorderItem: (oldIndex, newIndex) =>
                      _onReorder(items, oldIndex, newIndex),
                  itemBuilder: (context, i) {
                    final item = items[i];
                    return _ItemCard(
                      key: ValueKey(item.id ?? i),
                      index: i,
                      item: item,
                      onEdit: () => _editItem(item),
                      onDelete: () => _removeItem(item),
                    );
                  },
                ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _addItem,
            icon: const Icon(Icons.add),
            label: const Text('Add exercise'),
          ),
        );
      },
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    super.key,
    required this.index,
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  final int index;
  final WorkoutItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        onTap: onEdit,
        leading: ReorderableDragStartListener(
          index: index,
          child: const Padding(
            padding: EdgeInsets.only(right: 4),
            child: Icon(Icons.drag_handle),
          ),
        ),
        title: Row(
          children: [
            Flexible(child: Text(item.exercise.name)),
            if (item.isFinisher) ...[
              const SizedBox(width: 8),
              const Icon(Icons.local_fire_department,
                  size: 16, color: Colors.deepOrange),
            ],
          ],
        ),
        subtitle: Text('${item.summary} · rest ${item.restSeconds}s'),
        trailing: IconButton(
          icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
          tooltip: 'Remove',
          onPressed: onDelete,
        ),
      ),
    );
  }
}
