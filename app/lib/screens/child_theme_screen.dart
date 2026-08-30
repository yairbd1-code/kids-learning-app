import 'package:flutter/material.dart';
import '../theme/child_theme.dart';
import '../services/api_service.dart';
import '../services/child_profile_service.dart';

class ChildThemeScreen extends StatefulWidget {
  final ChildSession session;
  final ValueChanged<String>? onThemeChanged;

  const ChildThemeScreen({super.key, required this.session, this.onThemeChanged});

  @override
  State<ChildThemeScreen> createState() => _ChildThemeScreenState();
}

class _ChildThemeScreenState extends State<ChildThemeScreen> {
  late final ChildProfileService _profileService;
  String? _currentThemeId;
  bool _isSaving = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _profileService = ChildProfileService(widget.session.token);
    _load();
  }

  Future<void> _load() async {
    try {
      final profile = await _profileService.fetchProfile();
      if (!mounted) return;
      setState(() {
        _currentThemeId = profile.themeId;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('שגיאה: $e')));
    }
  }

  Future<void> _select(ChildTheme theme) async {
    if (_isSaving || theme.id == _currentThemeId) return;
    setState(() => _isSaving = true);
    try {
      await _profileService.updateTheme(theme.id);
      if (!mounted) return;
      setState(() {
        _currentThemeId = theme.id;
        _isSaving = false;
      });
      widget.onThemeChanged?.call(theme.id);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('שגיאה: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('הצבעים שלי')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('בחרו את הצבע שהכי מדבר אליכם!', textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 1.3,
                      children: ChildTheme.all.map((theme) {
                        final isSelected = theme.id == _currentThemeId;
                        return InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: _isSaving ? null : () => _select(theme),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: theme.gradient,
                              borderRadius: BorderRadius.circular(20),
                              border: isSelected
                                  ? Border.all(color: Colors.white, width: 4)
                                  : null,
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: theme.primary.withValues(alpha: 0.6),
                                        blurRadius: 12,
                                        spreadRadius: 2,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isSelected)
                                    const Icon(Icons.check_circle, color: Colors.white, size: 28),
                                  Text(
                                    theme.label,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
