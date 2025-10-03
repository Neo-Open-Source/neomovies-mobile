import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/services/torrent_platform_service.dart';
import '../../data/models/torrent_info.dart';

/// Provider для управления загрузками торрентов
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
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    super.dispose();
  }

  void _startProgressUpdates() {
    _progressTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_torrents.isNotEmpty && !_isLoading) {
        refreshDownloads();
      }
    });
  }

  /// Загрузить список активных загрузок
  Future<void> refreshDownloads() async {
    try {
      _setLoading(true);
      _setError(null);
      
      final progress = await TorrentPlatformService.getAllDownloads();
      
      // Получаем полную информацию о каждом торренте
      _torrents.clear();
      for (final progressItem in progress) {
        try {
          final torrentInfo = await TorrentPlatformService.getTorrent(progressItem.infoHash);
          if (torrentInfo != null) {
            _torrents.add(torrentInfo);
          }
        } catch (e) {
          // Если не удалось получить полную информацию, создаем базовую
          _torrents.add(TorrentInfo(
            infoHash: progressItem.infoHash,
            name: 'Торрент ${progressItem.infoHash.substring(0, 8)}',
            totalSize: 0,
            progress: progressItem.progress,
            downloadSpeed: progressItem.downloadRate,
            uploadSpeed: progressItem.uploadRate,
            numSeeds: progressItem.numSeeds,
            numPeers: progressItem.numPeers,
            state: progressItem.state,
            savePath: '/storage/emulated/0/Download/NeoMovies',
            files: [],
          ));
        }
      }
      
      _setLoading(false);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }

  /// Получить информацию о конкретном торренте
  Future<TorrentInfo?> getTorrentInfo(String infoHash) async {
    try {
      return await TorrentPlatformService.getTorrent(infoHash);
    } catch (e) {
      debugPrint('Ошибка получения информации о торренте: $e');
      return null;
    }
  }

  /// Приостановить торрент
  Future<void> pauseTorrent(String infoHash) async {
    try {
      await TorrentPlatformService.pauseDownload(infoHash);
      await refreshDownloads(); // Обновляем список
    } catch (e) {
      _setError(e.toString());
    }
  }

  /// Возобновить торрент
  Future<void> resumeTorrent(String infoHash) async {
    try {
      await TorrentPlatformService.resumeDownload(infoHash);
      await refreshDownloads(); // Обновляем список
    } catch (e) {
      _setError(e.toString());
    }
  }

  /// Удалить торрент
  Future<void> removeTorrent(String infoHash) async {
    try {
      await TorrentPlatformService.cancelDownload(infoHash);
      await refreshDownloads(); // Обновляем список
    } catch (e) {
      _setError(e.toString());
    }
  }

  /// Установить приоритет файла
  Future<void> setFilePriority(String infoHash, int fileIndex, FilePriority priority) async {
    try {
      await TorrentPlatformService.setFilePriority(infoHash, fileIndex, priority);
    } catch (e) {
      _setError(e.toString());
    }
  }

  /// Добавить новый торрент
  Future<String?> addTorrent(String magnetUri, {String? savePath}) async {
    try {
      final infoHash = await TorrentPlatformService.addTorrent(
        magnetUri: magnetUri,
        savePath: savePath,
      );
      await refreshDownloads(); // Обновляем список
      return infoHash;
    } catch (e) {
      _setError(e.toString());
      return null;
    }
  }

  /// Форматировать скорость
  String formatSpeed(int bytesPerSecond) {
    if (bytesPerSecond < 1024) return '${bytesPerSecond}B/s';
    if (bytesPerSecond < 1024 * 1024) return '${(bytesPerSecond / 1024).toStringAsFixed(1)}KB/s';
    return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)}MB/s';
  }

  /// Форматировать продолжительность
  String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}ч ${minutes}м ${seconds}с';
    } else if (minutes > 0) {
      return '${minutes}м ${seconds}с';
    } else {
      return '${seconds}с';
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }
}