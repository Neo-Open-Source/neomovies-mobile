class Subtitle {
  final String name;
  final String language;
  final String url;
  final bool isDefault;

  Subtitle({
    required this.name,
    required this.language,
    required this.url,
    this.isDefault = false,
  });

  factory Subtitle.fromJson(Map<String, dynamic> json) {
    return Subtitle(
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