import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:neomovies_mobile/data/models/player/video_source.dart';

class SettingsProvider with ChangeNotifier {
  static const String _settingsKey = 'player_settings';
  
  late PlayerSettings _settings;
  final SharedPreferences _prefs;
  
  SettingsProvider(this._prefs) {
    // Load settings from shared preferences
    _loadSettings();
  }
  
  PlayerSettings get settings => _settings;
  
  // Load settings from shared preferences
  void _loadSettings() {
    try {
      final settingsJson = _prefs.getString(_settingsKey);
      if (settingsJson != null) {
        _settings = PlayerSettings.fromMap(
          Map<String, dynamic>.from(settingsJson as Map),
        );
      } else {
        // Use default settings if no saved settings exist
        _settings = PlayerSettings.defaultSettings();
        // Save default settings
        _saveSettings();
      }
    } catch (e) {
      debugPrint('Error loading player settings: $e');
      // Fallback to default settings on error
      _settings = PlayerSettings.defaultSettings();
    }
  }
  
  // Save settings to shared preferences
  Future<void> _saveSettings() async {
    try {
      await _prefs.setString(
        _settingsKey,
        _settings.toMap().toString(),
      );
    } catch (e) {
      debugPrint('Error saving player settings: $e');
    }
  }
  
  // Update and save settings
  Future<void> updateSettings(PlayerSettings newSettings) async {
    if (_settings == newSettings) return;
    
    _settings = newSettings;
    await _saveSettings();
    notifyListeners();
  }
  
  // Individual setting updates
  
  // Video settings
  Future<void> setAutoPlay(bool value) async {
    if (_settings.autoPlay == value) return;
    _settings = _settings.copyWith(autoPlay: value);
    await _saveSettings();
    notifyListeners();
  }
  
  Future<void> setAutoPlayNextEpisode(bool value) async {
    if (_settings.autoPlayNextEpisode == value) return;
    _settings = _settings.copyWith(autoPlayNextEpisode: value);
    await _saveSettings();
    notifyListeners();
  }
  
  Future<void> setSkipIntro(bool value) async {
    if (_settings.skipIntro == value) return;
    _settings = _settings.copyWith(skipIntro: value);
    await _saveSettings();
    notifyListeners();
  }
  
  Future<void> setSkipCredits(bool value) async {
    if (_settings.skipCredits == value) return;
    _settings = _settings.copyWith(skipCredits: value);
    await _saveSettings();
    notifyListeners();
  }
  
  Future<void> setRememberPlaybackPosition(bool value) async {
    if (_settings.rememberPlaybackPosition == value) return;
    _settings = _settings.copyWith(rememberPlaybackPosition: value);
    await _saveSettings();
    notifyListeners();
  }
  
  Future<void> setPlaybackSpeed(double value) async {
    if (_settings.playbackSpeed == value) return;
    _settings = _settings.copyWith(playbackSpeed: value);
    await _saveSettings();
    notifyListeners();
  }
  
  // Subtitle settings
  Future<void> setDefaultSubtitleLanguage(String language) async {
    if (_settings.defaultSubtitleLanguage == language) return;
    _settings = _settings.copyWith(defaultSubtitleLanguage: language);
    await _saveSettings();
    notifyListeners();
  }
  
  Future<void> setSubtitleSize(double size) async {
    if (_settings.subtitleSize == size) return;
    _settings = _settings.copyWith(subtitleSize: size);
    await _saveSettings();
    notifyListeners();
  }
  
  Future<void> setSubtitleTextColor(String color) async {
    if (_settings.subtitleTextColor == color) return;
    _settings = _settings.copyWith(subtitleTextColor: color);
    await _saveSettings();
    notifyListeners();
  }
  
  Future<void> setSubtitleBackgroundColor(String color) async {
    if (_settings.subtitleBackgroundColor == color) return;
    _settings = _settings.copyWith(subtitleBackgroundColor: color);
    await _saveSettings();
    notifyListeners();
  }
  
  Future<void> setSubtitleBackgroundEnabled(bool enabled) async {
    if (_settings.subtitleBackgroundEnabled == enabled) return;
    _settings = _settings.copyWith(subtitleBackgroundEnabled: enabled);
    await _saveSettings();
    notifyListeners();
  }
  
  // Playback settings
  Future<void> setDefaultQualityIndex(int index) async {
    if (_settings.defaultQualityIndex == index) return;
    _settings = _settings.copyWith(defaultQualityIndex: index);
    await _saveSettings();
    notifyListeners();
  }
  
  Future<void> setDataSaverMode(bool enabled) async {
    if (_settings.dataSaverMode == enabled) return;
    _settings = _settings.copyWith(dataSaverMode: enabled);
    await _saveSettings();
    notifyListeners();
  }
  
  Future<void> setDownloadOverWifiOnly(bool enabled) async {
    if (_settings.downloadOverWifiOnly == enabled) return;
    _settings = _settings.copyWith(downloadOverWifiOnly: enabled);
    await _saveSettings();
    notifyListeners();
  }
  
  // Player UI settings
  Future<void> setShowControlsOnStart(bool show) async {
    if (_settings.showControlsOnStart == show) return;
    _settings = _settings.copyWith(showControlsOnStart: show);
    await _saveSettings();
    notifyListeners();
  }
  
  Future<void> setDoubleTapToSeek(bool enabled) async {
    if (_settings.doubleTapToSeek == enabled) return;
    _settings = _settings.copyWith(doubleTapToSeek: enabled);
    await _saveSettings();
    notifyListeners();
  }
  
  Future<void> setSwipeToSeek(bool enabled) async {
    if (_settings.swipeToSeek == enabled) return;
    _settings = _settings.copyWith(swipeToSeek: enabled);
    await _saveSettings();
    notifyListeners();
  }
  
  Future<void> setShowRemainingTime(bool show) async {
    if (_settings.showRemainingTime == show) return;
    _settings = _settings.copyWith(showRemainingTime: show);
    await _saveSettings();
    notifyListeners();
  }
  
  // Default video source
  Future<void> setDefaultSource(VideoSource source) async {
    _settings = _settings.copyWith(defaultSource: source);
    await _saveSettings();
    notifyListeners();
  }
  
  // Reset all settings to default
  Future<void> resetToDefaults() async {
    _settings = PlayerSettings.defaultSettings();
    await _saveSettings();
    notifyListeners();
  }
  
  // Clear all settings
  Future<void> clear() async {
    await _prefs.remove(_settingsKey);
    _settings = PlayerSettings.defaultSettings();
    notifyListeners();
  }
}
