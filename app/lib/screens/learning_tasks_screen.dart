import 'package:flutter/material.dart';
import '../models/learning_task.dart';
import '../services/api_service.dart';

const _pointTemplates = {
  'קצרה': 10,
  'בינונית': 25,
  'גדולה': 50,
};

class LearningTasksScreen extends StatefulWidget {
  final ApiService apiService;

  const LearningTasksScreen({super.key, required this.apiService});

  @override
  State<LearningTasksScreen> createState() => _LearningTasksScreenState();
}

class _LearningTasksScreenState extends State<LearningTasksScreen> {
  late Future<List<LearningTask>> _tasksFuture;

  @override
  void initState() {
    super.initState();
    _tasksFuture = widget.apiService.fetchLearningTasks();
  }

  void _reload() {
    setState(() {
      _tasksFuture = widget.apiService.fetchLearningTasks();
    });
  }

  Future<void> _openTaskDialog({LearningTask? existing}) async {
    final isEditing = existing != null;
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: existing?.name ?? '');
    final subjectController = TextEditingController(text: existing?.subject ?? '');
    final minAgeController = TextEditingController(text: existing?.minAge?.toString() ?? '');
    final maxAgeController = TextEditingController(text: existing?.maxAge?.toString() ?? '');
    final pointsController =
        TextEditingController(text: existing?.rewardPoints.toString() ?? '');
    bool isSaving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text(isEditing ? 'עריכת משימת לימוד' : 'הוספת משימת לימוד'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: 'שם המשימה'),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'חובה להזין שם';
                          }
                          return null;
                        },
                      ),
                      TextFormField(
                        controller: subjectController,
                        decoration: const InputDecoration(labelText: 'נושא (לא חובה)'),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: minAgeController,
                              decoration: const InputDecoration(labelText: 'גיל מינימלי'),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: maxAgeController,
                              decoration: const InputDecoration(labelText: 'גיל מקסימלי'),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: pointsController,
                        decoration: const InputDecoration(labelText: 'ניקוד'),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          final points = int.tryParse(value ?? '');
                          if (points == null || points <= 0) {
                            return 'יש להזין מספר חיובי';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Wrap(
                          spacing: 8,
                          children: _pointTemplates.entries.map((entry) {
                            return ActionChip(
                              label: Text('${entry.key} (${entry.value})'),
                              onPressed: () => pointsController.text = entry.value.toString(),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('ביטול'),
                ),
                FilledButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() => isSaving = true);
                          try {
                            if (isEditing) {
                              await widget.apiService.updateLearningTask(
                                taskId: existing.id,
                                name: nameController.text.trim(),
                                subject: subjectController.text.trim(),
                                minAge: int.tryParse(minAgeController.text),
                                maxAge: int.tryParse(maxAgeController.text),
                                rewardPoints: int.parse(pointsController.text),
                              );
                            } else {
                              await widget.apiService.addLearningTask(
                                name: nameController.text.trim(),
                                subject: subjectController.text.trim().isEmpty
                                    ? null
                                    : subjectController.text.trim(),
                                minAge: int.tryParse(minAgeController.text),
                                maxAge: int.tryParse(maxAgeController.text),
                                rewardPoints: int.parse(pointsController.text),
                              );
                            }
                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }
                            _reload();
                          } catch (e) {
                            setDialogState(() => isSaving = false);
                            if (dialogContext.mounted) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                SnackBar(content: Text('שגיאה: $e')),
                              );
                            }
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(isEditing ? 'שמירה' : 'הוספה'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteTask(LearningTask task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('מחיקת משימה'),
        content: Text('למחוק את "${task.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('ביטול'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('מחיקה'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await widget.apiService.deleteLearningTask(task.id);
      _reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('שגיאה: $e')));
      }
    }
  }

  String _ageRangeLabel(LearningTask task) {
    if (task.minAge == null && task.maxAge == null) return '';
    if (task.minAge != null && task.maxAge != null) {
      return ' · גילאים ${task.minAge}-${task.maxAge}';
    }
    if (task.minAge != null) return ' · מגיל ${task.minAge}';
    return ' · עד גיל ${task.maxAge}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('משימות לימוד')),
      body: FutureBuilder<List<LearningTask>>(
        future: _tasksFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('שגיאה בטעינה: ${snapshot.error}'));
          }

          final tasks = snapshot.data ?? [];
          if (tasks.isEmpty) {
            return const Center(child: Text('עדיין לא נוספו משימות. לחצו על + כדי להתחיל.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final task = tasks[index];
              final subjectLabel = task.subject == null ? '' : '${task.subject} · ';
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(task.name),
                  subtitle: Text('$subjectLabel${task.rewardPoints} נקודות${_ageRangeLabel(task)}'),
                  onTap: () => _openTaskDialog(existing: task),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'מחיקה',
                    onPressed: () => _deleteTask(task),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openTaskDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
