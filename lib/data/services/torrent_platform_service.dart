import 'dart:convert';
import 'package:flutter/services.dart';

/// Data classes for torrent metadata (matching Kotlin side)
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
  static const MethodChannel _channel = MethodChannel('com.neo.neomovies/torrent');

  /// Get torrent metadata from magnet link
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
