import 'package:flutter/material.dart';
import 'package:neomovies_mobile/data/repositories/reactions_repository.dart';
import 'package:neomovies_mobile/presentation/providers/auth_provider.dart';

class ReactionsProvider with ChangeNotifier {
  final ReactionsRepository _repository;
  final AuthProvider _authProvider;

  ReactionsProvider(this._repository, this._authProvider) {
    _authProvider.addListener(_onAuthChanged);
  }

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  Map<String, int> _reactionCounts = {};
  Map<String, int> get reactionCounts => _reactionCounts;

  String? _userReaction;
  String? get userReaction => _userReaction;

  String? _currentMediaId;
  String? _currentMediaType;

  void _onAuthChanged() {
    // If user logs out, clear their specific reaction data
    if (!_authProvider.isAuthenticated) {
      _userReaction = null;
      // We can keep the public reaction counts loaded
      notifyListeners();
    }
  }

  Future<void> loadReactionsForMedia(String mediaType, String mediaId) async {
    if (_currentMediaId == mediaId && _currentMediaType == mediaType) return; // Already loaded
    
    _currentMediaId = mediaId;
    _currentMediaType = mediaType;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _reactionCounts = await _repository.getReactionCounts(mediaType, mediaId);

      if (_authProvider.isAuthenticated) {
        final userReactionResult = await _repository.getMyReaction(mediaType, mediaId);
        _userReaction = userReactionResult?.reactionType;
      } else {
        _userReaction = null;
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setReaction(String mediaType, String mediaId, String reactionType) async {
    if (!_authProvider.isAuthenticated) {
      _error = 'User not authenticated';
      notifyListeners();
      return;
    }

    final previousReaction = _userReaction;
    final previousCounts = Map<String, int>.from(_reactionCounts);

    // Optimistic UI update
    if (_userReaction == reactionType) {
      // User is deselecting their reaction - send empty string to remove
      _userReaction = null;
      _reactionCounts[reactionType] = (_reactionCounts[reactionType] ?? 1) - 1;
      reactionType = '';
    } else {
      // User is selecting a new or different reaction
      if (_userReaction != null) {
        _reactionCounts[_userReaction!] = (_reactionCounts[_userReaction!] ?? 1) - 1;
      }
      _userReaction = reactionType;
      _reactionCounts[reactionType] = (_reactionCounts[reactionType] ?? 0) + 1;
    }
    notifyListeners();

    try {
      await _repository.setReaction(mediaType, mediaId, reactionType);
    } catch (e) {
      // Revert on error
      _error = e.toString();
      _userReaction = previousReaction;
      _reactionCounts = previousCounts;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _authProvider.removeListener(_onAuthChanged);
    super.dispose();
  }
}
