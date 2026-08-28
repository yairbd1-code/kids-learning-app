import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/reward.dart';
import '../models/redemption.dart';
import 'auth_service.dart' show apiBaseUrl;

class ChildStoreService {
  final String childToken;

  ChildStoreService(this.childToken);

  Map<String, String> get _headers => {
        'Content-Type': 'application/json; charset=utf-8',
        'Authorization': 'Bearer $childToken',
      };

  Future<int> fetchBalance() async {
    final response = await http.get(Uri.parse('$apiBaseUrl/store/balance'), headers: _headers);

    if (response.statusCode != 200) {
      throw Exception('שגיאה בטעינת היתרה (${response.statusCode})');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return data['balance'] as int;
  }

  Future<List<Reward>> fetchRewards() async {
    final response = await http.get(Uri.parse('$apiBaseUrl/store/rewards'), headers: _headers);

    if (response.statusCode != 200) {
      throw Exception('שגיאה בטעינת חנות הפרסים (${response.statusCode})');
    }

    final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
    return data.map((json) => Reward.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<List<Redemption>> fetchMyRedemptions() async {
    final response =
        await http.get(Uri.parse('$apiBaseUrl/store/redemptions'), headers: _headers);

    if (response.statusCode != 200) {
      throw Exception('שגיאה בטעינת הבקשות שלי (${response.statusCode})');
    }

    final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
    return data.map((json) => Redemption.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<Redemption> requestRedemption(String rewardId) async {
    final response = await http.post(
      Uri.parse('$apiBaseUrl/store/redemptions'),
      headers: _headers,
      body: jsonEncode({'rewardId': rewardId}),
    );

    final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if (response.statusCode != 201) {
      throw Exception((data['error'] as String?) ?? 'שגיאה בשליחת הבקשה');
    }

    return Redemption.fromJson(data);
  }
}
