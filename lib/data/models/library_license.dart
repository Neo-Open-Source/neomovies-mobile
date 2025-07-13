class LibraryLicense {
  final String name;
  final String version;
  final String license;
  final String url;
  final String description;
  final String? licenseText;

  const LibraryLicense({
    required this.name,
    required this.version,
    required this.license,
    required this.url,
    required this.description,
    this.licenseText,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'version': version,
      'license': license,
      'url': url,
      'description': description,
      'licenseText': licenseText,
    };
  }

  LibraryLicense copyWith({
    String? name,
    String? version,
    String? license,
    String? url,
    String? description,
    String? licenseText,
  }) {
    return LibraryLicense(
      name: name ?? this.name,
      version: version ?? this.version,
      license: license ?? this.license,
      url: url ?? this.url,
      description: description ?? this.description,
      licenseText: licenseText ?? this.licenseText,
    );
  }

  factory LibraryLicense.fromMap(Map<String, dynamic> map) {
    return LibraryLicense(
      name: map['name'] as String? ?? '',
      version: map['version'] as String? ?? '',
      license: map['license'] as String? ?? '',
      url: map['url'] as String? ?? '',
      description: map['description'] as String? ?? '',
      licenseText: map['licenseText'] as String?,
    );
  }
}
