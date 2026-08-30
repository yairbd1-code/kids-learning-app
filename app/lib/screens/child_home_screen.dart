import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/child_profile_service.dart';
import '../theme/child_theme.dart';
import 'practice_subject_screen.dart';
import 'child_store_screen.dart';
import 'child_theme_screen.dart';

class ChildHomeScreen extends StatefulWidget {
  final ChildSession session;

  const ChildHomeScreen({super.key, required this.session});

  @override
  State<ChildHomeScreen> createState() => _ChildHomeScreenState();
}

class _ChildHomeScreenState extends State<ChildHomeScreen> {
  late final ChildProfileService _profileService;
  ChildTheme _theme = ChildTheme.byId(null);

  @override
  void initState() {
    super.initState();
    _profileService = ChildProfileService(widget.session.token);
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    try {
      final profile = await _profileService.fetchProfile();
      if (!mounted) return;
      setState(() => _theme = ChildTheme.byId(profile.themeId));
    } catch (_) {
      // לא קריטי - נשארים עם צבע ברירת המחדל
    }
  }

  Future<void> _openThemePicker() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChildThemeScreen(
          session: widget.session,
          onThemeChanged: (themeId) => setState(() => _theme = ChildTheme.byId(themeId)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('שלום, ${widget.session.childName}!'),
        backgroundColor: _theme.primary,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: _openThemePicker,
            icon: const Icon(Icons.palette_outlined),
            tooltip: 'הצבעים שלי',
          ),
          IconButton(
            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
            icon: const Icon(Icons.close),
            tooltip: 'יציאה',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_theme.primary.withValues(alpha: 0.12), Colors.transparent],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: _theme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 24),
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => PracticeSubjectScreen(
                            session: widget.session,
                            themeColor: _theme.primary,
                          ),
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
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _theme.primary,
                      side: BorderSide(color: _theme.primary, width: 2),
                      padding: const EdgeInsets.symmetric(vertical: 24),
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => ChildStoreScreen(
                            session: widget.session,
                            themeColor: _theme.primary,
                          ),
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
      ),
    );
  }
}
