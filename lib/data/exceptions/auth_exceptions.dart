class UnverifiedAccountException implements Exception {
  final String email;
  final String? message;

  UnverifiedAccountException(this.email, {this.message});

  @override
  String toString() => message ?? 'Account not verified';
}
