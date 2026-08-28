import 'package:flutter/material.dart';
import '../models/question_draft.dart';
import '../services/api_service.dart';
import '../services/practice_service.dart';

class AiContentScreen extends StatefulWidget {
  final ApiService apiService;

  const AiContentScreen({super.key, required this.apiService});

  @override
  State<AiContentScreen> createState() => _AiContentScreenState();
}

class _AiContentScreenState extends State<AiContentScreen> {
  String _subject = practiceSubjects.first;
  int _gradeLevel = 1;
  String _difficulty = 'MEDIUM';
  int _count = 5;
  bool _isGenerating = false;
  String _listStatus = 'pending';

  late Future<List<QuestionDraft>> _listFuture;

  @override
  void initState() {
    super.initState();
    _listFuture = widget.apiService.fetchQuestionDrafts(status: _listStatus);
  }

  void _reload() {
    setState(() {
      _listFuture = widget.apiService.fetchQuestionDrafts(status: _listStatus);
    });
  }

  void _switchStatus(String status) {
    setState(() => _listStatus = status);
    _reload();
  }

  Future<void> _generate() async {
    setState(() => _isGenerating = true);
    try {
      await widget.apiService.generateQuestionDrafts(
        subject: _subject,
        gradeLevel: _gradeLevel,
        difficulty: _difficulty,
        count: _count,
      );
      if (!mounted) return;
      setState(() => _isGenerating = false);
      _reload();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isGenerating = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('שגיאה: $e')));
    }
  }

  Future<void> _approve(QuestionDraft draft) async {
    try {
      await widget.apiService.setQuestionDraftApproved(draftId: draft.id, approved: true);
      _reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('השאלה אושרה ותתווסף לתרגול הילדים')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('שגיאה: $e')));
      }
    }
  }

  Future<void> _reject(QuestionDraft draft) async {
    try {
      await widget.apiService.deleteQuestionDraft(draft.id);
      _reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('שגיאה: $e')));
      }
    }
  }

  Future<void> _remove(QuestionDraft draft) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('הסרת שאלה'),
        content: const Text('להסיר את השאלה הזו מהתרגול של הילדים?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('ביטול'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('הסרה'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _reject(draft);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('יצירת שאלות עם AI')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('הגדרת שאלות חדשות', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _subject,
                    decoration: const InputDecoration(labelText: 'מקצוע'),
                    items: practiceSubjects
                        .map((s) => DropdownMenuItem(value: s, child: Text(subjectLabel(s))))
                        .toList(),
                    onChanged: _isGenerating
                        ? null
                        : (value) => setState(() => _subject = value ?? _subject),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: _gradeLevel,
                          decoration: const InputDecoration(labelText: 'כיתה'),
                          items: List.generate(gradeLabels.length, (i) => i + 1)
                              .map((g) => DropdownMenuItem(value: g, child: Text(gradeLabel(g))))
                              .toList(),
                          onChanged: _isGenerating
                              ? null
                              : (value) => setState(() => _gradeLevel = value ?? _gradeLevel),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _difficulty,
                          decoration: const InputDecoration(labelText: 'רמת קושי'),
                          items: const ['EASY', 'MEDIUM', 'HARD']
                              .map((d) => DropdownMenuItem(value: d, child: Text(difficultyLabel(d))))
                              .toList(),
                          onChanged: _isGenerating
                              ? null
                              : (value) => setState(() => _difficulty = value ?? _difficulty),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: _count,
                    decoration: const InputDecoration(labelText: 'כמות שאלות'),
                    items: [1, 3, 5, 10]
                        .map((c) => DropdownMenuItem(value: c, child: Text('$c')))
                        .toList(),
                    onChanged: _isGenerating
                        ? null
                        : (value) => setState(() => _count = value ?? _count),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _isGenerating ? null : _generate,
                    icon: _isGenerating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome),
                    label: Text(_isGenerating ? 'יוצר שאלות...' : 'צור שאלות'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'pending', label: Text('ממתינות לאישור')),
              ButtonSegment(value: 'approved', label: Text('כבר אושרו')),
            ],
            selected: {_listStatus},
            onSelectionChanged: (selection) => _switchStatus(selection.first),
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<QuestionDraft>>(
            future: _listFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('שגיאה בטעינה: ${snapshot.error}'),
                );
              }

              final drafts = snapshot.data ?? [];
              if (drafts.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _listStatus == 'pending'
                        ? 'אין כרגע שאלות ממתינות לאישור.'
                        : 'עדיין לא אושרו שאלות AI למשפחה הזו.',
                  ),
                );
              }

              return Column(
                children: drafts.map((draft) => _DraftCard(
                      draft: draft,
                      onApprove: _listStatus == 'pending' ? () => _approve(draft) : null,
                      onReject: _listStatus == 'pending' ? () => _reject(draft) : null,
                      onRemove: _listStatus == 'approved' ? () => _remove(draft) : null,
                    )).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DraftCard extends StatelessWidget {
  final QuestionDraft draft;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onRemove;

  const _DraftCard({required this.draft, this.onApprove, this.onReject, this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Chip(label: Text(subjectLabel(draft.subject))),
                const SizedBox(width: 6),
                Chip(label: Text(gradeLabel(draft.gradeLevel))),
                const SizedBox(width: 6),
                Chip(label: Text(difficultyLabel(draft.difficulty))),
              ],
            ),
            const SizedBox(height: 12),
            Text(draft.questionText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            ...List.generate(draft.options.length, (i) {
              final isCorrect = i == draft.correctOptionIndex;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Icon(
                      isCorrect ? Icons.check_circle : Icons.circle_outlined,
                      size: 18,
                      color: isCorrect ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        draft.options[i],
                        style: TextStyle(fontWeight: isCorrect ? FontWeight.bold : FontWeight.normal),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
            Text('הסבר: ${draft.explanation}', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            if (onRemove != null)
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('הסרה'),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onReject,
                      child: const Text('דחייה'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: onApprove,
                      child: const Text('אישור'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
