import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/child_theme.dart';
import 'child_avatar.dart';

/// מחזיק את הבחירות הנוכחיות (תמונה + ערכת צבע) בזמן שדיאלוג הוספה/עריכה
/// פתוח, כדי שהערכים ייקראו בזמן השמירה - באותה רוח כמו TextEditingController
/// לשדות הטקסט באותם הדיאלוגים.
class ChildAppearanceController {
  String? photoDataUri;
  String themeId;

  ChildAppearanceController({this.photoDataUri, this.themeId = 'ocean'});
}

/// עורך תמונת פרופיל + ערכת צבע אישית לילד/ה, לשימוש בתוך דיאלוג הוספה/עריכה.
class ChildAppearancePicker extends StatefulWidget {
  final ChildAppearanceController controller;
  final String Function() nameForInitials;

  const ChildAppearancePicker({
    super.key,
    required this.controller,
    required this.nameForInitials,
  });

  @override
  State<ChildAppearancePicker> createState() => _ChildAppearancePickerState();
}

class _ChildAppearancePickerState extends State<ChildAppearancePicker> {
  bool _isPicking = false;

  String _mediaTypeFor(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('צילום תמונה'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('בחירה מהגלריה'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    setState(() => _isPicking = true);
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 480,
        maxHeight: 480,
        imageQuality: 75,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final mediaType = _mediaTypeFor(picked.name);
      setState(() {
        widget.controller.photoDataUri = 'data:$mediaType;base64,${base64Encode(bytes)}';
      });
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: GestureDetector(
            onTap: _isPicking ? null : _pickPhoto,
            child: Stack(
              children: [
                ChildAvatar(
                  photoDataUri: widget.controller.photoDataUri,
                  themeId: widget.controller.themeId,
                  name: widget.nameForInitials(),
                  radius: 44,
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        width: 2,
                      ),
                    ),
                    child: _isPicking
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            'הוספת תמונה (אופציונלי)',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: 16),
        Text('ערכת צבע אישית', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 14,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: ChildTheme.all.map((theme) {
            final isSelected = theme.id == widget.controller.themeId;
            return GestureDetector(
              onTap: () => setState(() => widget.controller.themeId = theme.id),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: theme.gradient,
                  border: isSelected
                      ? Border.all(color: Theme.of(context).colorScheme.onSurface, width: 2.5)
                      : null,
                ),
                alignment: Alignment.center,
                child: isSelected
                    ? const Icon(Icons.check, size: 18, color: Colors.white)
                    : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
