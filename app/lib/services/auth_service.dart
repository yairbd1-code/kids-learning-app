import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// כתובת שרת ה-production, מוזרקת רק בזמן build עם:
// flutter build web --dart-define=API_BASE_URL=https://kids-learning-backend-l2ts.onrender.com
// כשזה ריק (ברירת המחדל, כמו ב-flutter run הרגיל בפיתוח) חוזרים לכתובת
// המקומית - כך שאין צורך לגעת בקוד בין עבודה מקומית לבנייה אמיתית.
const String _prodApiBaseUrl = String.fromEnvironment('API_BASE_URL');

// באמולטור אנדרואיד "localhost" מצביע על המכשיר הווירטואלי עצמו, לא על
// המחשב המארח - 10.0.2.2 הוא הכתובת המיוחדת שהאמולטור מספק לגישה למארח.
String get apiBaseUrl {
  if (_prodApiBaseUrl.isNotEmpty) return _prodApiBaseUrl;
  if (kIsWeb) return 'http://localhost:3000';
  if (defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.2.2:3000';
  return 'http://localhost:3000';
}

const String _tokenPrefsKey = 'auth_token';

class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}

class ProfileInfo {
  final String parentName;
  final String email;
  final String familyName;
  final String joinCode;

  ProfileInfo({
    required this.parentName,
    required this.email,
    required this.familyName,
    required this.joinCode,
  });

  factory ProfileInfo.fromJson(Map<String, dynamic> json) {
    final parent = json['parent'] as Map<String, dynamic>;
    final family = json['family'] as Map<String, dynamic>;
    return ProfileInfo(
      parentName: parent['name'] as String,
      email: parent['email'] as String,
      familyName: family['name'] as String,
      joinCode: family['joinCode'] as String,
    );
  }
}

class FamilyMember {
  final String id;
  final String name;
  final String email;
  final String authProvider;

  FamilyMember({
    required this.id,
    required this.name,
    required this.email,
    required this.authProvider,
  });

  factory FamilyMember.fromJson(Map<String, dynamic> json) {
    return FamilyMember(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      authProvider: json['authProvider'] as String,
    );
  }
}

class AuthService {
  String? _token;

  String? get token => _token;

  Future<bool> hasValidSession() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenPrefsKey);
    if (_token == null) return false;

    final response = await http.get(
      Uri.parse('$apiBaseUrl/auth/me'),
      headers: {'Authorization': 'Bearer $_token'},
    );

    if (response.statusCode == 200) return true;

    await logout();
    return false;
  }

  Future<void> _saveToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenPrefsKey, token);
  }

  Future<void> logout() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenPrefsKey);
  }

  Future<void> register({
    required String familyName,
    required String parentName,
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$apiBaseUrl/auth/register'),
      headers: {'Content-Type': 'application/json; charset=utf-8'},
      body: jsonEncode({
        'familyName': familyName,
        'parentName': parentName,
        'email': email,
        'password': password,
      }),
    );

    final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if (response.statusCode != 201) {
      throw AuthException((data['error'] as String?) ?? 'שגיאה בהרשמה');
    }
    await _saveToken(data['token'] as String);
  }

  Future<void> joinFamily({
    required String joinCode,
    required String parentName,
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$apiBaseUrl/auth/join'),
      headers: {'Content-Type': 'application/json; charset=utf-8'},
      body: jsonEncode({
        'joinCode': joinCode,
        'parentName': parentName,
        'email': email,
        'password': password,
      }),
    );

    final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if (response.statusCode != 201) {
      throw AuthException((data['error'] as String?) ?? 'שגיאה בהצטרפות למשפחה');
    }
    await _saveToken(data['token'] as String);
  }

  Future<List<FamilyMember>> fetchFamilyMembers() async {
    final response = await http.get(
      Uri.parse('$apiBaseUrl/auth/family-members'),
      headers: {'Authorization': 'Bearer $_token'},
    );

    if (response.statusCode != 200) {
      throw AuthException('שגיאה בטעינת רשימת ההורים');
    }
    final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
    return data.map((json) => FamilyMember.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<void> login({required String email, required String password}) async {
    final response = await http.post(
      Uri.parse('$apiBaseUrl/auth/login'),
      headers: {'Content-Type': 'application/json; charset=utf-8'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw AuthException((data['error'] as String?) ?? 'שגיאה בהתחברות');
    }
    await _saveToken(data['token'] as String);
  }

  Future<void> loginWithGoogle(String googleIdToken) async {
    final response = await http.post(
      Uri.parse('$apiBaseUrl/auth/google'),
      headers: {'Content-Type': 'application/json; charset=utf-8'},
      body: jsonEncode({'idToken': googleIdToken}),
    );

    final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw AuthException((data['error'] as String?) ?? 'שגיאה בהתחברות עם Google');
    }
    await _saveToken(data['token'] as String);
  }

  Future<ProfileInfo> fetchProfile() async {
    final response = await http.get(
      Uri.parse('$apiBaseUrl/auth/me'),
      headers: {'Authorization': 'Bearer $_token'},
    );

    final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw AuthException((data['error'] as String?) ?? 'שגיאה בטעינת הפרופיל');
    }
    return ProfileInfo.fromJson(data);
  }

  Future<ProfileInfo> updateProfile({
    String? parentName,
    String? familyName,
    String? currentPassword,
    String? newPassword,
  }) async {
    final body = <String, dynamic>{};
    if (parentName != null) body['name'] = parentName;
    if (familyName != null) body['familyName'] = familyName;
    if (currentPassword != null) body['currentPassword'] = currentPassword;
    if (newPassword != null) body['newPassword'] = newPassword;

    final response = await http.patch(
      Uri.parse('$apiBaseUrl/auth/me'),
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
        'Authorization': 'Bearer $_token',
      },
      body: jsonEncode(body),
    );

    final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw AuthException((data['error'] as String?) ?? 'שגיאה בעדכון הפרופיל');
    }
    return ProfileInfo.fromJson(data);
  }
}
