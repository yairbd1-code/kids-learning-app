import 'package:flutter/material.dart';
import '../models/practice_question.dart';
import '../services/api_service.dart';
import '../services/practice_service.dart';

class PracticeScreen extends StatefulWidget {
  final ChildSession session;
  final String subject;

  const PracticeScreen({super.key, required this.session, required this.subject});

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  late final PracticeService _practiceService;
  final _scratchpadController = TextEditingController();

  PracticeQuestion? _question;
  PracticeAnswerResult? _result;
  int? _selectedOptionIndex;
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _explanationRequested = false;
  String? _loadError;
  int _sessionPoints = 0;
  int _sessionCorrect = 0;
  int _sessionTotal = 0;

  @override
  void initState() {
    super.initState();
    _practiceService = PracticeService(widget.session.token);
    _loadNextQuestion();
  }

  @override
  void dispose() {
    _scratchpadController.dispose();
    super.dispose();
  }

  Future<void> _loadNextQuestion() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
      _result = null;
      _selectedOptionIndex = null;
      _explanationRequested = false;
      _scratchpadController.clear();
    });

    try {
      final question = await _practiceService.fetchNextQuestion(widget.subject);
      if (!mounted) return;
      setState(() {
        _question = question;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = e is NoQuestionsAvailableException
            ? 'עדיין אין שאלות זמינות ברמה הזו. נסו שוב מאוחר יותר!'
            : 'שגיאה בטעינת השאלה: $e';
      });
    }
  }

  Future<void> _selectOption(int index) async {
    if (_isSubmitting || _result != null || _question == null) return;

    setState(() {
      _isSubmitting = true;
      _selectedOptionIndex = index;
    });

    try {
      final result = await _practiceService.submitAnswer(
        questionId: _question!.id,
        selectedOptionIndex: index,
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _isSubmitting = false;
        _sessionTotal += 1;
        if (result.correct) {
          _sessionCorrect += 1;
          _sessionPoints += result.pointsAwarded;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _selectedOptionIndex = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('שגיאה: $e')));
    }
  }

  Color? _optionColor(int index) {
    if (_result == null) return null;
    if (index == _result!.correctOptionIndex) return Colors.green.shade100;
    if (index == _selectedOptionIndex) return Colors.red.shade100;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(subjectLabel(widget.subject)),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Text('⭐ $_sessionPoints', style: const TextStyle(fontSize: 18)),
            ),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_loadError!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('חזרה לבחירת מקצוע'),
              ),
            ],
          ),
        ),
      );
    }

    final question = _question!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Chip(label: Text(gradeLabel(question.gradeLevel))),
              const SizedBox(width: 8),
              Chip(label: Text(difficultyLabel(question.difficulty))),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            question.questionText,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ...List.generate(question.options.length, (index) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: FilledButton.tonal(
                style: FilledButton.styleFrom(
                  backgroundColor: _optionColor(index),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: _result == null ? () => _selectOption(index) : null,
                child: Text(question.options[index], style: const TextStyle(fontSize: 18)),
              ),
            );
          }),
          if (widget.subject == 'math') ...[
            const SizedBox(height: 12),
            Text('מחברת טיוטה (לא נשמר)', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            TextField(
              controller: _scratchpadController,
              maxLines: 4,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'אפשר לחשב כאן...',
              ),
            ),
          ],
          if (_result != null) ...[
            const SizedBox(height: 20),
            _buildResultCard(_result!),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _loadNextQuestion,
              child: const Text('שאלה הבאה'),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            'סבב זה: $_sessionCorrect מתוך $_sessionTotal נכונות',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(PracticeAnswerResult result) {
    if (result.correct) {
      return Card(
        color: Colors.green.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green),
              const SizedBox(width: 12),
              Expanded(child: Text('כל הכבוד! +${result.pointsAwarded} נקודות')),
            ],
          ),
        ),
      );
    }

    if (!_explanationRequested) {
      return Card(
        color: Colors.orange.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.cancel_outlined, color: Colors.deepOrange),
                  SizedBox(width: 8),
                  Text('לא נכון הפעם', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => setState(() => _explanationRequested = true),
                icon: const Icon(Icons.lightbulb_outline),
                label: const Text('לומדה — תסבירו לי'),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.lightbulb_outline, color: Colors.orange),
                SizedBox(width: 8),
                Text('בואו נלמד יחד', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Text(result.explanation),
          ],
        ),
      ),
    );
  }
}
