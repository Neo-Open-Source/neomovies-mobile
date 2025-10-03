import 'package:neomovies_mobile/data/models/player/video_quality.dart';
import 'package:neomovies_mobile/data/models/player/audio_track.dart';
import 'package:neomovies_mobile/data/models/player/subtitle.dart';

class PlayerSettings {
  final VideoQuality? selectedQuality;
  final AudioTrack? selectedAudioTrack;
  final Subtitle? selectedSubtitle;
  final double volume;
  final double playbackSpeed;
  final bool autoPlay;
  final bool muted;

  PlayerSettings({
    this.selectedQuality,
    this.selectedAudioTrack,
    this.selectedSubtitle,
    this.volume = 1.0,
    this.playbackSpeed = 1.0,
    this.autoPlay = true,
    this.muted = false,
  });

  PlayerSettings copyWith({
    VideoQuality? selectedQuality,
    AudioTrack? selectedAudioTrack,
    Subtitle? selectedSubtitle,
    double? volume,
    double? playbackSpeed,
    bool? autoPlay,
    bool? muted,
  }) {
    return PlayerSettings(
      selectedQuality: selectedQuality ?? this.selectedQuality,
      selectedAudioTrack: selectedAudioTrack ?? this.selectedAudioTrack,
      selectedSubtitle: selectedSubtitle ?? this.selectedSubtitle,
      volume: volume ?? this.volume,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      autoPlay: autoPlay ?? this.autoPlay,
      muted: muted ?? this.muted,
    );
  }

  factory PlayerSettings.fromJson(Map<String, dynamic> json) {
    return PlayerSettings(
      selectedQuality: json['selectedQuality'] != null 
          ? VideoQuality.fromJson(json['selectedQuality']) 
          : null,
      selectedAudioTrack: json['selectedAudioTrack'] != null 
          ? AudioTrack.fromJson(json['selectedAudioTrack']) 
          : null,
      selectedSubtitle: json['selectedSubtitle'] != null 
          ? Subtitle.fromJson(json['selectedSubtitle']) 
          : null,
      volume: json['volume']?.toDouble() ?? 1.0,
      playbackSpeed: json['playbackSpeed']?.toDouble() ?? 1.0,
      autoPlay: json['autoPlay'] ?? true,
      muted: json['muted'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'selectedQuality': selectedQuality?.toJson(),
      'selectedAudioTrack': selectedAudioTrack?.toJson(),
      'selectedSubtitle': selectedSubtitle?.toJson(),
      'volume': volume,
      'playbackSpeed': playbackSpeed,
      'autoPlay': autoPlay,
      'muted': muted,
    };
  }
}