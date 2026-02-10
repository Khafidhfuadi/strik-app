class UserModel {
  final String id;
  final String? username;
  final String? avatarUrl;
  final DateTime createdAt;
  final int xp;
  final int level;

  UserModel({
    required this.id,
    this.username,
    this.avatarUrl,
    required this.createdAt,
    this.xp = 0,
    this.level = 1,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      username: json['username'],
      avatarUrl: json['avatar_url'],
      createdAt: DateTime.parse(json['created_at']).toLocal(),
      xp: json['xp'] ?? 0,
      level: json['level'] ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'avatar_url': avatarUrl,
      'created_at': createdAt.toIso8601String(),
      'xp': xp,
      'level': level,
    };
  }

  UserModel copyWith({
    String? id,
    String? username,
    String? avatarUrl,
    DateTime? createdAt,
    int? xp,
    int? level,
  }) {
    return UserModel(
      id: id ?? this.id,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt ?? this.createdAt,
      xp: xp ?? this.xp,
      level: level ?? this.level,
    );
  }
}
