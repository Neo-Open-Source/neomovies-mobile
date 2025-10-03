import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neomovies_mobile/data/services/torrent_platform_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('TorrentPlatformService Tests', () {
    late List<MethodCall> methodCalls;

    setUp(() {
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

    test('addTorrent should call platform method with correct parameters', () async {
      const magnetUri = 'magnet:?xt=urn:btih:test123&dn=test.movie.mkv';
      const savePath = '/storage/emulated/0/Download/Torrents';
      
      final result = await TorrentPlatformService.addTorrent(
        magnetUri: magnetUri, 
        savePath: savePath
      );

      expect(methodCalls.length, 1);
      expect(methodCalls.first.method, 'addTorrent');
      expect(methodCalls.first.arguments, {
        'magnetUri': magnetUri,
        'savePath': savePath,
      });
      expect(result, 'test-hash-123');
    });

    test('parseMagnetBasicInfo should parse magnet URI correctly', () async {
      const magnetUri = 'magnet:?xt=urn:btih:abc123&dn=test%20movie&tr=http%3A//tracker.example.com%3A8080/announce';
      
      final result = await TorrentPlatformService.parseMagnetBasicInfo(magnetUri);

      expect(result.name, 'test movie');
      expect(result.infoHash, 'abc123');
      expect(result.trackers.length, 1);
      expect(result.trackers.first, 'http://tracker.example.com:8080/announce');
    });
  });
}

/// Mock method call handler for torrent platform channel
dynamic _handleMethodCall(MethodCall methodCall) {
  switch (methodCall.method) {
    case 'addTorrent':
      return 'test-hash-123';

    case 'getTorrents':
      return jsonEncode([
        {
          'infoHash': 'test-hash-123',
          'progress': 0.5,
          'downloadSpeed': 1024000,
          'uploadSpeed': 512000,
          'numSeeds': 5,
          'numPeers': 10,
          'state': 'downloading',
        }
      ]);

    case 'getTorrent':
      return jsonEncode({
        'name': 'Test Movie',
        'infoHash': 'test-hash-123',
        'totalSize': 1073741824,
        'files': [
          {
            'path': 'Test Movie.mkv',
            'size': 1073741824,
            'priority': 4,
          }
        ],
        'downloadedSize': 536870912,
        'downloadSpeed': 1024000,
        'uploadSpeed': 512000,
        'state': 'downloading',
        'progress': 0.5,
        'numSeeds': 5,
        'numPeers': 10,
        'addedTime': DateTime.now().millisecondsSinceEpoch,
        'ratio': 0.8,
      });

    default:
      return null;
  }
}