import 'dart:convert';
import 'package:flutter/services.dart';

/// Data classes for torrent metadata (matching Kotlin side)

/// Базовая информация из magnet-ссылки
class MagnetBasicInfo {
  final String name;
  final String infoHash;
  final List<String> trackers;
  final int totalSize;

  MagnetBasicInfo({
    required this.name,
    required this.infoHash,
    required this.trackers,
    this.totalSize = 0,
  });

  factory MagnetBasicInfo.fromJson(Map<String, dynamic> json) {
    return MagnetBasicInfo(
      name: json['name'] as String,
      infoHash: json['infoHash'] as String,
      trackers: List<String>.from(json['trackers'] as List),
      totalSize: json['totalSize'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'infoHash': infoHash,
      'trackers': trackers,
      'totalSize': totalSize,
    };
  }
}

/// Информация о файле в торренте
class FileInfo {
  final String name;
  final String path;
  final int size;
  final int index;
  final String extension;
  final bool isVideo;
  final bool isAudio;
  final bool isImage;
  final bool isDocument;
  final bool selected;

  FileInfo({
    required this.name,
    required this.path,
    required this.size,
    required this.index,
    this.extension = '',
    this.isVideo = false,
    this.isAudio = false,
    this.isImage = false,
    this.isDocument = false,
    this.selected = false,
  });

  factory FileInfo.fromJson(Map<String, dynamic> json) {
    return FileInfo(
      name: json['name'] as String,
      path: json['path'] as String,
      size: json['size'] as int,
      index: json['index'] as int,
      extension: json['extension'] as String? ?? '',
      isVideo: json['isVideo'] as bool? ?? false,
      isAudio: json['isAudio'] as bool? ?? false,
      isImage: json['isImage'] as bool? ?? false,
      isDocument: json['isDocument'] as bool? ?? false,
      selected: json['selected'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'path': path,
      'size': size,
      'index': index,
      'extension': extension,
      'isVideo': isVideo,
      'isAudio': isAudio,
      'isImage': isImage,
      'isDocument': isDocument,
      'selected': selected,
    };
  }

  FileInfo copyWith({
    String? name,
    String? path,
    int? size,
    int? index,
    String? extension,
    bool? isVideo,
    bool? isAudio,
    bool? isImage,
    bool? isDocument,
    bool? selected,
  }) {
    return FileInfo(
      name: name ?? this.name,
      path: path ?? this.path,
      size: size ?? this.size,
      index: index ?? this.index,
      extension: extension ?? this.extension,
      isVideo: isVideo ?? this.isVideo,
      isAudio: isAudio ?? this.isAudio,
      isImage: isImage ?? this.isImage,
      isDocument: isDocument ?? this.isDocument,
      selected: selected ?? this.selected,
    );
  }
}

/// Узел директории
class DirectoryNode {
  final String name;
  final String path;
  final List<FileInfo> files;
  final List<DirectoryNode> subdirectories;
  final int totalSize;
  final int fileCount;

  DirectoryNode({
    required this.name,
    required this.path,
    required this.files,
    required this.subdirectories,
    required this.totalSize,
    required this.fileCount,
  });

  factory DirectoryNode.fromJson(Map<String, dynamic> json) {
    return DirectoryNode(
      name: json['name'] as String,
      path: json['path'] as String,
      files: (json['files'] as List)
          .map((file) => FileInfo.fromJson(file as Map<String, dynamic>))
          .toList(),
      subdirectories: (json['subdirectories'] as List)
          .map((dir) => DirectoryNode.fromJson(dir as Map<String, dynamic>))
          .toList(),
      totalSize: json['totalSize'] as int,
      fileCount: json['fileCount'] as int,
    );
  }
}

/// Структура файлов торрента
class FileStructure {
  final DirectoryNode rootDirectory;
  final int totalFiles;
  final Map<String, int> filesByType;

  FileStructure({
    required this.rootDirectory,
    required this.totalFiles,
    required this.filesByType,
  });

  factory FileStructure.fromJson(Map<String, dynamic> json) {
    return FileStructure(
      rootDirectory: DirectoryNode.fromJson(json['rootDirectory'] as Map<String, dynamic>),
      totalFiles: json['totalFiles'] as int,
      filesByType: Map<String, int>.from(json['filesByType'] as Map),
    );
  }
}

/// Полные метаданные торрента
class TorrentMetadataFull {
  final String name;
  final String infoHash;
  final int totalSize;
  final int pieceLength;
  final int numPieces;
  final FileStructure fileStructure;
  final List<String> trackers;
  final int creationDate;
  final String comment;
  final String createdBy;

  TorrentMetadataFull({
    required this.name,
    required this.infoHash,
    required this.totalSize,
    required this.pieceLength,
    required this.numPieces,
    required this.fileStructure,
    required this.trackers,
    required this.creationDate,
    required this.comment,
    required this.createdBy,
  });

  factory TorrentMetadataFull.fromJson(Map<String, dynamic> json) {
    return TorrentMetadataFull(
      name: json['name'] as String,
      infoHash: json['infoHash'] as String,
      totalSize: json['totalSize'] as int,
      pieceLength: json['pieceLength'] as int,
      numPieces: json['numPieces'] as int,
      fileStructure: FileStructure.fromJson(json['fileStructure'] as Map<String, dynamic>),
      trackers: List<String>.from(json['trackers'] as List),
      creationDate: json['creationDate'] as int,
      comment: json['comment'] as String,
      createdBy: json['createdBy'] as String,
    );
  }

  /// Получить плоский список всех файлов
  List<FileInfo> getAllFiles() {
    final List<FileInfo> allFiles = [];
    _collectFiles(fileStructure.rootDirectory, allFiles);
    return allFiles;
  }

  void _collectFiles(DirectoryNode directory, List<FileInfo> result) {
    result.addAll(directory.files);
    for (final subdir in directory.subdirectories) {
      _collectFiles(subdir, result);
    }
  }
}

class TorrentFileInfo {
  final String path;
  final int size;
  final bool selected;

  TorrentFileInfo({
    required this.path,
    required this.size,
    this.selected = false,
  });

  factory TorrentFileInfo.fromJson(Map<String, dynamic> json) {
    return TorrentFileInfo(
      path: json['path'] as String,
      size: json['size'] as int,
      selected: json['selected'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'size': size,
      'selected': selected,
    };
  }

  TorrentFileInfo copyWith({
    String? path,
    int? size,
    bool? selected,
  }) {
    return TorrentFileInfo(
      path: path ?? this.path,
      size: size ?? this.size,
      selected: selected ?? this.selected,
    );
  }
}

class TorrentMetadata {
  final String name;
  final int totalSize;
  final List<TorrentFileInfo> files;
  final String infoHash;

  TorrentMetadata({
    required this.name,
    required this.totalSize,
    required this.files,
    required this.infoHash,
  });

  factory TorrentMetadata.fromJson(Map<String, dynamic> json) {
    return TorrentMetadata(
      name: json['name'] as String,
      totalSize: json['totalSize'] as int,
      files: (json['files'] as List)
          .map((file) => TorrentFileInfo.fromJson(file as Map<String, dynamic>))
          .toList(),
      infoHash: json['infoHash'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'totalSize': totalSize,
      'files': files.map((file) => file.toJson()).toList(),
      'infoHash': infoHash,
    };
  }
}

class DownloadProgress {
  final String infoHash;
  final double progress;
  final int downloadRate;
  final int uploadRate;
  final int numSeeds;
  final int numPeers;
  final String state;

  DownloadProgress({
    required this.infoHash,
    required this.progress,
    required this.downloadRate,
    required this.uploadRate,
    required this.numSeeds,
    required this.numPeers,
    required this.state,
  });

  factory DownloadProgress.fromJson(Map<String, dynamic> json) {
    return DownloadProgress(
      infoHash: json['infoHash'] as String,
      progress: (json['progress'] as num).toDouble(),
      downloadRate: json['downloadRate'] as int,
      uploadRate: json['uploadRate'] as int,
      numSeeds: json['numSeeds'] as int,
      numPeers: json['numPeers'] as int,
      state: json['state'] as String,
    );
  }
}

/// Platform service for torrent operations using jlibtorrent on Android
class TorrentPlatformService {
  static const MethodChannel _channel = MethodChannel('com.neo.neomovies_mobile/torrent');

  /// Получить базовую информацию из magnet-ссылки
  static Future<MagnetBasicInfo> parseMagnetBasicInfo(String magnetUri) async {
    try {
      final String result = await _channel.invokeMethod('parseMagnetBasicInfo', {
        'magnetUri': magnetUri,
      });
      
      final Map<String, dynamic> json = jsonDecode(result);
      return MagnetBasicInfo.fromJson(json);
    } on PlatformException catch (e) {
      throw Exception('Failed to parse magnet URI: ${e.message}');
    } catch (e) {
      throw Exception('Failed to parse magnet basic info: $e');
    }
  }

  /// Получить полные метаданные торрента
  static Future<TorrentMetadataFull> fetchFullMetadata(String magnetUri) async {
    try {
      final String result = await _channel.invokeMethod('fetchFullMetadata', {
        'magnetUri': magnetUri,
      });
      
      final Map<String, dynamic> json = jsonDecode(result);
      return TorrentMetadataFull.fromJson(json);
    } on PlatformException catch (e) {
      throw Exception('Failed to fetch torrent metadata: ${e.message}');
    } catch (e) {
      throw Exception('Failed to parse torrent metadata: $e');
    }
  }

  /// Тестирование торрент-сервиса
  static Future<String> testTorrentService() async {
    try {
      final String result = await _channel.invokeMethod('testTorrentService');
      return result;
    } on PlatformException catch (e) {
      throw Exception('Torrent service test failed: ${e.message}');
    }
  }

  /// Get torrent metadata from magnet link (legacy method)
  static Future<TorrentMetadata> getTorrentMetadata(String magnetLink) async {
    try {
      final String result = await _channel.invokeMethod('getTorrentMetadata', {
        'magnetLink': magnetLink,
      });
      
      final Map<String, dynamic> json = jsonDecode(result);
      return TorrentMetadata.fromJson(json);
    } on PlatformException catch (e) {
      throw Exception('Failed to get torrent metadata: ${e.message}');
    } catch (e) {
      throw Exception('Failed to parse torrent metadata: $e');
    }
  }

  /// Start downloading selected files from torrent
  static Future<String> startDownload({
    required String magnetLink,
    required List<int> selectedFiles,
    String? downloadPath,
  }) async {
    try {
      final String infoHash = await _channel.invokeMethod('startDownload', {
        'magnetLink': magnetLink,
        'selectedFiles': selectedFiles,
        'downloadPath': downloadPath,
      });
      
      return infoHash;
    } on PlatformException catch (e) {
      throw Exception('Failed to start download: ${e.message}');
    }
  }

  /// Get download progress for a torrent
  static Future<DownloadProgress?> getDownloadProgress(String infoHash) async {
    try {
      final String? result = await _channel.invokeMethod('getDownloadProgress', {
        'infoHash': infoHash,
      });
      
      if (result == null) return null;
      
      final Map<String, dynamic> json = jsonDecode(result);
      return DownloadProgress.fromJson(json);
    } on PlatformException catch (e) {
      if (e.code == 'NOT_FOUND') return null;
      throw Exception('Failed to get download progress: ${e.message}');
    } catch (e) {
      throw Exception('Failed to parse download progress: $e');
    }
  }

  /// Pause download
  static Future<bool> pauseDownload(String infoHash) async {
    try {
      final bool result = await _channel.invokeMethod('pauseDownload', {
        'infoHash': infoHash,
      });
      
      return result;
    } on PlatformException catch (e) {
      throw Exception('Failed to pause download: ${e.message}');
    }
  }

  /// Resume download
  static Future<bool> resumeDownload(String infoHash) async {
    try {
      final bool result = await _channel.invokeMethod('resumeDownload', {
        'infoHash': infoHash,
      });
      
      return result;
    } on PlatformException catch (e) {
      throw Exception('Failed to resume download: ${e.message}');
    }
  }

  /// Cancel and remove download
  static Future<bool> cancelDownload(String infoHash) async {
    try {
      final bool result = await _channel.invokeMethod('cancelDownload', {
        'infoHash': infoHash,
      });
      
      return result;
    } on PlatformException catch (e) {
      throw Exception('Failed to cancel download: ${e.message}');
    }
  }

  /// Get all active downloads
  static Future<List<DownloadProgress>> getAllDownloads() async {
    try {
      final String result = await _channel.invokeMethod('getAllDownloads');
      
      final List<dynamic> jsonList = jsonDecode(result);
      return jsonList
          .map((json) => DownloadProgress.fromJson(json as Map<String, dynamic>))
          .toList();
    } on PlatformException catch (e) {
      throw Exception('Failed to get all downloads: ${e.message}');
    } catch (e) {
      throw Exception('Failed to parse downloads: $e');
    }
  }
}
