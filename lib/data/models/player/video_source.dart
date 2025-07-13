import 'package:equatable/equatable.dart';

enum VideoSourceType {
  lumex,
  alloha,
}

class VideoSource extends Equatable {
  final String id;
  final String name;
  final VideoSourceType type;
  final bool isActive;

  const VideoSource({
    required this.id,
    required this.name,
    required this.type,
    this.isActive = true,
  });

  // Default sources
  static final List<VideoSource> defaultSources = [
    const VideoSource(
      id: 'alloha',
      name: 'Alloha',
      type: VideoSourceType.alloha,
      isActive: true,
    ),
    const VideoSource(
      id: 'lumex',
      name: 'Lumex',
      type: VideoSourceType.lumex,
      isActive: false,
    ),
  ];

  @override
  List<Object?> get props => [id, name, type, isActive];

  @override
  bool get stringify => true;

  // Convert to map for serialization
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'isActive': isActive,
    };
  }

  // Create from map for deserialization
  factory VideoSource.fromMap(Map<String, dynamic> map) {
    return VideoSource(
      id: map['id'] as String? ?? 'unknown',
      name: map['name'] as String? ?? 'Unknown',
      type: VideoSourceType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => VideoSourceType.lumex,
      ),
      isActive: map['isActive'] as bool? ?? true,
    );
  }

  // Copy with method for immutability
  VideoSource copyWith({
    String? id,
    String? name,
    VideoSourceType? type,
    bool? isActive,
  }) {
    return VideoSource(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      isActive: isActive ?? this.isActive,
    );
  }
}
