import 'package:flutter/material.dart';
import '../models/child.dart';
import '../models/subject_progress.dart';
import '../services/api_service.dart';
import '../services/practice_service.dart';

class SubjectProgressScreen extends StatefulWidget {
  final ApiService apiService;
  final Child child;

  const SubjectProgressScreen({super.key, required this.apiService, required this.child});

  @override
  State<SubjectProgressScreen> createState() => _SubjectProgressScreenState();
}

class _SubjectProgressScreenState extends State<SubjectProgressScreen> {
  late Future<List<SubjectProgress>> _progressFuture;

  @override
  void initState() {
    super.initState();
    _progressFuture = widget.apiService.fetchSubjectProgress(widget.child.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('רמת לימוד — ${widget.child.name}')),
      body: FutureBuilder<List<SubjectProgress>>(
        future: _progressFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('שגיאה בטעינה: ${snapshot.error}'));
          }

          final progress = snapshot.data ?? [];
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: progress.length,
            itemBuilder: (context, index) {
              return _SubjectProgressCard(
                apiService: widget.apiService,
                childId: widget.child.id,
                progress: progress[index],
              );
            },
          );
        },
      ),
    );
  }
}

class _SubjectProgressCard extends StatefulWidget {
  final ApiService apiService;
  final String childId;
  final SubjectProgress progress;

  const _SubjectProgressCard({
    required this.apiService,
    required this.childId,
    required this.progress,
  });

  @override
  State<_SubjectProgressCard> createState() => _SubjectProgressCardState();
}

class _SubjectProgressCardState extends State<_SubjectProgressCard> {
  late int _grade;
  late String _difficulty;
  bool _isSaving = false;
  bool _isDirty = false;

  @override
  void initState() {
    super.initState();
    _grade = widget.progress.currentGrade;
    _difficulty = widget.progress.currentDifficulty;
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await widget.apiService.updateSubjectProgress(
        childId: widget.childId,
        subject: widget.progress.subject,
        currentGrade: _grade,
        currentDifficulty: _difficulty,
      );
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _isDirty = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('נשמר')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('שגיאה: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subjectLabel(widget.progress.subject),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _grade,
                    decoration: const InputDecoration(labelText: 'כיתה'),
                    items: List.generate(gradeLabels.length, (i) => i + 1)
                        .map((g) => DropdownMenuItem(value: g, child: Text(gradeLabel(g))))
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _grade = value;
                        _isDirty = true;
                      });
                    },
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
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _difficulty = value;
                        _isDirty = true;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                onPressed: (_isDirty && !_isSaving) ? _save : null,
                child: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('שמירה'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
