class CurriculumNote {
  final String id;
  final String subject;
  final String noteText;
  final String source;
  final DateTime createdAt;

  CurriculumNote({
    required this.id,
    required this.subject,
    required this.noteText,
    required this.source,
    required this.createdAt,
  });

  factory CurriculumNote.fromJson(Map<String, dynamic> json) {
    return CurriculumNote(
      id: json['id'] as String,
      subject: json['subject'] as String,
      noteText: json['noteText'] as String,
      source: json['source'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
