class User {
  final int id;
  final String name;
  final String email;
  final String? avatarUrl;
  final Map<String, dynamic>? preferences;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl,
    this.preferences,
  });

  /// Someone using the app without an account: data stays on the device.
  factory User.local() => User(id: 0, name: 'You', email: '');

  bool get isLocal => id == 0;

  factory User.fromJson(Map<String, dynamic> json) {
    final preferences = json['preferences'];
    return User(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      avatarUrl: json['avatar_url'],
      preferences: preferences is Map
          ? Map<String, dynamic>.from(preferences)
          : null,
    );
  }

  User copyWith({String? avatarUrl}) {
    return User(
      id: id,
      name: name,
      email: email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      preferences: preferences,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'avatar_url': avatarUrl,
      'preferences': preferences,
    };
  }
}
