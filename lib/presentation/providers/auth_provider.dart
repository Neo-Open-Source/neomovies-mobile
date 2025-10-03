import 'package:flutter/material.dart';
import 'package:neomovies_mobile/data/models/user.dart';
import 'package:neomovies_mobile/data/repositories/auth_repository.dart';
import 'package:neomovies_mobile/data/exceptions/auth_exceptions.dart';

enum AuthState { initial, loading, authenticated, unauthenticated, error }

class AuthProvider extends ChangeNotifier {
  AuthProvider({required AuthRepository authRepository})
      : _authRepository = authRepository;

  final AuthRepository _authRepository;

  AuthState _state = AuthState.initial;
  AuthState get state => _state;

  String? _token;
  String? get token => _token;

  // Считаем пользователя аутентифицированным, если состояние AuthState.authenticated
  bool get isAuthenticated => _state == AuthState.authenticated;

  User? _user;
  User? get user => _user;

  String? _error;
  String? get error => _error;

  bool _needsVerification = false;
  bool get needsVerification => _needsVerification;
  String? _pendingEmail;
  String? get pendingEmail => _pendingEmail;

  Future<void> checkAuthStatus() async {
    _state = AuthState.loading;
    notifyListeners();
    try {
      final isLoggedIn = await _authRepository.isLoggedIn();
      if (isLoggedIn) {
        _user = await _authRepository.getCurrentUser();
        _state = AuthState.authenticated;
      } else {
        _state = AuthState.unauthenticated;
      }
    } catch (e) {
      _state = AuthState.unauthenticated;
    }
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    _state = AuthState.loading;
    _error = null;
    _needsVerification = false;
    notifyListeners();
    try {
      await _authRepository.login(email, password);
      _user = await _authRepository.getCurrentUser();
      _state = AuthState.authenticated;
    } catch (e) {
      if (e is UnverifiedAccountException) {
        // Need verification flow
        _needsVerification = true;
        _pendingEmail = e.email;
        _state = AuthState.unauthenticated;
      } else {
        _error = e.toString();
        _state = AuthState.error;
      }
    }
    notifyListeners();
  }

  Future<void> register(String name, String email, String password) async {
    _state = AuthState.loading;
    _error = null;
    notifyListeners();
    try {
      await _authRepository.register(name, email, password);
      // After registration, user needs to verify, so we go to unauthenticated state
      // The UI will navigate to the verify screen
      _state = AuthState.unauthenticated;
    } catch (e) {
      _error = e.toString();
      _state = AuthState.error;
    }
    notifyListeners();
  }

  Future<void> verifyEmail(String email, String code) async {
    _state = AuthState.loading;
    _error = null;
    notifyListeners();
    try {
      await _authRepository.verifyEmail(email, code);
      // Auto-login after successful verification
      _user = await _authRepository.getCurrentUser();
      _state = AuthState.authenticated;
    } catch (e) {
      _error = e.toString();
      _state = AuthState.error;
    }
    notifyListeners();
  }

  Future<void> logout() async {
    _state = AuthState.loading;
    notifyListeners();
    await _authRepository.logout();
    _user = null;
    _state = AuthState.unauthenticated;
    notifyListeners();
  }

  Future<void> deleteAccount() async {
    _state = AuthState.loading;
    notifyListeners();
    try {
      await _authRepository.deleteAccount();
      _user = null;
      _state = AuthState.unauthenticated;
    } catch (e) {
      _error = e.toString();
      _state = AuthState.error;
    }
    notifyListeners();
  }

  /// Reset pending verification state after navigating to VerifyScreen
  void clearVerificationFlag() {
    _needsVerification = false;
    _pendingEmail = null;
    notifyListeners();
  }
}
