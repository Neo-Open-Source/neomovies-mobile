import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  const SecureStorageService(this._storage);

  final FlutterSecureStorage _storage;

  Future<void> saveToken(String token) async {
    await _storage.write(key: 'auth_token', value: token);
  }

  Future<String?> getToken() async {
    return await _storage.read(key: 'auth_token');
  }

  Future<void> deleteToken() async {
    await _storage.delete(key: 'auth_token');
  }

  Future<void> saveUserData({required String name, required String email}) async {
    await _storage.write(key: 'user_name', value: name);
    await _storage.write(key: 'user_email', value: email);
  }

  Future<Map<String, String?>> getUserData() async {
    final name = await _storage.read(key: 'user_name');
    final email = await _storage.read(key: 'user_email');
    return {'name': name, 'email': email};
  }

  Future<void> deleteAll() async {
    await _storage.deleteAll();
  }
}
