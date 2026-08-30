import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart' show apiBaseUrl;

class ChildProfile {
  final String id;
  final String name;
  final String themeId;
  final String? photoUrl;

  ChildProfile({required this.id, required this.name, required this.themeId, this.photoUrl});

  factory ChildProfile.fromJson(Map<String, dynamic> json) {
    return ChildProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      themeId: json['themeId'] as String,
      photoUrl: json['photoUrl'] as String?,
    );
  }
}

class ChildProfileService {
  final String childToken;

  ChildProfileService(this.childToken);

  Map<String, String> get _headers => {
        'Content-Type': 'application/json; charset=utf-8',
        'Authorization': 'Bearer $childToken',
      };

  Future<ChildProfile> fetchProfile() async {
    final response = await http.get(Uri.parse('$apiBaseUrl/me'), headers: _headers);

    if (response.statusCode != 200) {
      throw Exception('שגיאה בטעינת הפרופיל (${response.statusCode})');
    }

    return ChildProfile.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
  }

  Future<ChildProfile> updateTheme(String themeId) async {
    final response = await http.patch(
      Uri.parse('$apiBaseUrl/me'),
      headers: _headers,
      body: jsonEncode({'themeId': themeId}),
    );

    final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception((data['error'] as String?) ?? 'שגיאה בעדכון הצבע');
    }

    return ChildProfile.fromJson(data);
  }
}
