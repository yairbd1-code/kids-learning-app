import 'package:flutter/material.dart';

/// ערכת הצבע האישית שכל ילד/ה בוחר/ת לעצמו/ה במסך "הצבעים שלי".
/// ה-id נשמר כמו שהוא ב-DB (Child.themeId) - שינוי כאן חייב להישאר מסונכרן
/// עם ALLOWED_THEMES ב-backend/src/routes/children.ts.
class ChildTheme {
  final String id;
  final String label;
  final Color primary;
  final Color secondary;

  const ChildTheme({
    required this.id,
    required this.label,
    required this.primary,
    required this.secondary,
  });

  LinearGradient get gradient => LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [primary, secondary],
      );

  static const List<ChildTheme> all = [
    ChildTheme(
      id: 'ocean',
      label: 'אוקיינוס',
      primary: Color(0xFF2784D5),
      secondary: Color(0xFF00AFA9),
    ),
    ChildTheme(
      id: 'blossom',
      label: 'פריחה',
      primary: Color(0xFFE662A8),
      secondary: Color(0xFF9860D0),
    ),
    ChildTheme(
      id: 'forest',
      label: 'יער',
      primary: Color(0xFF409D48),
      secondary: Color(0xFF40A47E),
    ),
    ChildTheme(
      id: 'galaxy',
      label: 'גלקסיה',
      primary: Color(0xFF7457D1),
      secondary: Color(0xFFBF56B9),
    ),
    ChildTheme(
      id: 'sunshine',
      label: 'שמש',
      primary: Color(0xFFEF852E),
      secondary: Color(0xFFE4C64F),
    ),
    ChildTheme(
      id: 'fire',
      label: 'אש',
      primary: Color(0xFFE54C4A),
      secondary: Color(0xFFED7940),
    ),
  ];

  static ChildTheme byId(String? id) {
    return all.firstWhere((t) => t.id == id, orElse: () => all.first);
  }
}
