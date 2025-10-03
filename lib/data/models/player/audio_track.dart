class AudioTrack {
  final String name;
  final String language;
  final String url;
  final bool isDefault;

  AudioTrack({
    required this.name,
    required this.language,
    required this.url,
    this.isDefault = false,
  });

  factory AudioTrack.fromJson(Map<String, dynamic> json) {
    return AudioTrack(
      name: json['name'] ?? '',
      language: json['language'] ?? '',
      url: json['url'] ?? '',
      isDefault: json['isDefault'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'language': language,
      'url': url,
      'isDefault': isDefault,
    };
  }

  @override
  String toString() => name;
}