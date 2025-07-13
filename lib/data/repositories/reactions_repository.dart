import 'package:neomovies_mobile/data/api/api_client.dart';
import 'package:neomovies_mobile/data/models/reaction.dart';

class ReactionsRepository {
  final ApiClient _apiClient;

  ReactionsRepository(this._apiClient);

  Future<Map<String,int>> getReactionCounts(String mediaType,String mediaId) async {
    return await _apiClient.getReactionCounts(mediaType, mediaId);
  }

  Future<UserReaction> getMyReaction(String mediaType,String mediaId) async {
    return await _apiClient.getMyReaction(mediaType, mediaId);
  }

  Future<void> setReaction(String mediaType,String mediaId, String reactionType) async {
    await _apiClient.setReaction(mediaType, mediaId, reactionType);
  }
}
