import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:neomovies_mobile/data/api/api_client.dart';
import 'package:neomovies_mobile/data/models/user.dart';
import 'package:neomovies_mobile/data/services/secure_storage_service.dart';
import 'package:neomovies_mobile/data/exceptions/auth_exceptions.dart';

class AuthRepository {
  final ApiClient _apiClient;
  final SecureStorageService _storageService;

  AuthRepository({
    required ApiClient apiClient,
    required SecureStorageService storageService,
  })  : _apiClient = apiClient,
        _storageService = storageService;

  Future<void> login(String email, String password) async {
    final response = await _apiClient.login(email, password);
    if (!response.verified) {
      throw UnverifiedAccountException(email, message: 'Account not verified');
    }
    await _storageService.saveToken(response.token);
    await _storageService.saveUserData(
      name: response.user.name,
      email: response.user.email,
    );
  }

  Future<void> register(String name, String email, String password) async {
    // Registration does not automatically log in the user in this flow.
    // It sends a verification code.
    await _apiClient.register(name, email, password);
  }

  Future<void> verifyEmail(String email, String code) async {
    final response = await _apiClient.verify(email, code);
    // Auto-login user after successful verification
    await _storageService.saveToken(response.token);
    await _storageService.saveUserData(
      name: response.user.name,
      email: response.user.email,
    );
  }

  Future<void> resendVerificationCode(String email) async {
    await _apiClient.resendCode(email);
  }

  Future<void> logout() async {
    await _storageService.deleteAll();
  }

  Future<void> deleteAccount() async {
    // The AuthenticatedHttpClient will handle the token.
    await _apiClient.deleteAccount();
    await _storageService.deleteAll();
  }

  Future<bool> isLoggedIn() async {
    final token = await _storageService.getToken();
    return token != null;
  }

  Future<User?> getCurrentUser() async {
    final isLoggedIn = await this.isLoggedIn();
    if (!isLoggedIn) return null;

    final userData = await _storageService.getUserData();
    if (userData['name'] == null || userData['email'] == null) {
      return null;
    }

    // The User model requires an ID, which we don't have in storage.
    // For the profile screen, we only need name and email.
    // We'll create a User object with a placeholder ID.
    return User(id: 'local', name: userData['name']!, email: userData['email']!);
  }
}
