import 'package:flutter_test/flutter_test.dart';
import 'package:neomovies_mobile/data/models/torrent_info.dart';

void main() {
  group('TorrentInfo', () {
    test('fromAndroidJson creates valid TorrentInfo', () {
      final json = {
        'infoHash': 'test_hash',
        'name': 'Test Torrent',
        'totalSize': 1024000000,
        'progress': 0.5,
        'downloadSpeed': 1024000,
        'uploadSpeed': 512000,
        'numSeeds': 10,
        'numPeers': 5,
        'state': 'DOWNLOADING',
        'savePath': '/test/path',
        'files': [
          {
            'path': 'test.mp4',
            'size': 1024000000,
            'priority': 4,
            'progress': 0.5,
          }
        ],
        'pieceLength': 16384,
        'numPieces': 62500,
        'addedTime': 1640995200000,
      };

      final torrentInfo = TorrentInfo.fromAndroidJson(json);

      expect(torrentInfo.infoHash, equals('test_hash'));
      expect(torrentInfo.name, equals('Test Torrent'));
      expect(torrentInfo.totalSize, equals(1024000000));
      expect(torrentInfo.progress, equals(0.5));
      expect(torrentInfo.downloadSpeed, equals(1024000));
      expect(torrentInfo.uploadSpeed, equals(512000));
      expect(torrentInfo.numSeeds, equals(10));
      expect(torrentInfo.numPeers, equals(5));
      expect(torrentInfo.state, equals('DOWNLOADING'));
      expect(torrentInfo.savePath, equals('/test/path'));
      expect(torrentInfo.files.length, equals(1));
      expect(torrentInfo.files.first.path, equals('test.mp4'));
      expect(torrentInfo.files.first.size, equals(1024000000));
      expect(torrentInfo.files.first.priority, equals(FilePriority.NORMAL));
    });

    test('isDownloading returns true for DOWNLOADING state', () {
      final torrent = TorrentInfo(
        infoHash: 'test',
        name: 'test',
        totalSize: 100,
        progress: 0.5,
        downloadSpeed: 1000,
        uploadSpeed: 500,
        numSeeds: 5,
        numPeers: 3,
        state: 'DOWNLOADING',
        savePath: '/test',
        files: [],
      );

      expect(torrent.isDownloading, isTrue);
      expect(torrent.isPaused, isFalse);
      expect(torrent.isSeeding, isFalse);
      expect(torrent.isCompleted, isFalse);
    });

    test('isCompleted returns true for progress >= 1.0', () {
      final torrent = TorrentInfo(
        infoHash: 'test',
        name: 'test',
        totalSize: 100,
        progress: 1.0,
        downloadSpeed: 0,
        uploadSpeed: 500,
        numSeeds: 5,
        numPeers: 3,
        state: 'SEEDING',
        savePath: '/test',
        files: [],
      );

      expect(torrent.isCompleted, isTrue);
      expect(torrent.isSeeding, isTrue);
    });

    test('videoFiles returns only video files', () {
      final torrent = TorrentInfo(
        infoHash: 'test',
        name: 'test',
        totalSize: 100,
        progress: 1.0,
        downloadSpeed: 0,
        uploadSpeed: 0,
        numSeeds: 0,
        numPeers: 0,
        state: 'COMPLETED',
        savePath: '/test',
        files: [
          TorrentFileInfo(
            path: 'movie.mp4',
            size: 1000000,
            priority: FilePriority.NORMAL,
          ),
          TorrentFileInfo(
            path: 'subtitle.srt',
            size: 10000,
            priority: FilePriority.NORMAL,
          ),
          TorrentFileInfo(
            path: 'episode.mkv',
            size: 2000000,
            priority: FilePriority.NORMAL,
          ),
        ],
      );

      final videoFiles = torrent.videoFiles;
      expect(videoFiles.length, equals(2));
      expect(videoFiles.any((file) => file.path == 'movie.mp4'), isTrue);
      expect(videoFiles.any((file) => file.path == 'episode.mkv'), isTrue);
      expect(videoFiles.any((file) => file.path == 'subtitle.srt'), isFalse);
    });

    test('mainVideoFile returns largest video file', () {
      final torrent = TorrentInfo(
        infoHash: 'test',
        name: 'test',
        totalSize: 100,
        progress: 1.0,
        downloadSpeed: 0,
        uploadSpeed: 0,
        numSeeds: 0,
        numPeers: 0,
        state: 'COMPLETED',
        savePath: '/test',
        files: [
          TorrentFileInfo(
            path: 'small.mp4',
            size: 1000000,
            priority: FilePriority.NORMAL,
          ),
          TorrentFileInfo(
            path: 'large.mkv',
            size: 5000000,
            priority: FilePriority.NORMAL,
          ),
          TorrentFileInfo(
            path: 'medium.avi',
            size: 3000000,
            priority: FilePriority.NORMAL,
          ),
        ],
      );

      final mainFile = torrent.mainVideoFile;
      expect(mainFile?.path, equals('large.mkv'));
      expect(mainFile?.size, equals(5000000));
    });

    test('formattedTotalSize formats bytes correctly', () {
      final torrent = TorrentInfo(
        infoHash: 'test',
        name: 'test',
        totalSize: 1073741824, // 1 GB
        progress: 0.0,
        downloadSpeed: 0,
        uploadSpeed: 0,
        numSeeds: 0,
        numPeers: 0,
        state: 'PAUSED',
        savePath: '/test',
        files: [],
      );

      expect(torrent.formattedTotalSize, equals('1.0GB'));
    });
  });

  group('FilePriority', () {
    test('fromValue returns correct priority', () {
      expect(FilePriority.fromValue(0), equals(FilePriority.DONT_DOWNLOAD));
      expect(FilePriority.fromValue(4), equals(FilePriority.NORMAL));
      expect(FilePriority.fromValue(7), equals(FilePriority.HIGH));
      expect(FilePriority.fromValue(999), equals(FilePriority.NORMAL)); // Default
    });

    test('comparison operators work correctly', () {
      expect(FilePriority.HIGH > FilePriority.NORMAL, isTrue);
      expect(FilePriority.NORMAL > FilePriority.DONT_DOWNLOAD, isTrue);
      expect(FilePriority.DONT_DOWNLOAD < FilePriority.HIGH, isTrue);
    });
  });
}