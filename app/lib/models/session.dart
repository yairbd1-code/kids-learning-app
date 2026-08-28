class ParentInfo {
  final String id;
  final String name;
  final String email;

  ParentInfo({required this.id, required this.name, required this.email});

  factory ParentInfo.fromJson(Map<String, dynamic> json) {
    return ParentInfo(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
    );
  }
}

class FamilyInfo {
  final String id;
  final String name;

  FamilyInfo({required this.id, required this.name});

  factory FamilyInfo.fromJson(Map<String, dynamic> json) {
    return FamilyInfo(id: json['id'] as String, name: json['name'] as String);
  }
}
