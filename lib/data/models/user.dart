class User {
  final String id;
  final String name;
  final String email;
  final bool verified;

  User({
    required this.id, 
    required this.name, 
    required this.email,
    this.verified = true,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: (json['_id'] ?? json['id'] ?? '') as String,
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      verified: json['verified'] as bool? ?? true,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'email': email,
      'verified': verified,
    };
  }
}
