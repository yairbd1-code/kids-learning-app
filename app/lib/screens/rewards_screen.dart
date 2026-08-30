import 'package:flutter/material.dart';
import '../models/reward.dart';
import '../services/api_service.dart';

const _pointTemplates = {
  'קטן': 20,
  'בינוני': 50,
  'גדול': 100,
};

class RewardsScreen extends StatefulWidget {
  final ApiService apiService;

  const RewardsScreen({super.key, required this.apiService});

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> {
  late Future<List<Reward>> _rewardsFuture;

  @override
  void initState() {
    super.initState();
    _rewardsFuture = widget.apiService.fetchRewards();
  }

  void _reload() {
    setState(() {
      _rewardsFuture = widget.apiService.fetchRewards();
    });
  }

  Future<void> _openRewardDialog({Reward? existing}) async {
    final isEditing = existing != null;
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: existing?.name ?? '');
    final costController = TextEditingController(text: existing?.costPoints.toString() ?? '');
    bool isSaving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text(isEditing ? 'עריכת פרס' : 'הוספת פרס'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'שם הפרס'),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'חובה להזין שם';
                        }
                        return null;
                      },
                    ),
                    TextFormField(
                      controller: costController,
                      decoration: const InputDecoration(labelText: 'עלות בנקודות'),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        final cost = int.tryParse(value ?? '');
                        if (cost == null || cost <= 0) {
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
                            onPressed: () => costController.text = entry.value.toString(),
                          );
                        }).toList(),
                      ),
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
                            if (isEditing) {
                              await widget.apiService.updateReward(
                                rewardId: existing.id,
                                name: nameController.text.trim(),
                                costPoints: int.parse(costController.text),
                              );
                            } else {
                              await widget.apiService.addReward(
                                name: nameController.text.trim(),
                                costPoints: int.parse(costController.text),
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

  Future<void> _deleteReward(Reward reward) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('מחיקת פרס'),
        content: Text('למחוק את "${reward.name}"?'),
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
      await widget.apiService.deleteReward(reward.id);
      _reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('שגיאה: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('חנות פרסים')),
      body: FutureBuilder<List<Reward>>(
        future: _rewardsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('שגיאה בטעינה: ${snapshot.error}'));
          }

          final rewards = snapshot.data ?? [];
          if (rewards.isEmpty) {
            return const Center(child: Text('עדיין לא נוספו פרסים. לחצו על + כדי להתחיל.'));
          }

          final colorScheme = Theme.of(context).colorScheme;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: rewards.length,
            itemBuilder: (context, index) {
              final reward = rewards[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => _openRewardDialog(existing: reward),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(Icons.card_giftcard, color: colorScheme.onPrimary),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                reward.name,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.star_rounded,
                                        size: 14, color: colorScheme.onPrimaryContainer),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${reward.costPoints} נק׳',
                                      style: TextStyle(
                                        color: colorScheme.onPrimaryContainer,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'מחיקה',
                          onPressed: () => _deleteReward(reward),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openRewardDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
