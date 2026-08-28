import 'package:flutter/material.dart';
import '../models/child.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'child_detail_screen.dart';
import 'rewards_screen.dart';
import 'learning_tasks_screen.dart';
import 'settings_screen.dart';
import 'ai_content_screen.dart';

class ChildrenScreen extends StatefulWidget {
  final ApiService apiService;
  final AuthService authService;
  final VoidCallback onLoggedOut;

  const ChildrenScreen({
    super.key,
    required this.apiService,
    required this.authService,
    required this.onLoggedOut,
  });

  @override
  State<ChildrenScreen> createState() => _ChildrenScreenState();
}

class _ChildrenScreenState extends State<ChildrenScreen> {
  ApiService get _api => widget.apiService;
  late Future<List<Child>> _childrenFuture;

  @override
  void initState() {
    super.initState();
    _childrenFuture = _api.fetchChildren();
  }

  Future<void> _logout() async {
    await widget.authService.logout();
    widget.onLoggedOut();
  }

  void _reload() {
    setState(() {
      _childrenFuture = _api.fetchChildren();
    });
  }

  Future<void> _openAddChildDialog() async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final ageController = TextEditingController();
    final gradeController = TextEditingController();
    bool isSaving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('הוספת ילד'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'שם'),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'חובה להזין שם';
                        }
                        return null;
                      },
                    ),
                    TextFormField(
                      controller: ageController,
                      decoration: const InputDecoration(labelText: 'גיל'),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        final age = int.tryParse(value ?? '');
                        if (age == null || age < 0 || age > 18) {
                          return 'גיל צריך להיות מספר בין 0 ל-18';
                        }
                        return null;
                      },
                    ),
                    TextFormField(
                      controller: gradeController,
                      decoration: const InputDecoration(labelText: 'כיתה (לא חובה)'),
                    ),
                  ],
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
                            await _api.addChild(
                              name: nameController.text.trim(),
                              age: int.parse(ageController.text),
                              grade: gradeController.text.trim().isEmpty
                                  ? null
                                  : gradeController.text.trim(),
                            );
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
                      : const Text('הוספה'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('הילדים שלי'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => LearningTasksScreen(apiService: _api)),
              );
            },
            icon: const Icon(Icons.checklist),
            tooltip: 'משימות לימוד',
          ),
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => RewardsScreen(apiService: _api)),
              );
            },
            icon: const Icon(Icons.card_giftcard),
            tooltip: 'חנות פרסים',
          ),
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => AiContentScreen(apiService: _api)),
              );
            },
            icon: const Icon(Icons.auto_awesome),
            tooltip: 'יצירת שאלות עם AI',
          ),
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => SettingsScreen(authService: widget.authService)),
              );
            },
            icon: const Icon(Icons.settings),
            tooltip: 'הגדרות',
          ),
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            tooltip: 'התנתקות',
          ),
        ],
      ),
      body: FutureBuilder<List<Child>>(
        future: _childrenFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('שגיאה בטעינה: ${snapshot.error}'),
                  const SizedBox(height: 8),
                  FilledButton(onPressed: _reload, child: const Text('נסה שוב')),
                ],
              ),
            );
          }

          final children = snapshot.data ?? [];
          if (children.isEmpty) {
            return const Center(child: Text('עדיין לא נוספו ילדים. לחצו על + כדי להתחיל.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: children.length,
            itemBuilder: (context, index) {
              final child = children[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(child.name),
                  subtitle: Text(
                    (child.grade == null || child.grade!.isEmpty)
                        ? 'גיל ${child.age}'
                        : 'גיל ${child.age} · כיתה ${child.grade}',
                  ),
                  trailing: Chip(label: Text('${child.pointsBalance} נקודות')),
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ChildDetailScreen(apiService: _api, child: child),
                      ),
                    );
                    _reload();
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddChildDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
