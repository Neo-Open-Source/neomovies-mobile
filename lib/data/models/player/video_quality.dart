class VideoQuality {
  final String quality;
  final String url;
  final int bandwidth;
  final int width;
  final int height;

  VideoQuality({
    required this.quality,
    required this.url,
    required this.bandwidth,
    required this.width,
    required this.height,
  });

  factory VideoQuality.fromJson(Map<String, dynamic> json) {
    return VideoQuality(
      quality: json['quality'] ?? '',
      url: json['url'] ?? '',
      bandwidth: json['bandwidth'] ?? 0,
      width: json['width'] ?? 0,
      height: json['height'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'quality': quality,
      'url': url,
      'bandwidth': bandwidth,
      'width': width,
      'height': height,
    };
  }

  @override
  String toString() => quality;
}