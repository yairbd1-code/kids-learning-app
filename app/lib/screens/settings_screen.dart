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
          final colorScheme = Theme.of(context).colorScheme;

          Widget sectionLabel(String text) => Padding(
                padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
                child: Text(
                  text,
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              );

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              sectionLabel('פרטי חשבון'),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: const Text('השם שלך'),
                      subtitle: Text(profile.parentName),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      leading: const Icon(Icons.email_outlined),
                      title: const Text('אימייל'),
                      subtitle: Text(profile.email),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      leading: const Icon(Icons.groups_outlined),
                      title: const Text('שם המשפחה'),
                      subtitle: Text(profile.familyName),
                    ),
                  ],
                ),
              ),
              sectionLabel('הצטרפות בני משפחה'),
              Card(
                color: colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'קוד המשפחה שלכם',
                              style: TextStyle(
                                color: colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              profile.joinCode,
                              style: TextStyle(
                                color: colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.w800,
                                fontSize: 26,
                                letterSpacing: 3,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'שתפו את הקוד עם בן/בת הזוג כדי שיוכלו להצטרף לאותה משפחה',
                              style: TextStyle(color: colorScheme.onPrimaryContainer, fontSize: 12.5),
                            ),
                          ],
                        ),
                      ),
                      IconButton.filled(
                        icon: const Icon(Icons.copy),
                        tooltip: 'העתקת הקוד',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: profile.joinCode));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('הקוד הועתק')),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              FutureBuilder<List<FamilyMember>>(
                future: _membersFuture,
                builder: (context, snapshot) {
                  final members = snapshot.data ?? [];
                  if (members.length <= 1) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      sectionLabel('בני המשפחה עם גישה'),
                      Card(
                        child: Column(
                          children: [
                            for (var i = 0; i < members.length; i++) ...[
                              if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
                              ListTile(
                                leading: const Icon(Icons.person_outline),
                                title: Text(members[i].name),
                                subtitle: Text(members[i].email),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
              sectionLabel('פעולות'),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.edit_outlined),
                      title: const Text('עריכת שם / שם משפחה'),
                      onTap: () => _openEditNamesDialog(profile),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      leading: const Icon(Icons.lock_outline),
                      title: const Text('שינוי סיסמה'),
                      onTap: _openChangePasswordDialog,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
