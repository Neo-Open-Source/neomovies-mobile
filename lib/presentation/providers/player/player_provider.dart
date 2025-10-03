import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:neomovies_mobile/data/models/player/video_source.dart';
import 'package:neomovies_mobile/data/models/player/video_quality.dart';
import 'package:neomovies_mobile/data/models/player/audio_track.dart';
import 'package:neomovies_mobile/data/models/player/subtitle.dart' as local_subtitle;
import 'package:neomovies_mobile/data/models/player/player_settings.dart';

class PlayerProvider with ChangeNotifier {
  // Controller instances
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  
  // Player state
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _isBuffering = false;
  bool _isFullScreen = false;
  bool _showControls = true;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  
  // Media info
  String? _mediaId;
  String? _mediaType;
  String? _title;
  String? _subtitle;
  String? _posterUrl;
  
  // Player settings
  PlayerSettings _settings;
  
  // Available options
  List<VideoSource> _sources = [];
  List<VideoQuality> _qualities = [];
  List<AudioTrack> _audioTracks = [];
  List<local_subtitle.Subtitle> _subtitles = [];
  
  // Selected options
  VideoSource? _selectedSource;
  VideoQuality? _selectedQuality;
  AudioTrack? _selectedAudioTrack;
  local_subtitle.Subtitle? _selectedSubtitle;
  
  // Playback state
  double _volume = 1.0;
  bool _isMuted = false;
  double _playbackSpeed = 1.0;
  
  // Getters
  bool get isInitialized => _isInitialized;
  bool get isPlaying => _isPlaying;
  bool get isBuffering => _isBuffering;
  bool get isFullScreen => _isFullScreen;
  bool get showControls => _showControls;
  Duration get position => _position;
  Duration get duration => _duration;
  String? get mediaId => _mediaId;
  String? get mediaType => _mediaType;
  String? get title => _title;
  String? get subtitle => _subtitle;
  String? get posterUrl => _posterUrl;
  PlayerSettings get settings => _settings;
  List<VideoSource> get sources => _sources;
  List<VideoQuality> get qualities => _qualities;
  List<AudioTrack> get audioTracks => _audioTracks;
  List<local_subtitle.Subtitle> get subtitles => _subtitles;
  VideoSource? get selectedSource => _selectedSource;
  VideoQuality? get selectedQuality => _selectedQuality;
  AudioTrack? get selectedAudioTrack => _selectedAudioTrack;
  local_subtitle.Subtitle? get selectedSubtitle => _selectedSubtitle;
  double get volume => _volume;
  bool get isMuted => _isMuted;
  double get playbackSpeed => _playbackSpeed;
  
  // Controllers
  VideoPlayerController? get videoPlayerController => _videoPlayerController;
  ChewieController? get chewieController => _chewieController;
  
  // Constructor
  PlayerProvider({PlayerSettings? initialSettings}) 
      : _settings = initialSettings ?? PlayerSettings.defaultSettings();
  
  // Initialize the player with media
  Future<void> initialize({
    required String mediaId,
    required String mediaType,
    String? title,
    String? subtitle,
    String? posterUrl,
    List<VideoSource>? sources,
    List<VideoQuality>? qualities,
    List<AudioTrack>? audioTracks,
    List<local_subtitle.Subtitle>? subtitles,
  }) async {
    _mediaId = mediaId;
    _mediaType = mediaType;
    _title = title;
    _subtitle = subtitle;
    _posterUrl = posterUrl;
    
    // Set available options
    _sources = sources ?? [];
    _qualities = qualities ?? VideoQuality.defaultQualities;
    _audioTracks = audioTracks ?? [];
    _subtitles = subtitles ?? [];
    
    // Set default selections
    _selectedSource = _sources.isNotEmpty ? _sources.first : null;
    _selectedQuality = _qualities.isNotEmpty ? _qualities.first : null;
    _selectedAudioTrack = _audioTracks.isNotEmpty ? _audioTracks.first : null;
    _selectedSubtitle = _subtitles.firstWhere(
      (s) => s.id == 'none',
      orElse: () => _subtitles.first,
    );
    
    // Initialize video player with the first source and quality
    if (_selectedSource != null && _selectedQuality != null) {
      await _initializeVideoPlayer();
    }
    
    _isInitialized = true;
    notifyListeners();
  }
  
  // Initialize video player with current source and quality
  Future<void> _initializeVideoPlayer() async {
    if (_selectedSource == null || _selectedQuality == null) return;
    
    // Dispose of previous controllers if they exist
    await dispose();
    
    try {
      // In a real app, you would fetch the actual video URL based on source and quality
      final videoUrl = _getVideoUrl(_selectedSource!, _selectedQuality!);
      
      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(videoUrl),
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: true,
        ),
      );
      
      await _videoPlayerController!.initialize();
      
      // Setup position listener
      _videoPlayerController!.addListener(_videoPlayerListener);
      
      // Setup chewie controller
      _setupChewieController();
      
      // Start playing if autoplay is enabled
      if (_settings.autoPlay) {
        await _videoPlayerController!.play();
        _isPlaying = true;
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing video player: $e');
      // Handle error appropriately
      rethrow;
    }
  }
  
  // Setup Chewie controller with custom options
  void _setupChewieController() {
    _chewieController = ChewieController(
      videoPlayerController: _videoPlayerController!,
      autoPlay: _settings.autoPlay,
      looping: false,
      allowFullScreen: true,
      allowMuting: true,
      allowPlaybackSpeedChanging: true,
      showControls: _settings.showControlsOnStart,
      showControlsOnInitialize: _settings.showControlsOnStart,
      placeholder: _posterUrl != null ? Image.network(_posterUrl!) : null,
      aspectRatio: _videoPlayerController!.value.aspectRatio,
      // Custom options can be added here
    );
    
    // Listen to Chewie events
    _chewieController!.addListener(() {
      if (_chewieController!.isFullScreen != _isFullScreen) {
        _isFullScreen = _chewieController!.isFullScreen;
        notifyListeners();
      }
      
      if (_chewieController!.isPlaying != _isPlaying) {
        _isPlaying = _chewieController!.isPlaying;
        notifyListeners();
      }
    });
  }
  
  // Video player listener
  void _videoPlayerListener() {
    if (!_videoPlayerController!.value.isInitialized) return;
    
    final controller = _videoPlayerController!;
    
    // Update buffering state
    final isBuffering = controller.value.isBuffering;
    if (_isBuffering != isBuffering) {
      _isBuffering = isBuffering;
      notifyListeners();
    }
    
    // Update position and duration
    if (controller.value.duration != _duration) {
      _duration = controller.value.duration;
    }
    
    if (controller.value.position != _position) {
      _position = controller.value.position;
      notifyListeners();
    }
  }
  
  // Get video URL based on source and quality
  // In a real app, this would make an API call to get the stream URL
  String _getVideoUrl(VideoSource source, VideoQuality quality) {
    // This is a placeholder - replace with actual logic to get the video URL
    return 'https://example.com/stream/$mediaType/$mediaId?source=${source.name.toLowerCase()}&quality=${quality.name}';
  }
  
  // Toggle play/pause
  Future<void> togglePlayPause() async {
    if (_videoPlayerController == null) return;
    
    if (_isPlaying) {
      await _videoPlayerController!.pause();
    } else {
      await _videoPlayerController!.play();
    }
    
    _isPlaying = !_isPlaying;
    notifyListeners();
  }
  
  // Seek to a specific position
  Future<void> seekTo(Duration position) async {
    if (_videoPlayerController == null) return;
    
    await _videoPlayerController!.seekTo(position);
    _position = position;
    notifyListeners();
  }
  
  // Set volume (0.0 to 1.0)
  Future<void> setVolume(double volume) async {
    if (_videoPlayerController == null) return;
    
    _volume = volume.clamp(0.0, 1.0);
    await _videoPlayerController!.setVolume(_isMuted ? 0.0 : _volume);
    notifyListeners();
  }
  
  // Toggle mute
  Future<void> toggleMute() async {
    if (_videoPlayerController == null) return;
    
    _isMuted = !_isMuted;
    await _videoPlayerController!.setVolume(_isMuted ? 0.0 : _volume);
    notifyListeners();
  }
  
  // Set playback speed
  Future<void> setPlaybackSpeed(double speed) async {
    if (_videoPlayerController == null) return;
    
    _playbackSpeed = speed;
    await _videoPlayerController!.setPlaybackSpeed(speed);
    notifyListeners();
  }
  
  // Change video source
  Future<void> setSource(VideoSource source) async {
    if (_selectedSource == source) return;
    
    _selectedSource = source;
    await _initializeVideoPlayer();
    notifyListeners();
  }
  
  // Change video quality
  Future<void> setQuality(VideoQuality quality) async {
    if (_selectedQuality == quality) return;
    
    _selectedQuality = quality;
    await _initializeVideoPlayer();
    notifyListeners();
  }
  
  // Change audio track
  void setAudioTrack(AudioTrack track) {
    if (_selectedAudioTrack == track) return;
    
    _selectedAudioTrack = track;
    // In a real implementation, you would update the audio track on the video player
    notifyListeners();
  }
  
  // Change subtitle
  void setSubtitle(local_subtitle.Subtitle subtitle) {
    if (_selectedSubtitle == subtitle) return;
    
    _selectedSubtitle = subtitle;
    // In a real implementation, you would update the subtitle on the video player
    notifyListeners();
  }
  
  // Toggle fullscreen
  void toggleFullScreen() {
    if (_chewieController == null) return;
    
    _isFullScreen = !_isFullScreen;
    if (_isFullScreen) {
      _chewieController!.enterFullScreen();
    } else {
      _chewieController!.exitFullScreen();
    }
    
    notifyListeners();
  }
  
  // Toggle controls visibility
  void toggleControls() {
    _showControls = !_showControls;
    notifyListeners();
  }
  
  // Update player settings
  void updateSettings(PlayerSettings newSettings) {
    _settings = newSettings;
    
    // Apply settings that affect the current playback
    if (_videoPlayerController != null) {
      _videoPlayerController!.setPlaybackSpeed(_settings.playbackSpeed);
      // Apply other settings as needed
    }
    
    notifyListeners();
  }
  
  // Clean up resources
  @override
  Future<void> dispose() async {
    _videoPlayerController?.removeListener(_videoPlayerListener);
    await _videoPlayerController?.dispose();
    await _chewieController?.dispose();
    
    _videoPlayerController = null;
    _chewieController = null;
    
    _isInitialized = false;
    _isPlaying = false;
    _isBuffering = false;
    _isFullScreen = false;
    _position = Duration.zero;
    _duration = Duration.zero;
    
    super.dispose();
  }
}
