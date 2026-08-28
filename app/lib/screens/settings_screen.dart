import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';

class SettingsScreen extends StatefulWidget {
  final AuthService authService;

  const SettingsScreen({super.key, required this.authService});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Future<ProfileInfo> _profileFuture;
  late Future<List<FamilyMember>> _membersFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = widget.authService.fetchProfile();
    _membersFuture = widget.authService.fetchFamilyMembers();
  }

  void _reload() {
    setState(() {
      _profileFuture = widget.authService.fetchProfile();
      _membersFuture = widget.authService.fetchFamilyMembers();
    });
  }

  Future<void> _openEditNamesDialog(ProfileInfo profile) async {
    final formKey = GlobalKey<FormState>();
    final parentNameController = TextEditingController(text: profile.parentName);
    final familyNameController = TextEditingController(text: profile.familyName);
    bool isSaving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('עריכת פרטים'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: parentNameController,
                      decoration: const InputDecoration(labelText: 'השם שלך'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'שדה חובה' : null,
                    ),
                    TextFormField(
                      controller: familyNameController,
                      decoration: const InputDecoration(labelText: 'שם המשפחה'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'שדה חובה' : null,
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
                            await widget.authService.updateProfile(
                              parentName: parentNameController.text.trim(),
                              familyName: familyNameController.text.trim(),
                            );
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
                      : const Text('שמירה'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openChangePasswordDialog() async {
    final formKey = GlobalKey<FormState>();
    final currentController = TextEditingController();
    final newController = TextEditingController();
    bool isSaving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('שינוי סיסמה'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: currentController,
                      decoration: const InputDecoration(labelText: 'סיסמה נוכחית'),
                      obscureText: true,
                      validator: (v) => (v == null || v.isEmpty) ? 'שדה חובה' : null,
                    ),
                    TextFormField(
                      controller: newController,
                      decoration: const InputDecoration(labelText: 'סיסמה חדשה'),
                      obscureText: true,
                      validator: (v) {
                        if (v == null || v.length < 8) return 'סיסמה חייבת להיות באורך 8 תווים לפחות';
                        return null;
                      },
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
                            await widget.authService.updateProfile(
                              currentPassword: currentController.text,
                              newPassword: newController.text,
                            );
                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('הסיסמה עודכנה בהצלחה')),
                              );
                            }
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
                      : const Text('שמירה'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('הגדרות')),
      body: FutureBuilder<ProfileInfo>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('שגיאה בטעינה: ${snapshot.error}'));
          }

          final profile = snapshot.data!;
          return ListView(
            children: [
              ListTile(
                title: const Text('השם שלך'),
                subtitle: Text(profile.parentName),
              ),
              ListTile(
                title: const Text('אימייל'),
                subtitle: Text(profile.email),
              ),
              ListTile(
                title: const Text('שם המשפחה'),
                subtitle: Text(profile.familyName),
              ),
              const Divider(),
              ListTile(
                title: const Text('קוד משפחה'),
                subtitle: Text(
                  '${profile.joinCode}\nשתפו את הקוד עם בן/בת הזוג כדי שיוכלו להצטרף לאותה משפחה',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.copy),
                  tooltip: 'העתקת הקוד',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: profile.joinCode));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('הקוד הועתק')),
                    );
                  },
                ),
              ),
              FutureBuilder<List<FamilyMember>>(
                future: _membersFuture,
                builder: (context, snapshot) {
                  final members = snapshot.data ?? [];
                  if (members.length <= 1) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('בני המשפחה עם גישה', style: Theme.of(context).textTheme.labelLarge),
                        ...members.map(
                          (m) => Text('${m.name} · ${m.email}',
                              style: Theme.of(context).textTheme.bodySmall),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('עריכת שם / שם משפחה'),
                onTap: () => _openEditNamesDialog(profile),
              ),
              ListTile(
                leading: const Icon(Icons.lock_outline),
                title: const Text('שינוי סיסמה'),
                onTap: _openChangePasswordDialog,
              ),
            ],
          );
        },
      ),
    );
  }
}
