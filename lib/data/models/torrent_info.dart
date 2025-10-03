/// File priority enum matching Android implementation
enum FilePriority {
  DONT_DOWNLOAD(0),
  NORMAL(4),
  HIGH(7);

  const FilePriority(this.value);
  final int value;

  static FilePriority fromValue(int value) {
    return FilePriority.values.firstWhere(
      (priority) => priority.value == value,
      orElse: () => FilePriority.NORMAL,
    );
  }

  bool operator >(FilePriority other) => value > other.value;
  bool operator <(FilePriority other) => value < other.value;
  bool operator >=(FilePriority other) => value >= other.value;
  bool operator <=(FilePriority other) => value <= other.value;
}

/// Torrent file information matching Android TorrentFileInfo
class TorrentFileInfo {
  final String path;
  final int size;
  final FilePriority priority;
  final double progress;

  TorrentFileInfo({
    required this.path,
    required this.size,
    required this.priority,
    this.progress = 0.0,
  });

  factory TorrentFileInfo.fromAndroidJson(Map<String, dynamic> json) {
    return TorrentFileInfo(
      path: json['path'] as String,
      size: json['size'] as int,
      priority: FilePriority.fromValue(json['priority'] as int),
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'size': size,
      'priority': priority.value,
      'progress': progress,
    };
  }
}

/// Main torrent information class matching Android TorrentInfo
class TorrentInfo {
  final String infoHash;
  final String name;
  final int totalSize;
  final double progress;
  final int downloadSpeed;
  final int uploadSpeed;
  final int numSeeds;
  final int numPeers;
  final String state;
  final String savePath;
  final List<TorrentFileInfo> files;
  final int pieceLength;
  final int numPieces;
  final DateTime? addedTime;

  TorrentInfo({
    required this.infoHash,
    required this.name,
    required this.totalSize,
    required this.progress,
    required this.downloadSpeed,
    required this.uploadSpeed,
    required this.numSeeds,
    required this.numPeers,
    required this.state,
    required this.savePath,
    required this.files,
    this.pieceLength = 0,
    this.numPieces = 0,
    this.addedTime,
  });

  factory TorrentInfo.fromAndroidJson(Map<String, dynamic> json) {
    final filesJson = json['files'] as List<dynamic>? ?? [];
    final files = filesJson
        .map((fileJson) => TorrentFileInfo.fromAndroidJson(fileJson as Map<String, dynamic>))
        .toList();

    return TorrentInfo(
      infoHash: json['infoHash'] as String,
      name: json['name'] as String,
      totalSize: json['totalSize'] as int,
      progress: (json['progress'] as num).toDouble(),
      downloadSpeed: json['downloadSpeed'] as int,
      uploadSpeed: json['uploadSpeed'] as int,
      numSeeds: json['numSeeds'] as int,
      numPeers: json['numPeers'] as int,
      state: json['state'] as String,
      savePath: json['savePath'] as String,
      files: files,
      pieceLength: json['pieceLength'] as int? ?? 0,
      numPieces: json['numPieces'] as int? ?? 0,
      addedTime: json['addedTime'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['addedTime'] as int)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'infoHash': infoHash,
      'name': name,
      'totalSize': totalSize,
      'progress': progress,
      'downloadSpeed': downloadSpeed,
      'uploadSpeed': uploadSpeed,
      'numSeeds': numSeeds,
      'numPeers': numPeers,
      'state': state,
      'savePath': savePath,
      'files': files.map((file) => file.toJson()).toList(),
      'pieceLength': pieceLength,
      'numPieces': numPieces,
      'addedTime': addedTime?.millisecondsSinceEpoch,
    };
  }

  /// Get video files only
  List<TorrentFileInfo> get videoFiles {
    final videoExtensions = {'.mp4', '.mkv', '.avi', '.mov', '.wmv', '.flv', '.webm', '.m4v'};
    return files.where((file) {
      final extension = file.path.toLowerCase().split('.').last;
      return videoExtensions.contains('.$extension');
    }).toList();
  }

  /// Get the largest video file (usually the main movie file)
  TorrentFileInfo? get mainVideoFile {
    final videos = videoFiles;
    if (videos.isEmpty) return null;
    
    videos.sort((a, b) => b.size.compareTo(a.size));
    return videos.first;
  }

  /// Check if torrent is completed
  bool get isCompleted => progress >= 1.0;

  /// Check if torrent is downloading
  bool get isDownloading => state == 'DOWNLOADING';

  /// Check if torrent is seeding
  bool get isSeeding => state == 'SEEDING';

  /// Check if torrent is paused
  bool get isPaused => state == 'PAUSED';

  /// Get formatted download speed
  String get formattedDownloadSpeed => _formatBytes(downloadSpeed);

  /// Get formatted upload speed
  String get formattedUploadSpeed => _formatBytes(uploadSpeed);

  /// Get formatted total size
  String get formattedTotalSize => _formatBytes(totalSize);

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }
}