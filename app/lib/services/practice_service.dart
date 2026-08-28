import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/practice_question.dart';
import 'auth_service.dart' show apiBaseUrl;

const List<String> practiceSubjects = ['math', 'english', 'hebrew'];
const String mixedSubjectValue = 'mixed';

String subjectLabel(String subject) {
  switch (subject) {
    case 'math':
      return 'חשבון';
    case 'english':
      return 'אנגלית';
    case 'hebrew':
      return 'עברית';
    case mixedSubjectValue:
      return 'תרגול מעורב';
    default:
      return subject;
  }
}

const List<String> gradeLabels = ['א', 'ב', 'ג', 'ד', 'ה', 'ו', 'ז', 'ח'];

String gradeLabel(int gradeLevel) {
  if (gradeLevel < 1 || gradeLevel > gradeLabels.length) return 'כיתה $gradeLevel';
  return 'כיתה ${gradeLabels[gradeLevel - 1]}';
}

String difficultyLabel(String difficulty) {
  switch (difficulty) {
    case 'EASY':
      return 'קלה';
    case 'MEDIUM':
      return 'בינונית';
    case 'HARD':
      return 'קשה';
    default:
      return difficulty;
  }
}

class NoQuestionsAvailableException implements Exception {
  @override
  String toString() => 'אין עדיין שאלות זמינות לרמה הזו';
}

class PracticeService {
  final String childToken;

  PracticeService(this.childToken);

  Map<String, String> get _headers => {
        'Content-Type': 'application/json; charset=utf-8',
        'Authorization': 'Bearer $childToken',
      };

  Future<List<String>> fetchEnabledSubjects() async {
    final response = await http.get(Uri.parse('$apiBaseUrl/practice/subjects'), headers: _headers);

    if (response.statusCode != 200) {
      throw Exception('שגיאה בטעינת רשימת המקצועות (${response.statusCode})');
    }

    final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
    return data.map((e) => e as String).toList();
  }

  Future<PracticeQuestion> fetchNextQuestion(String subject) async {
    final path = subject == mixedSubjectValue ? 'mixed' : subject;
    final response = await http.get(
      Uri.parse('$apiBaseUrl/practice/$path/next-question'),
      headers: _headers,
    );

    if (response.statusCode == 404) {
      throw NoQuestionsAvailableException();
    }
    if (response.statusCode != 200) {
      throw Exception('שגיאה בטעינת השאלה (${response.statusCode})');
    }

    return PracticeQuestion.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
  }

  Future<PracticeAnswerResult> submitAnswer({
    required String questionId,
    required int selectedOptionIndex,
  }) async {
    final response = await http.post(
      Uri.parse('$apiBaseUrl/practice/answer'),
      headers: _headers,
      body: jsonEncode({'questionId': questionId, 'selectedOptionIndex': selectedOptionIndex}),
    );

    final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception((data['error'] as String?) ?? 'שגיאה בשליחת התשובה');
    }

    return PracticeAnswerResult.fromJson(data);
  }
}
