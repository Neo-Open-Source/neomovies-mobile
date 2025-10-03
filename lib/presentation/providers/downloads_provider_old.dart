import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/services/torrent_platform_service.dart';
import '../../data/models/torrent_info.dart';

class ActiveDownload {
  final String infoHash;
  final String name;
  final DownloadProgress progress;
  final DateTime startTime;
  final List<String> selectedFiles;

  ActiveDownload({
    required this.infoHash,
    required this.name,
    required this.progress,
    required this.startTime,
    required this.selectedFiles,
  });

  ActiveDownload copyWith({
    String? infoHash,
    String? name,
    DownloadProgress? progress,
    DateTime? startTime,
    List<String>? selectedFiles,
  }) {
    return ActiveDownload(
      infoHash: infoHash ?? this.infoHash,
      name: name ?? this.name,
      progress: progress ?? this.progress,
      startTime: startTime ?? this.startTime,
      selectedFiles: selectedFiles ?? this.selectedFiles,
    );
  }
}

class DownloadsProvider with ChangeNotifier {
  final List<TorrentInfo> _torrents = [];
  Timer? _progressTimer;
  bool _isLoading = false;
  String? _error;

  List<TorrentInfo> get torrents => List.unmodifiable(_torrents);
  bool get isLoading => _isLoading;
  String? get error => _error;

  DownloadsProvider() {
    _startProgressUpdates();
    loadDownloads();
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    super.dispose();
  }

  void _startProgressUpdates() {
    _progressTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _updateProgress();
    });
  }

  Future<void> loadDownloads() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final progressList = await TorrentPlatformService.getAllDownloads();
      
      _downloads = progressList.map((progress) {
        // Try to find existing download to preserve metadata
        final existing = _downloads.where((d) => d.infoHash == progress.infoHash).firstOrNull;
        
        return ActiveDownload(
          infoHash: progress.infoHash,
          name: existing?.name ?? 'Unnamed Torrent',
          progress: progress,
          startTime: existing?.startTime ?? DateTime.now(),
          selectedFiles: existing?.selectedFiles ?? [],
        );
      }).toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _updateProgress() async {
    if (_downloads.isEmpty) return;

    try {
      final List<ActiveDownload> updatedDownloads = [];
      
      for (final download in _downloads) {
        final progress = await TorrentPlatformService.getDownloadProgress(download.infoHash);
        if (progress != null) {
          updatedDownloads.add(download.copyWith(progress: progress));
        }
      }
      
      _downloads = updatedDownloads;
      notifyListeners();
    } catch (e) {
      // Silent failure for progress updates
      if (kDebugMode) {
        print('Failed to update progress: $e');
      }
    }
  }

  Future<bool> pauseDownload(String infoHash) async {
    try {
      final success = await TorrentPlatformService.pauseDownload(infoHash);
      if (success) {
        await _updateProgress();
      }
      return success;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> resumeDownload(String infoHash) async {
    try {
      final success = await TorrentPlatformService.resumeDownload(infoHash);
      if (success) {
        await _updateProgress();
      }
      return success;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> cancelDownload(String infoHash) async {
    try {
      final success = await TorrentPlatformService.cancelDownload(infoHash);
      if (success) {
        _downloads.removeWhere((d) => d.infoHash == infoHash);
        notifyListeners();
      }
      return success;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  void addDownload({
    required String infoHash,
    required String name,
    required List<String> selectedFiles,
  }) {
    final download = ActiveDownload(
      infoHash: infoHash,
      name: name,
      progress: DownloadProgress(
        infoHash: infoHash,
        progress: 0.0,
        downloadRate: 0,
        uploadRate: 0,
        numSeeds: 0,
        numPeers: 0,
        state: 'starting',
      ),
      startTime: DateTime.now(),
      selectedFiles: selectedFiles,
    );

    _downloads.add(download);
    notifyListeners();
  }

  ActiveDownload? getDownload(String infoHash) {
    try {
      return _downloads.where((d) => d.infoHash == infoHash).first;
    } catch (e) {
      return null;
    }
  }

  String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String formatSpeed(int bytesPerSecond) {
    return '${formatFileSize(bytesPerSecond)}/s';
  }

  String formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays}d ${duration.inHours % 24}h';
    }
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    }
    if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds % 60}s';
    }
    return '${duration.inSeconds}s';
  }
}

extension ListExtension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}