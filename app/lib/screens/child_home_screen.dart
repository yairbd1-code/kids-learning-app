import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'practice_subject_screen.dart';
import 'child_store_screen.dart';

class ChildHomeScreen extends StatelessWidget {
  final ChildSession session;

  const ChildHomeScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('שלום, ${session.childName}!'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
            icon: const Icon(Icons.close),
            tooltip: 'יציאה',
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 24)),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => PracticeSubjectScreen(session: session),
                      ),
                    );
                  },
                  icon: const Icon(Icons.school, size: 32),
                  label: const Text('תרגול', style: TextStyle(fontSize: 22)),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 24)),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => ChildStoreScreen(session: session),
                      ),
                    );
                  },
                  icon: const Icon(Icons.storefront, size: 32),
                  label: const Text('חנות פרסים', style: TextStyle(fontSize: 22)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
