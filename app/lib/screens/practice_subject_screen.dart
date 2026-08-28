import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/practice_service.dart';
import 'practice_screen.dart';

IconData _subjectIcon(String subject) {
  switch (subject) {
    case 'math':
      return Icons.calculate_outlined;
    case 'english':
      return Icons.language_outlined;
    case 'hebrew':
      return Icons.menu_book_outlined;
    case mixedSubjectValue:
      return Icons.shuffle;
    default:
      return Icons.school_outlined;
  }
}

class PracticeSubjectScreen extends StatefulWidget {
  final ChildSession session;

  const PracticeSubjectScreen({super.key, required this.session});

  @override
  State<PracticeSubjectScreen> createState() => _PracticeSubjectScreenState();
}

class _PracticeSubjectScreenState extends State<PracticeSubjectScreen> {
  late final PracticeService _practiceService;
  late Future<List<String>> _subjectsFuture;

  @override
  void initState() {
    super.initState();
    _practiceService = PracticeService(widget.session.token);
    _subjectsFuture = _practiceService.fetchEnabledSubjects();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('באיזה מקצוע נתרגל?'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
            icon: const Icon(Icons.close),
            tooltip: 'סיום תרגול',
          ),
        ],
      ),
      body: FutureBuilder<List<String>>(
        future: _subjectsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('שגיאה בטעינה: ${snapshot.error}'));
          }

          final subjects = snapshot.data ?? [];
          if (subjects.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('אין כרגע מקצועות זמינים לתרגול. בקשו מההורה להפעיל מקצוע.'),
              ),
            );
          }

          final tiles = <String>[
            if (subjects.length > 1) mixedSubjectValue,
            ...subjects,
          ];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: tiles.map((subject) {
              return Card(
                child: ListTile(
                  leading: Icon(_subjectIcon(subject), size: 32),
                  title: Text(subjectLabel(subject), style: const TextStyle(fontSize: 20)),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            PracticeScreen(session: widget.session, subject: subject),
                      ),
                    );
                  },
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
