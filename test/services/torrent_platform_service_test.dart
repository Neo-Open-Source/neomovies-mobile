import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neomovies_mobile/data/models/torrent_info.dart';
import 'package:neomovies_mobile/data/services/torrent_platform_service.dart';

void main() {
  group('TorrentPlatformService Tests', () {
    late TorrentPlatformService service;
    late List<MethodCall> methodCalls;

    setUp(() {
      service = TorrentPlatformService();
      methodCalls = [];

      // Mock the platform channel
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.neo.neomovies_mobile/torrent'),
        (MethodCall methodCall) async {
          methodCalls.add(methodCall);
          return _handleMethodCall(methodCall);
        },
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.neo.neomovies_mobile/torrent'),
        null,
      );
    });

    group('Torrent Management', () {
      test('addTorrent should call Android method with correct parameters', () async {
        const magnetUri = 'magnet:?xt=urn:btih:test123&dn=test.movie.mkv';
        const downloadPath = '/storage/emulated/0/Download/Torrents';
        
        await service.addTorrent(magnetUri, downloadPath);

        expect(methodCalls.length, 1);
        expect(methodCalls.first.method, 'addTorrent');
        expect(methodCalls.first.arguments, {
          'magnetUri': magnetUri,
          'downloadPath': downloadPath,
        });
      });

      test('removeTorrent should call Android method with torrent hash', () async {
        const torrentHash = 'abc123def456';
        
        await service.removeTorrent(torrentHash);

        expect(methodCalls.length, 1);
        expect(methodCalls.first.method, 'removeTorrent');
        expect(methodCalls.first.arguments, {'torrentHash': torrentHash});
      });

      test('pauseTorrent should call Android method with torrent hash', () async {
        const torrentHash = 'abc123def456';
        
        await service.pauseTorrent(torrentHash);

        expect(methodCalls.length, 1);
        expect(methodCalls.first.method, 'pauseTorrent');
        expect(methodCalls.first.arguments, {'torrentHash': torrentHash});
      });

      test('resumeTorrent should call Android method with torrent hash', () async {
        const torrentHash = 'abc123def456';
        
        await service.resumeTorrent(torrentHash);

        expect(methodCalls.length, 1);
        expect(methodCalls.first.method, 'resumeTorrent');
        expect(methodCalls.first.arguments, {'torrentHash': torrentHash});
      });
    });

    group('Torrent Information', () {
      test('getAllTorrents should return list of TorrentInfo objects', () async {
        final torrents = await service.getAllTorrents();

        expect(methodCalls.length, 1);
        expect(methodCalls.first.method, 'getAllTorrents');
        expect(torrents, isA<List<TorrentInfo>>());
        expect(torrents.length, 2); // Based on mock data
        
        final firstTorrent = torrents.first;
        expect(firstTorrent.name, 'Test Movie 1080p.mkv');
        expect(firstTorrent.infoHash, 'abc123def456');
        expect(firstTorrent.state, 'downloading');
        expect(firstTorrent.progress, 0.65);
      });

      test('getTorrentInfo should return specific torrent information', () async {
        const torrentHash = 'abc123def456';
        
        final torrent = await service.getTorrentInfo(torrentHash);

        expect(methodCalls.length, 1);
        expect(methodCalls.first.method, 'getTorrentInfo');
        expect(methodCalls.first.arguments, {'torrentHash': torrentHash});
        expect(torrent, isA<TorrentInfo>());
        expect(torrent?.infoHash, torrentHash);
      });
    });

    group('File Priority Management', () {
      test('setFilePriority should call Android method with correct parameters', () async {
        const torrentHash = 'abc123def456';
        const fileIndex = 0;
        const priority = FilePriority.high;
        
        await service.setFilePriority(torrentHash, fileIndex, priority);

        expect(methodCalls.length, 1);
        expect(methodCalls.first.method, 'setFilePriority');
        expect(methodCalls.first.arguments, {
          'torrentHash': torrentHash,
          'fileIndex': fileIndex,
          'priority': priority.value,
        });
      });

      test('getFilePriorities should return list of priorities', () async {
        const torrentHash = 'abc123def456';
        
        final priorities = await service.getFilePriorities(torrentHash);

        expect(methodCalls.length, 1);
        expect(methodCalls.first.method, 'getFilePriorities');
        expect(methodCalls.first.arguments, {'torrentHash': torrentHash});
        expect(priorities, isA<List<FilePriority>>());
        expect(priorities.length, 3); // Based on mock data
      });
    });

    group('Error Handling', () {
      test('should handle PlatformException gracefully', () async {
        // Override mock to throw exception
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('com.neo.neomovies_mobile/torrent'),
          (MethodCall methodCall) async {
            throw PlatformException(
              code: 'TORRENT_ERROR',
              message: 'Failed to add torrent',
              details: 'Invalid magnet URI',
            );
          },
        );

        expect(
          () => service.addTorrent('invalid-magnet', '/path'),
          throwsA(isA<PlatformException>()),
        );
      });

      test('should handle null response from platform', () async {
        // Override mock to return null
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('com.neo.neomovies_mobile/torrent'),
          (MethodCall methodCall) async => null,
        );

        final result = await service.getTorrentInfo('nonexistent');
        expect(result, isNull);
      });
    });

    group('State Management', () {
      test('torrent states should be correctly identified', () async {
        final torrents = await service.getAllTorrents();
        
        // Find torrents with different states
        final downloadingTorrent = torrents.firstWhere(
          (t) => t.state == 'downloading',
        );
        final seedingTorrent = torrents.firstWhere(
          (t) => t.state == 'seeding',
        );

        expect(downloadingTorrent.isDownloading, isTrue);
        expect(downloadingTorrent.isSeeding, isFalse);
        expect(downloadingTorrent.isCompleted, isFalse);

        expect(seedingTorrent.isDownloading, isFalse);
        expect(seedingTorrent.isSeeding, isTrue);
        expect(seedingTorrent.isCompleted, isTrue);
      });

      test('progress calculation should be accurate', () async {
        final torrents = await service.getAllTorrents();
        final torrent = torrents.first;

        expect(torrent.progress, inInclusiveRange(0.0, 1.0));
        expect(torrent.formattedProgress, '65%');
      });
    });

    group('Video File Detection', () {
      test('should identify video files correctly', () async {
        final torrents = await service.getAllTorrents();
        final torrent = torrents.first;

        final videoFiles = torrent.videoFiles;
        expect(videoFiles.isNotEmpty, isTrue);
        
        final videoFile = videoFiles.first;
        expect(videoFile.name.toLowerCase(), contains('.mkv'));
        expect(videoFile.isVideo, isTrue);
      });

      test('should find main video file', () async {
        final torrents = await service.getAllTorrents();
        final torrent = torrents.first;

        final mainFile = torrent.mainVideoFile;
        expect(mainFile, isNotNull);
        expect(mainFile!.isVideo, isTrue);
        expect(mainFile.size, greaterThan(0));
      });
    });
  });
}

/// Mock method call handler for torrent platform channel
dynamic _handleMethodCall(MethodCall methodCall) {
  switch (methodCall.method) {
    case 'addTorrent':
      return {'success': true, 'torrentHash': 'abc123def456'};

    case 'removeTorrent':
    case 'pauseTorrent':
    case 'resumeTorrent':
      return {'success': true};

    case 'getAllTorrents':
      return _getMockTorrentsData();

    case 'getTorrentInfo':
      final hash = methodCall.arguments['torrentHash'] as String;
      final torrents = _getMockTorrentsData();
      return torrents.firstWhere(
        (t) => t['infoHash'] == hash,
        orElse: () => null,
      );

    case 'setFilePriority':
      return {'success': true};

    case 'getFilePriorities':
      return [
        FilePriority.high.value,
        FilePriority.normal.value,
        FilePriority.low.value,
      ];

    default:
      throw PlatformException(
        code: 'UNIMPLEMENTED',
        message: 'Method ${methodCall.method} not implemented',
      );
  }
}

/// Mock torrents data for testing
List<Map<String, dynamic>> _getMockTorrentsData() {
  return [
    {
      'name': 'Test Movie 1080p.mkv',
      'infoHash': 'abc123def456',
      'state': 'downloading',
      'progress': 0.65,
      'downloadSpeed': 2500000, // 2.5 MB/s
      'uploadSpeed': 800000, // 800 KB/s
      'totalSize': 4294967296, // 4 GB
      'downloadedSize': 2791728742, // ~2.6 GB
      'seeders': 15,
      'leechers': 8,
      'ratio': 1.2,
      'addedTime': DateTime.now().subtract(const Duration(hours: 2)).millisecondsSinceEpoch,
      'files': [
        {
          'name': 'Test Movie 1080p.mkv',
          'size': 4294967296,
          'path': '/storage/emulated/0/Download/Torrents/Test Movie 1080p.mkv',
          'priority': FilePriority.high.value,
        },
        {
          'name': 'subtitle.srt',
          'size': 65536,
          'path': '/storage/emulated/0/Download/Torrents/subtitle.srt',
          'priority': FilePriority.normal.value,
        },
        {
          'name': 'NFO.txt',
          'size': 2048,
          'path': '/storage/emulated/0/Download/Torrents/NFO.txt',
          'priority': FilePriority.low.value,
        },
      ],
    },
    {
      'name': 'Another Movie 720p',
      'infoHash': 'def456ghi789',
      'state': 'seeding',
      'progress': 1.0,
      'downloadSpeed': 0,
      'uploadSpeed': 500000, // 500 KB/s
      'totalSize': 2147483648, // 2 GB
      'downloadedSize': 2147483648,
      'seeders': 25,
      'leechers': 3,
      'ratio': 2.5,
      'addedTime': DateTime.now().subtract(const Duration(days: 1)).millisecondsSinceEpoch,
      'files': [
        {
          'name': 'Another Movie 720p.mp4',
          'size': 2147483648,
          'path': '/storage/emulated/0/Download/Torrents/Another Movie 720p.mp4',
          'priority': FilePriority.high.value,
        },
      ],
    },
  ];
}