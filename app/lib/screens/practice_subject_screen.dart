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
    default:
      return Icons.school_outlined;
  }
}

class PracticeSubjectScreen extends StatelessWidget {
  final ChildSession session;

  const PracticeSubjectScreen({super.key, required this.session});

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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: practiceSubjects.map((subject) {
          return Card(
            child: ListTile(
              leading: Icon(_subjectIcon(subject), size: 32),
              title: Text(subjectLabel(subject), style: const TextStyle(fontSize: 20)),
              trailing: const Icon(Icons.chevron_left),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => PracticeScreen(session: session, subject: subject),
                  ),
                );
              },
            ),
          );
        }).toList(),
      ),
    );
  }
}
