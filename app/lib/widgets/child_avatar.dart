import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../theme/child_theme.dart';

/// אווטאר של ילד/ה - תמונת פרופיל אם קיימת, אחרת אותיות ראשונות על רקע
/// ערכת הצבע האישית שלו/ה.
class ChildAvatar extends StatelessWidget {
  final String? photoDataUri;
  final String themeId;
  final String name;
  final double radius;

  const ChildAvatar({
    super.key,
    required this.photoDataUri,
    required this.themeId,
    required this.name,
    this.radius = 28,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ChildTheme.byId(themeId);
    final bytes = _decodePhoto(photoDataUri);

    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(shape: BoxShape.circle, gradient: theme.gradient),
      alignment: Alignment.center,
      child: bytes != null
          ? ClipOval(
              child: Image.memory(
                bytes,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
              ),
            )
          : Text(
              name.isEmpty ? '?' : name.substring(0, 1),
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: radius * 0.7,
              ),
            ),
    );
  }

  static Uint8List? _decodePhoto(String? dataUri) {
    if (dataUri == null) return null;
    final commaIndex = dataUri.indexOf(',');
    if (!dataUri.startsWith('data:image/') || commaIndex == -1) return null;
    try {
      return base64Decode(dataUri.substring(commaIndex + 1));
    } catch (_) {
      return null;
    }
  }
}
