import 'package:neomovies_mobile/data/api/api_client.dart';
import 'package:neomovies_mobile/data/models/favorite.dart';

class FavoritesRepository {
  final ApiClient _apiClient;

  FavoritesRepository(this._apiClient);

  Future<List<Favorite>> getFavorites() async {
    return await _apiClient.getFavorites();
  }

  Future<void> addFavorite(String mediaId, String mediaType, String title, String posterPath) async {
    await _apiClient.addFavorite(mediaId, mediaType, title, posterPath);
  }

  Future<void> removeFavorite(String mediaId) async {
    await _apiClient.removeFavorite(mediaId);
  }
}
