import 'package:neomovies_mobile/data/models/user.dart';

class AuthResponse {
  final String token;
  final User user;
  final bool verified;

  AuthResponse({required this.token, required this.user, required this.verified});

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    // Handle wrapped response with "data" field
    final data = json['data'] ?? json;
    
    return AuthResponse(
      token: data['token'] as String,
      user: User.fromJson(data['user'] as Map<String, dynamic>),
      verified: (data['verified'] as bool?) ?? (data['user']?['verified'] as bool? ?? true),
    );
  }
}
