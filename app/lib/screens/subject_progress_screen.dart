import 'package:flutter/material.dart';
import '../models/child.dart';
import '../models/subject_progress.dart';
import '../models/practice_stats.dart';
import '../services/api_service.dart';
import '../services/practice_service.dart';

class _ProgressAndStats {
  final List<SubjectProgress> progress;
  final List<PracticeStats> stats;

  _ProgressAndStats(this.progress, this.stats);
}

class SubjectProgressScreen extends StatefulWidget {
  final ApiService apiService;
  final Child child;

  const SubjectProgressScreen({super.key, required this.apiService, required this.child});

  @override
  State<SubjectProgressScreen> createState() => _SubjectProgressScreenState();
}

class _SubjectProgressScreenState extends State<SubjectProgressScreen> {
  late Child _child;
  late Future<_ProgressAndStats> _dataFuture;
  bool _isTogglingSubject = false;

  @override
  void initState() {
    super.initState();
    _child = widget.child;
    _dataFuture = _loadData();
  }

  Future<_ProgressAndStats> _loadData() async {
    final results = await Future.wait([
      widget.apiService.fetchSubjectProgress(_child.id),
      widget.apiService.fetchPracticeStats(_child.id),
    ]);
    return _ProgressAndStats(
      results[0] as List<SubjectProgress>,
      results[1] as List<PracticeStats>,
    );
  }

  Future<void> _toggleSubjectEnabled(String subject, bool enabled) async {
    setState(() => _isTogglingSubject = true);
    final newDisabled = List<String>.from(_child.disabledSubjects);
    if (enabled) {
      newDisabled.remove(subject);
    } else if (!newDisabled.contains(subject)) {
      newDisabled.add(subject);
    }

    try {
      final updated = await widget.apiService.updateChild(
        childId: _child.id,
        disabledSubjects: newDisabled,
      );
      if (!mounted) return;
      setState(() {
        _child = updated;
        _isTogglingSubject = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isTogglingSubject = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('שגיאה: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('רמת לימוד — ${_child.name}')),
      body: FutureBuilder<_ProgressAndStats>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('שגיאה בטעינה: ${snapshot.error}'));
          }

          final progress = snapshot.data?.progress ?? [];
          final statsBySubject = {
            for (final s in snapshot.data?.stats ?? <PracticeStats>[]) s.subject: s,
          };
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _MixedWeightsCard(
                apiService: widget.apiService,
                child: _child,
                onSaved: (updated) => setState(() => _child = updated),
              ),
              const SizedBox(height: 16),
              ...progress.map((p) {
                final subject = p.subject;
                final isEnabled = !_child.disabledSubjects.contains(subject);
                return _SubjectProgressCard(
                  apiService: widget.apiService,
                  childId: _child.id,
                  progress: p,
                  stats: statsBySubject[subject],
                  isEnabled: isEnabled,
                  isTogglingSubject: _isTogglingSubject,
                  onToggleEnabled: (enabled) => _toggleSubjectEnabled(subject, enabled),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

class _MixedWeightsCard extends StatefulWidget {
  final ApiService apiService;
  final Child child;
  final ValueChanged<Child> onSaved;

  const _MixedWeightsCard({required this.apiService, required this.child, required this.onSaved});

  @override
  State<_MixedWeightsCard> createState() => _MixedWeightsCardState();
}

class _MixedWeightsCardState extends State<_MixedWeightsCard> {
  late Map<String, int> _weights;
  bool _isSaving = false;
  bool _isDirty = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.child.subjectWeights;
    _weights = {
      for (final s in practiceSubjects) s: existing?[s] ?? (100 ~/ practiceSubjects.length),
    };
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final updated = await widget.apiService.updateChild(
        childId: widget.child.id,
        subjectWeights: _weights,
      );
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _isDirty = false;
      });
      widget.onSaved(updated);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('נשמר')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('שגיאה: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _weights.values.fold<int>(0, (a, b) => a + b);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('אחוזי תרגול מעורב', style: Theme.of(context).textTheme.titleMedium),
            Text(
              'קובע כמה מהשאלות ב"תרגול מעורב" יגיעו מכל מקצוע. היחס נשמר גם אם הסכום אינו 100.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            ...practiceSubjects.map((subject) {
              final value = _weights[subject] ?? 0;
              final percent = total == 0 ? 0 : (value * 100 / total).round();
              return Row(
                children: [
                  SizedBox(width: 70, child: Text(subjectLabel(subject))),
                  Expanded(
                    child: Slider(
                      value: value.toDouble(),
                      min: 0,
                      max: 100,
                      divisions: 20,
                      label: '$value',
                      onChanged: (v) {
                        setState(() {
                          _weights[subject] = v.round();
                          _isDirty = true;
                        });
                      },
                    ),
                  ),
                  SizedBox(width: 40, child: Text('$percent%', textAlign: TextAlign.end)),
                ],
              );
            }),
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

class _SubjectProgressCard extends StatefulWidget {
  final ApiService apiService;
  final String childId;
  final SubjectProgress progress;
  final PracticeStats? stats;
  final bool isEnabled;
  final bool isTogglingSubject;
  final ValueChanged<bool> onToggleEnabled;

  const _SubjectProgressCard({
    required this.apiService,
    required this.childId,
    required this.progress,
    required this.stats,
    required this.isEnabled,
    required this.isTogglingSubject,
    required this.onToggleEnabled,
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
            Row(
              children: [
                Expanded(
                  child: Text(subjectLabel(widget.progress.subject),
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                Text('פעיל', style: Theme.of(context).textTheme.bodySmall),
                Switch(
                  value: widget.isEnabled,
                  onChanged: widget.isTogglingSubject ? null : widget.onToggleEnabled,
                ),
              ],
            ),
            if (!widget.isEnabled)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'המקצוע חסום — הילד לא יראה אותו בכלל במסך בחירת המקצוע לתרגול.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.orange),
                ),
              ),
            if (widget.stats != null && widget.stats!.totalAnswered > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '${widget.stats!.totalAnswered} שאלות נענו · '
                  '${widget.stats!.correctPercent}% הצלחה',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('עדיין לא תרגל/ה במקצוע זה', style: Theme.of(context).textTheme.bodySmall),
              ),
            const SizedBox(height: 4),
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
