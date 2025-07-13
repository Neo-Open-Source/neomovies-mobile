import 'package:http/http.dart' as http;
import 'package:neomovies_mobile/data/services/secure_storage_service.dart';

class AuthenticatedHttpClient extends http.BaseClient {
  final http.Client _inner;
  final SecureStorageService _storageService;

  AuthenticatedHttpClient(this._storageService, this._inner);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final token = await _storageService.getToken();
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.headers['Content-Type'] = 'application/json';
    return _inner.send(request);
  }
}
