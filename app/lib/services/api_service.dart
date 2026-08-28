import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/child.dart';
import '../models/points_transaction.dart';
import '../models/reward.dart';
import '../models/redemption.dart';
import '../models/learning_task.dart';
import '../models/task_completion.dart';
import '../models/subject_progress.dart';
import '../models/question_draft.dart';
import 'auth_service.dart';

class ChildSession {
  final String token;
  final String childId;
  final String childName;

  ChildSession({required this.token, required this.childId, required this.childName});
}

class ApiService {
  final AuthService authService;

  ApiService(this.authService);

  Map<String, String> get _authHeaders => {
        'Content-Type': 'application/json; charset=utf-8',
        'Authorization': 'Bearer ${authService.token}',
      };

  Future<List<Child>> fetchChildren() async {
    final response = await http.get(
      Uri.parse('$apiBaseUrl/children'),
      headers: _authHeaders,
    );

    if (response.statusCode != 200) {
      throw Exception('שגיאה בטעינת רשימת הילדים (${response.statusCode})');
    }

    final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
    return data.map((json) => Child.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<Child> addChild({
    required String name,
    required int age,
    String? grade,
  }) async {
    final response = await http.post(
      Uri.parse('$apiBaseUrl/children'),
      headers: _authHeaders,
      body: jsonEncode({'name': name, 'age': age, 'grade': grade}),
    );

    if (response.statusCode != 201) {
      throw Exception('שגיאה בהוספת הילד (${response.statusCode})');
    }

    return Child.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
  }

  Future<Child> updateChild({
    required String childId,
    String? name,
    int? age,
    String? grade,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (age != null) body['age'] = age;
    if (grade != null) body['grade'] = grade;

    final response = await http.patch(
      Uri.parse('$apiBaseUrl/children/$childId'),
      headers: _authHeaders,
      body: jsonEncode(body),
    );

    final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception((data['error'] as String?) ?? 'שגיאה בעדכון פרטי הילד');
    }

    return Child.fromJson(data);
  }

  Future<void> deleteChild(String childId) async {
    final response = await http.delete(
      Uri.parse('$apiBaseUrl/children/$childId'),
      headers: _authHeaders,
    );

    if (response.statusCode != 204) {
      final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      throw Exception((data['error'] as String?) ?? 'שגיאה במחיקת הילד');
    }
  }

  Future<List<PointsTransaction>> fetchTransactions(String childId) async {
    final response = await http.get(
      Uri.parse('$apiBaseUrl/children/$childId/transactions'),
      headers: _authHeaders,
    );

    if (response.statusCode != 200) {
      throw Exception('שגיאה בטעינת היסטוריית הנקודות (${response.statusCode})');
    }

    final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
    return data
        .map((json) => PointsTransaction.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<int> addTransaction({
    required String childId,
    required int amount,
    required String reason,
  }) async {
    final response = await http.post(
      Uri.parse('$apiBaseUrl/children/$childId/transactions'),
      headers: _authHeaders,
      body: jsonEncode({'amount': amount, 'reason': reason}),
    );

    final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if (response.statusCode != 201) {
      throw Exception((data['error'] as String?) ?? 'שגיאה בעדכון הנקודות');
    }

    return data['newBalance'] as int;
  }

  Future<List<Reward>> fetchRewards() async {
    final response = await http.get(
      Uri.parse('$apiBaseUrl/rewards'),
      headers: _authHeaders,
    );

    if (response.statusCode != 200) {
      throw Exception('שגיאה בטעינת חנות הפרסים (${response.statusCode})');
    }

    final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
    return data.map((json) => Reward.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<Reward> addReward({required String name, required int costPoints}) async {
    final response = await http.post(
      Uri.parse('$apiBaseUrl/rewards'),
      headers: _authHeaders,
      body: jsonEncode({'name': name, 'costPoints': costPoints}),
    );

    final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if (response.statusCode != 201) {
      throw Exception((data['error'] as String?) ?? 'שגיאה בהוספת הפרס');
    }

    return Reward.fromJson(data);
  }

  Future<Reward> updateReward({
    required String rewardId,
    String? name,
    int? costPoints,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (costPoints != null) body['costPoints'] = costPoints;

    final response = await http.patch(
      Uri.parse('$apiBaseUrl/rewards/$rewardId'),
      headers: _authHeaders,
      body: jsonEncode(body),
    );

    final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception((data['error'] as String?) ?? 'שגיאה בעדכון הפרס');
    }

    return Reward.fromJson(data);
  }

  Future<void> deleteReward(String rewardId) async {
    final response = await http.delete(
      Uri.parse('$apiBaseUrl/rewards/$rewardId'),
      headers: _authHeaders,
    );

    if (response.statusCode != 204) {
      final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      throw Exception((data['error'] as String?) ?? 'שגיאה במחיקת הפרס');
    }
  }

  Future<List<Redemption>> fetchRedemptions(String childId) async {
    final response = await http.get(
      Uri.parse('$apiBaseUrl/children/$childId/redemptions'),
      headers: _authHeaders,
    );

    if (response.statusCode != 200) {
      throw Exception('שגיאה בטעינת היסטוריית המימושים (${response.statusCode})');
    }

    final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
    return data.map((json) => Redemption.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<int> redeemReward({required String childId, required String rewardId}) async {
    final response = await http.post(
      Uri.parse('$apiBaseUrl/children/$childId/redemptions'),
      headers: _authHeaders,
      body: jsonEncode({'rewardId': rewardId}),
    );

    final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if (response.statusCode != 201) {
      throw Exception((data['error'] as String?) ?? 'שגיאה במימוש הפרס');
    }

    return data['newBalance'] as int;
  }

  Future<List<LearningTask>> fetchLearningTasks() async {
    final response = await http.get(
      Uri.parse('$apiBaseUrl/learning-tasks'),
      headers: _authHeaders,
    );

    if (response.statusCode != 200) {
      throw Exception('שגיאה בטעינת משימות הלימוד (${response.statusCode})');
    }

    final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
    return data.map((json) => LearningTask.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<LearningTask> addLearningTask({
    required String name,
    String? description,
    String? subject,
    int? minAge,
    int? maxAge,
    required int rewardPoints,
  }) async {
    final response = await http.post(
      Uri.parse('$apiBaseUrl/learning-tasks'),
      headers: _authHeaders,
      body: jsonEncode({
        'name': name,
        'description': description,
        'subject': subject,
        'minAge': minAge,
        'maxAge': maxAge,
        'rewardPoints': rewardPoints,
      }),
    );

    final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if (response.statusCode != 201) {
      throw Exception((data['error'] as String?) ?? 'שגיאה בהוספת המשימה');
    }

    return LearningTask.fromJson(data);
  }

  Future<LearningTask> updateLearningTask({
    required String taskId,
    String? name,
    String? subject,
    int? minAge,
    int? maxAge,
    int? rewardPoints,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (subject != null) body['subject'] = subject;
    if (minAge != null) body['minAge'] = minAge;
    if (maxAge != null) body['maxAge'] = maxAge;
    if (rewardPoints != null) body['rewardPoints'] = rewardPoints;

    final response = await http.patch(
      Uri.parse('$apiBaseUrl/learning-tasks/$taskId'),
      headers: _authHeaders,
      body: jsonEncode(body),
    );

    final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception((data['error'] as String?) ?? 'שגיאה בעדכון המשימה');
    }

    return LearningTask.fromJson(data);
  }

  Future<void> deleteLearningTask(String taskId) async {
    final response = await http.delete(
      Uri.parse('$apiBaseUrl/learning-tasks/$taskId'),
      headers: _authHeaders,
    );

    if (response.statusCode != 204) {
      final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      throw Exception((data['error'] as String?) ?? 'שגיאה במחיקת המשימה');
    }
  }

  Future<List<TaskCompletion>> fetchTaskCompletions(String childId) async {
    final response = await http.get(
      Uri.parse('$apiBaseUrl/children/$childId/task-completions'),
      headers: _authHeaders,
    );

    if (response.statusCode != 200) {
      throw Exception('שגיאה בטעינת היסטוריית המשימות (${response.statusCode})');
    }

    final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
    return data.map((json) => TaskCompletion.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<int> completeTask({required String childId, required String taskId}) async {
    final response = await http.post(
      Uri.parse('$apiBaseUrl/children/$childId/task-completions'),
      headers: _authHeaders,
      body: jsonEncode({'taskId': taskId}),
    );

    final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if (response.statusCode != 201) {
      throw Exception((data['error'] as String?) ?? 'שגיאה בסימון המשימה כהושלמה');
    }

    return data['newBalance'] as int;
  }

  Future<void> setChildPin({required String childId, required String pin}) async {
    final response = await http.post(
      Uri.parse('$apiBaseUrl/children/$childId/pin'),
      headers: _authHeaders,
      body: jsonEncode({'pin': pin}),
    );

    if (response.statusCode != 204) {
      final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      throw Exception((data['error'] as String?) ?? 'שגיאה בהגדרת קוד PIN');
    }
  }

  Future<ChildSession> startChildSession({required String childId, required String pin}) async {
    final response = await http.post(
      Uri.parse('$apiBaseUrl/children/$childId/child-session'),
      headers: _authHeaders,
      body: jsonEncode({'pin': pin}),
    );

    final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception((data['error'] as String?) ?? 'קוד PIN שגוי');
    }

    final child = data['child'] as Map<String, dynamic>;
    return ChildSession(
      token: data['token'] as String,
      childId: child['id'] as String,
      childName: child['name'] as String,
    );
  }

  Future<List<SubjectProgress>> fetchSubjectProgress(String childId) async {
    final response = await http.get(
      Uri.parse('$apiBaseUrl/children/$childId/subject-progress'),
      headers: _authHeaders,
    );

    if (response.statusCode != 200) {
      throw Exception('שגיאה בטעינת רמת הלימוד (${response.statusCode})');
    }

    final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
    return data.map((json) => SubjectProgress.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<SubjectProgress> updateSubjectProgress({
    required String childId,
    required String subject,
    required int currentGrade,
    required String currentDifficulty,
  }) async {
    final response = await http.patch(
      Uri.parse('$apiBaseUrl/children/$childId/subject-progress/$subject'),
      headers: _authHeaders,
      body: jsonEncode({'currentGrade': currentGrade, 'currentDifficulty': currentDifficulty}),
    );

    final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception((data['error'] as String?) ?? 'שגיאה בעדכון רמת הלימוד');
    }

    return SubjectProgress.fromJson(data);
  }

  Future<List<QuestionDraft>> fetchQuestionDrafts({String? status}) async {
    final uri = Uri.parse('$apiBaseUrl/question-drafts').replace(
      queryParameters: status != null ? {'status': status} : null,
    );
    final response = await http.get(uri, headers: _authHeaders);

    if (response.statusCode != 200) {
      throw Exception('שגיאה בטעינת השאלות (${response.statusCode})');
    }

    final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
    return data.map((json) => QuestionDraft.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<List<QuestionDraft>> generateQuestionDrafts({
    required String subject,
    required int gradeLevel,
    required String difficulty,
    required int count,
  }) async {
    final response = await http.post(
      Uri.parse('$apiBaseUrl/question-drafts/generate'),
      headers: _authHeaders,
      body: jsonEncode({
        'subject': subject,
        'gradeLevel': gradeLevel,
        'difficulty': difficulty,
        'count': count,
      }),
    );

    if (response.statusCode != 201) {
      final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      throw Exception((data['error'] as String?) ?? 'שגיאה ביצירת השאלות');
    }

    final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
    return data.map((json) => QuestionDraft.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<QuestionDraft> setQuestionDraftApproved({
    required String draftId,
    required bool approved,
  }) async {
    final response = await http.patch(
      Uri.parse('$apiBaseUrl/question-drafts/$draftId'),
      headers: _authHeaders,
      body: jsonEncode({'approved': approved}),
    );

    final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception((data['error'] as String?) ?? 'שגיאה בעדכון השאלה');
    }

    return QuestionDraft.fromJson(data);
  }

  Future<void> deleteQuestionDraft(String draftId) async {
    final response = await http.delete(
      Uri.parse('$apiBaseUrl/question-drafts/$draftId'),
      headers: _authHeaders,
    );

    if (response.statusCode != 204) {
      final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      throw Exception((data['error'] as String?) ?? 'שגיאה במחיקת השאלה');
    }
  }
}
