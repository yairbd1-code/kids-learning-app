import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/child.dart';
import '../models/points_transaction.dart';
import '../models/reward.dart';
import '../models/redemption.dart';
import '../models/learning_task.dart';
import '../services/api_service.dart';
import 'practice_pin_screen.dart';
import 'subject_progress_screen.dart';
import 'curriculum_notes_screen.dart';

class ChildDetailScreen extends StatefulWidget {
  final ApiService apiService;
  final Child child;

  const ChildDetailScreen({super.key, required this.apiService, required this.child});

  @override
  State<ChildDetailScreen> createState() => _ChildDetailScreenState();
}

class _ChildDetailScreenState extends State<ChildDetailScreen> {
  late Child _child;
  late int _balance;
  late Future<List<PointsTransaction>> _transactionsFuture;
  int _pendingRequestsCount = 0;

  @override
  void initState() {
    super.initState();
    _child = widget.child;
    _balance = _child.pointsBalance;
    _transactionsFuture = widget.apiService.fetchTransactions(_child.id);
    _loadPendingCount();
  }

  void _reload() {
    setState(() {
      _transactionsFuture = widget.apiService.fetchTransactions(_child.id);
    });
    _loadPendingCount();
  }

  Future<void> _loadPendingCount() async {
    try {
      final redemptions = await widget.apiService.fetchRedemptions(_child.id);
      if (!mounted) return;
      setState(() {
        _pendingRequestsCount = redemptions.where((r) => r.status == 'PENDING').length;
      });
    } catch (_) {
      // לא קריטי - רק תג ספירה, לא מציגים שגיאה על זה
    }
  }

  Future<void> _openPendingRequestsDialog() async {
    List<Redemption> redemptions;
    try {
      redemptions = await widget.apiService.fetchRedemptions(_child.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('שגיאה: $e')));
      }
      return;
    }
    final pending = redemptions.where((r) => r.status == 'PENDING').toList();

    if (!mounted) return;
    if (pending.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('אין כרגע בקשות ממתינות')),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> respond(Redemption r, bool approve) async {
              try {
                final newBalance = await widget.apiService.setRedemptionApproval(
                  childId: _child.id,
                  redemptionId: r.id,
                  approve: approve,
                );
                setDialogState(() => pending.remove(r));
                if (newBalance != null && mounted) {
                  setState(() => _balance = newBalance);
                }
                _reload();
                if (pending.isEmpty && dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              } catch (e) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text('שגיאה: $e')),
                  );
                }
              }
            }

            return AlertDialog(
              title: const Text('בקשות ממתינות'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: pending.length,
                  itemBuilder: (context, index) {
                    final r = pending[index];
                    return ListTile(
                      title: Text(r.rewardName),
                      subtitle: Text('${r.pointsSpent} נקודות'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.red),
                            tooltip: 'דחייה',
                            onPressed: () => respond(r, false),
                          ),
                          IconButton(
                            icon: const Icon(Icons.check, color: Colors.green),
                            tooltip: 'אישור',
                            onPressed: () => respond(r, true),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('סגירה'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openAddTransactionDialog() async {
    final formKey = GlobalKey<FormState>();
    final amountController = TextEditingController();
    final reasonController = TextEditingController();
    bool isCredit = true;
    bool isSaving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('עדכון נקודות'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: true, label: Text('זיכוי (+)')),
                        ButtonSegment(value: false, label: Text('חיוב (-)')),
                      ],
                      selected: {isCredit},
                      onSelectionChanged: (selection) =>
                          setDialogState(() => isCredit = selection.first),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: amountController,
                      decoration: const InputDecoration(labelText: 'כמות נקודות'),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        final amount = int.tryParse(value ?? '');
                        if (amount == null || amount <= 0) {
                          return 'יש להזין מספר חיובי';
                        }
                        return null;
                      },
                    ),
                    TextFormField(
                      controller: reasonController,
                      decoration: const InputDecoration(labelText: 'סיבה'),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'חובה להזין סיבה';
                        }
                        return null;
                      },
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
                            final rawAmount = int.parse(amountController.text);
                            final newBalance = await widget.apiService.addTransaction(
                              childId: _child.id,
                              amount: isCredit ? rawAmount : -rawAmount,
                              reason: reasonController.text.trim(),
                            );
                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }
                            setState(() => _balance = newBalance);
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
                      : const Text('שמירה'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openRedeemRewardDialog() async {
    List<Reward> rewards;
    try {
      rewards = await widget.apiService.fetchRewards();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('שגיאה: $e')));
      }
      return;
    }

    if (!mounted) return;

    if (rewards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('עדיין אין פרסים בחנות. אפשר להוסיף מ"חנות פרסים".')),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        bool isRedeeming = false;
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('מימוש פרס'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: rewards.length,
                  itemBuilder: (context, index) {
                    final reward = rewards[index];
                    final canAfford = reward.costPoints <= _balance;
                    return ListTile(
                      title: Text(reward.name),
                      subtitle: Text('${reward.costPoints} נקודות'),
                      trailing: FilledButton(
                        onPressed: (!canAfford || isRedeeming)
                            ? null
                            : () async {
                                setDialogState(() => isRedeeming = true);
                                try {
                                  final newBalance = await widget.apiService.redeemReward(
                                    childId: _child.id,
                                    rewardId: reward.id,
                                  );
                                  if (dialogContext.mounted) {
                                    Navigator.of(dialogContext).pop();
                                  }
                                  setState(() => _balance = newBalance);
                                  _reload();
                                } catch (e) {
                                  setDialogState(() => isRedeeming = false);
                                  if (dialogContext.mounted) {
                                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                                      SnackBar(content: Text('שגיאה: $e')),
                                    );
                                  }
                                }
                              },
                        child: const Text('מימוש'),
                      ),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isRedeeming ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('סגירה'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openCompleteTaskDialog() async {
    List<LearningTask> tasks;
    try {
      tasks = await widget.apiService.fetchLearningTasks();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('שגיאה: $e')));
      }
      return;
    }

    if (!mounted) return;

    if (tasks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('עדיין אין משימות. אפשר להוסיף מ"משימות לימוד".')),
      );
      return;
    }

    // משימות שמתאימות לגיל הילד קודם, השאר אחריהן.
    final sortedTasks = [...tasks]..sort((a, b) {
        final aSuits = a.suitsAge(_child.age) ? 0 : 1;
        final bSuits = b.suitsAge(_child.age) ? 0 : 1;
        return aSuits.compareTo(bSuits);
      });

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        bool isCompleting = false;
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('סימון משימה כהושלמה'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: sortedTasks.length,
                  itemBuilder: (context, index) {
                    final task = sortedTasks[index];
                    final subjectLabel = task.subject == null ? '' : '${task.subject} · ';
                    final suits = task.suitsAge(_child.age);
                    return ListTile(
                      title: Text(task.name),
                      subtitle: Text(
                        '$subjectLabel${task.rewardPoints} נקודות'
                        '${suits ? '' : ' · לא מותאם לגיל הילד'}',
                      ),
                      trailing: FilledButton(
                        onPressed: isCompleting
                            ? null
                            : () async {
                                setDialogState(() => isCompleting = true);
                                try {
                                  final newBalance = await widget.apiService.completeTask(
                                    childId: _child.id,
                                    taskId: task.id,
                                  );
                                  if (dialogContext.mounted) {
                                    Navigator.of(dialogContext).pop();
                                  }
                                  setState(() => _balance = newBalance);
                                  _reload();
                                } catch (e) {
                                  setDialogState(() => isCompleting = false);
                                  if (dialogContext.mounted) {
                                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                                      SnackBar(content: Text('שגיאה: $e')),
                                    );
                                  }
                                }
                              },
                        child: const Text('בוצע'),
                      ),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isCompleting ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('סגירה'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openEditChildDialog() async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: _child.name);
    final ageController = TextEditingController(text: _child.age.toString());
    final gradeController = TextEditingController(text: _child.grade ?? '');
    bool isSaving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('עריכת פרטי ילד'),
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
                            final updated = await widget.apiService.updateChild(
                              childId: _child.id,
                              name: nameController.text.trim(),
                              age: int.parse(ageController.text),
                              grade: gradeController.text.trim().isEmpty
                                  ? ''
                                  : gradeController.text.trim(),
                            );
                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }
                            setState(() => _child = updated);
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
                      : const Text('שמירה'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<bool> _openSetPinDialog() async {
    final formKey = GlobalKey<FormState>();
    final pinController = TextEditingController();
    bool isSaving = false;
    bool success = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('הגדרת קוד PIN לתרגול'),
              content: Form(
                key: formKey,
                child: TextFormField(
                  controller: pinController,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  decoration: const InputDecoration(labelText: 'קוד בן 4 ספרות'),
                  validator: (value) {
                    if (value == null || value.length != 4) {
                      return 'יש להזין קוד בן 4 ספרות בדיוק';
                    }
                    return null;
                  },
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
                            await widget.apiService.setChildPin(
                              childId: _child.id,
                              pin: pinController.text,
                            );
                            success = true;
                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }
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
                      : const Text('שמירה'),
                ),
              ],
            );
          },
        );
      },
    );

    if (success) {
      setState(() => _child = Child(
            id: _child.id,
            name: _child.name,
            age: _child.age,
            grade: _child.grade,
            pointsBalance: _child.pointsBalance,
            hasPin: true,
            disabledSubjects: _child.disabledSubjects,
            subjectWeights: _child.subjectWeights,
          ));
    }
    return success;
  }

  Future<void> _startPractice() async {
    if (!_child.hasPin) {
      final wasSet = await _openSetPinDialog();
      if (!wasSet || !mounted) return;
    }

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PracticePinScreen(apiService: widget.apiService, child: _child),
      ),
    );
    if (mounted) _reload();
  }

  void _openSubjectProgress() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            SubjectProgressScreen(apiService: widget.apiService, child: _child),
      ),
    );
  }

  void _openCurriculumNotes() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            CurriculumNotesScreen(apiService: widget.apiService, child: _child),
      ),
    );
  }

  Future<void> _confirmDeleteChild() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('מחיקת ילד'),
        content: Text('למחוק את "${_child.name}"? כל היסטוריית הנקודות שלו תימחק לצמיתות.'),
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
      await widget.apiService.deleteChild(_child.id);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('שגיאה: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_child.name),
        actions: [
          IconButton(
            onPressed: _startPractice,
            icon: const Icon(Icons.school_outlined),
            tooltip: 'התחלת תרגול',
          ),
          IconButton(
            onPressed: _openCompleteTaskDialog,
            icon: const Icon(Icons.checklist),
            tooltip: 'סימון משימה כהושלמה',
          ),
          IconButton(
            onPressed: _openRedeemRewardDialog,
            icon: const Icon(Icons.card_giftcard),
            tooltip: 'מימוש פרס',
          ),
          IconButton(
            onPressed: _openPendingRequestsDialog,
            icon: _pendingRequestsCount > 0
                ? Badge(
                    label: Text('$_pendingRequestsCount'),
                    child: const Icon(Icons.notifications_outlined),
                  )
                : const Icon(Icons.notifications_outlined),
            tooltip: 'בקשות ממתינות',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') _openEditChildDialog();
              if (value == 'pin') _openSetPinDialog();
              if (value == 'progress') _openSubjectProgress();
              if (value == 'curriculum') _openCurriculumNotes();
              if (value == 'delete') _confirmDeleteChild();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'edit', child: Text('עריכת פרטים')),
              PopupMenuItem(
                value: 'pin',
                child: Text(_child.hasPin ? 'שינוי קוד PIN' : 'הגדרת קוד PIN'),
              ),
              const PopupMenuItem(value: 'progress', child: Text('רמת לימוד ותרגול')),
              const PopupMenuItem(value: 'curriculum', child: Text('ספרי לימוד לשנה')),
              const PopupMenuItem(value: 'delete', child: Text('מחיקת ילד')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text('יתרת נקודות', style: Theme.of(context).textTheme.titleMedium),
                Text('$_balance', style: Theme.of(context).textTheme.displayMedium),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: FutureBuilder<List<PointsTransaction>>(
              future: _transactionsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('שגיאה בטעינה: ${snapshot.error}'));
                }

                final transactions = snapshot.data ?? [];
                if (transactions.isEmpty) {
                  return const Center(child: Text('אין עדיין תנועות נקודות'));
                }

                return ListView.builder(
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final tx = transactions[index];
                    final isPositive = tx.amount > 0;
                    return ListTile(
                      title: Text(tx.reason),
                      subtitle: Text(_formatDate(tx.createdAt)),
                      trailing: Text(
                        '${isPositive ? '+' : ''}${tx.amount}',
                        style: TextStyle(
                          color: isPositive ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddTransactionDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year}';
  }
}
