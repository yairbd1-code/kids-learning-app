import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_selector/file_selector.dart';
import '../models/child.dart';
import '../models/curriculum_note.dart';
import '../services/api_service.dart';
import '../services/practice_service.dart';

class CurriculumNotesScreen extends StatefulWidget {
  final ApiService apiService;
  final Child child;

  const CurriculumNotesScreen({super.key, required this.apiService, required this.child});

  @override
  State<CurriculumNotesScreen> createState() => _CurriculumNotesScreenState();
}

class _CurriculumNotesScreenState extends State<CurriculumNotesScreen> {
  late Future<List<CurriculumNote>> _notesFuture;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _notesFuture = widget.apiService.fetchCurriculumNotes(widget.child.id);
  }

  void _reload() {
    setState(() {
      _notesFuture = widget.apiService.fetchCurriculumNotes(widget.child.id);
    });
  }

  Future<String?> _pickSubject() async {
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('לאיזה מקצוע?'),
        children: practiceSubjects
            .map((s) => SimpleDialogOption(
                  onPressed: () => Navigator.of(dialogContext).pop(s),
                  child: Text(subjectLabel(s)),
                ))
            .toList(),
      ),
    );
  }

  Future<void> _openAddTextDialog() async {
    final subject = await _pickSubject();
    if (subject == null || !mounted) return;

    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text('חומר לימוד — ${subjectLabel(subject)}'),
              content: Form(
                key: formKey,
                child: TextFormField(
                  controller: controller,
                  maxLines: 4,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'מה הילד/ה לומד/ת השנה?',
                    hintText: 'לדוגמה: פרק 3 - שברים, כיתה ה׳',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'שדה חובה' : null,
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
                            await widget.apiService.addCurriculumNote(
                              childId: widget.child.id,
                              subject: subject,
                              noteText: controller.text.trim(),
                            );
                            if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                            _reload();
                          } catch (e) {
                            setDialogState(() => isSaving = false);
                            if (dialogContext.mounted) {
                              ScaffoldMessenger.of(dialogContext)
                                  .showSnackBar(SnackBar(content: Text('שגיאה: $e')));
                            }
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('הוספה'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _addFromImage(ImageSource source) async {
    final subject = await _pickSubject();
    if (subject == null || !mounted) return;

    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(source: source, imageQuality: 80);
    if (picked == null || !mounted) return;

    final bytes = await picked.readAsBytes();
    await _upload(subject: subject, bytes: bytes, mediaType: _mediaTypeFor(picked.name));
  }

  Future<void> _addFromFile() async {
    final subject = await _pickSubject();
    if (subject == null || !mounted) return;

    const pdfType = XTypeGroup(label: 'PDF', extensions: ['pdf']);
    final XFile? picked = await openFile(acceptedTypeGroups: [pdfType]);
    if (picked == null || !mounted) return;

    final bytes = await picked.readAsBytes();
    await _upload(subject: subject, bytes: bytes, mediaType: 'application/pdf');
  }

  Future<void> _upload({
    required String subject,
    required List<int> bytes,
    required String mediaType,
  }) async {
    setState(() => _isBusy = true);
    try {
      final base64Data = base64Encode(bytes);
      await widget.apiService.addCurriculumNoteFromImage(
        childId: widget.child.id,
        subject: subject,
        imageBase64: base64Data,
        mediaType: mediaType,
      );
      if (!mounted) return;
      setState(() => _isBusy = false);
      _reload();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('הקובץ נקרא ונוסף כחומר לימוד')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('שגיאה: $e')));
    }
  }

  IconData _sourceIcon(String source) {
    switch (source) {
      case 'photo':
        return Icons.photo_camera_outlined;
      case 'file':
        return Icons.picture_as_pdf_outlined;
      default:
        return Icons.edit_note;
    }
  }

  String _mediaTypeFor(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    return 'image/jpeg';
  }

  Future<void> _delete(CurriculumNote note) async {
    try {
      await widget.apiService.deleteCurriculumNote(childId: widget.child.id, noteId: note.id);
      _reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('שגיאה: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('ספרי לימוד — ${widget.child.name}')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'תארו כאן מה הילד/ה לומד/ת השנה בכל מקצוע — בכתיבה, בצילום דף מהספר, '
                  'או בהעלאת קובץ PDF. התמונה/הקובץ עצמם נמחקים מיד אחרי הקריאה, נשמר '
                  'רק התיאור. המידע הזה ישמש ליצירת שאלות תרגול מותאמות יותר במסך '
                  '"יצירת שאלות עם AI".',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _isBusy ? null : _openAddTextDialog,
                      icon: const Icon(Icons.edit_note),
                      label: const Text('הוספת טקסט'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _isBusy ? null : () => _addFromImage(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: const Text('צילום'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _isBusy ? null : () => _addFromImage(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('תמונה'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _isBusy ? null : _addFromFile,
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('קובץ PDF'),
                    ),
                  ],
                ),
                if (_isBusy) ...[
                  const SizedBox(height: 12),
                  const Center(child: CircularProgressIndicator()),
                  const SizedBox(height: 4),
                  const Center(child: Text('קורא את הקובץ...')),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: FutureBuilder<List<CurriculumNote>>(
              future: _notesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('שגיאה בטעינה: ${snapshot.error}'));
                }

                final notes = snapshot.data ?? [];
                if (notes.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('עדיין לא נוסף חומר לימוד לילד/ה הזה.'),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: notes.length,
                  itemBuilder: (context, index) {
                    final note = notes[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: Icon(_sourceIcon(note.source)),
                        title: Text(subjectLabel(note.subject)),
                        subtitle: Text(note.noteText),
                        isThreeLine: true,
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _delete(note),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
