import 'package:neomovies_mobile/data/models/user.dart';

class AuthResponse {
  final String token;
  final User user;
  final bool verified;

  AuthResponse({required this.token, required this.user, required this.verified});

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      token: json['token'] as String,
      user: User.fromJson(json['user'] as Map<String, dynamic>),
      verified: (json['verified'] as bool?) ?? (json['user']?['verified'] as bool? ?? true),
    );
  }
}
