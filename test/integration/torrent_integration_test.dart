import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neomovies_mobile/data/models/torrent_info.dart';
import 'package:neomovies_mobile/data/services/torrent_platform_service.dart';

void main() {
  group('Torrent Integration Tests', () {
    late TorrentPlatformService service;
    late List<MethodCall> methodCalls;
    
    // Sintel - открытый короткометражный фильм от Blender Foundation
    // Официально доступен под Creative Commons лицензией
    const sintelMagnetLink = 'magnet:?xt=urn:btih:08ada5a7a6183aae1e09d831df6748d566095a10'
        '&dn=Sintel&tr=udp%3A%2F%2Fexplodie.org%3A6969'
        '&tr=udp%3A%2F%2Ftracker.coppersurfer.tk%3A6969'
        '&tr=udp%3A%2F%2Ftracker.empire-js.us%3A1337'
        '&tr=udp%3A%2F%2Ftracker.leechers-paradise.org%3A6969'
        '&tr=udp%3A%2F%2Ftracker.opentrackr.org%3A1337'
        '&tr=wss%3A%2F%2Ftracker.btorrent.xyz'
        '&tr=wss%3A%2F%2Ftracker.fastcast.nz'
        '&tr=wss%3A%2F%2Ftracker.openwebtorrent.com'
        '&ws=https%3A%2F%2Fwebtorrent.io%2Ftorrents%2F'
        '&xs=https%3A%2F%2Fwebtorrent.io%2Ftorrents%2Fsintel.torrent';

    const expectedTorrentHash = '08ada5a7a6183aae1e09d831df6748d566095a10';

    setUp(() {
      service = TorrentPlatformService();
      methodCalls = [];

      // Mock platform channel для симуляции Android ответов
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.neo.neomovies_mobile/torrent'),
        (MethodCall methodCall) async {
          methodCalls.add(methodCall);
          return _handleSintelMethodCall(methodCall);
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

    group('Real Magnet Link Tests', () {
      test('should parse Sintel magnet link correctly', () {
        // Проверяем, что магнет ссылка содержит правильные компоненты
        expect(sintelMagnetLink, contains('urn:btih:$expectedTorrentHash'));
        expect(sintelMagnetLink, contains('Sintel'));
        expect(sintelMagnetLink, contains('tracker.opentrackr.org'));
        
        // Проверяем, что это действительно magnet ссылка
        expect(sintelMagnetLink, startsWith('magnet:?xt=urn:btih:'));
        
        // Извлекаем hash из магнет ссылки
        final hashMatch = RegExp(r'urn:btih:([a-fA-F0-9]{40})').firstMatch(sintelMagnetLink);
        expect(hashMatch, isNotNull);
        expect(hashMatch!.group(1)?.toLowerCase(), expectedTorrentHash);
      });

      test('should add Sintel torrent successfully', () async {
        const downloadPath = '/storage/emulated/0/Download/Torrents';
        
        final result = await service.addTorrent(sintelMagnetLink, downloadPath);

        // Проверяем, что метод был вызван с правильными параметрами
        expect(methodCalls.length, 1);
        expect(methodCalls.first.method, 'addTorrent');
        expect(methodCalls.first.arguments['magnetUri'], sintelMagnetLink);
        expect(methodCalls.first.arguments['downloadPath'], downloadPath);
        
        // Проверяем результат
        expect(result, isA<Map<String, dynamic>>());
        expect(result['success'], isTrue);
        expect(result['torrentHash'], expectedTorrentHash);
      });

      test('should retrieve Sintel torrent info', () async {
        // Добавляем торрент
        await service.addTorrent(sintelMagnetLink, '/storage/emulated/0/Download/Torrents');
        methodCalls.clear(); // Очищаем предыдущие вызовы
        
        // Получаем информацию о торренте
        final torrentInfo = await service.getTorrentInfo(expectedTorrentHash);

        expect(methodCalls.length, 1);
        expect(methodCalls.first.method, 'getTorrentInfo');
        expect(methodCalls.first.arguments['torrentHash'], expectedTorrentHash);
        
        expect(torrentInfo, isNotNull);
        expect(torrentInfo!.infoHash, expectedTorrentHash);
        expect(torrentInfo.name, contains('Sintel'));
        
        // Проверяем, что обнаружены видео файлы
        final videoFiles = torrentInfo.videoFiles;
        expect(videoFiles.isNotEmpty, isTrue);
        
        final mainFile = torrentInfo.mainVideoFile;
        expect(mainFile, isNotNull);
        expect(mainFile!.name.toLowerCase(), anyOf(
          contains('.mp4'),
          contains('.mkv'),
          contains('.avi'),
          contains('.webm'),
        ));
      });

      test('should handle torrent operations on Sintel', () async {
        // Добавляем торрент
        await service.addTorrent(sintelMagnetLink, '/storage/emulated/0/Download/Torrents');
        
        // Тестируем все операции
        await service.pauseTorrent(expectedTorrentHash);
        await service.resumeTorrent(expectedTorrentHash);
        
        // Проверяем приоритеты файлов
        final priorities = await service.getFilePriorities(expectedTorrentHash);
        expect(priorities, isA<List<FilePriority>>());
        expect(priorities.isNotEmpty, isTrue);
        
        // Устанавливаем высокий приоритет для первого файла
        await service.setFilePriority(expectedTorrentHash, 0, FilePriority.high);
        
        // Получаем список всех торрентов
        final allTorrents = await service.getAllTorrents();
        expect(allTorrents.any((t) => t.infoHash == expectedTorrentHash), isTrue);
        
        // Удаляем торрент
        await service.removeTorrent(expectedTorrentHash);
        
        // Проверяем все вызовы методов
        final expectedMethods = ['addTorrent', 'pauseTorrent', 'resumeTorrent', 
                               'getFilePriorities', 'setFilePriority', 'getAllTorrents', 'removeTorrent'];
        final actualMethods = methodCalls.map((call) => call.method).toList();
        
        for (final method in expectedMethods) {
          expect(actualMethods, contains(method));
        }
      });
    });

    group('Network and Environment Tests', () {
      test('should work in GitHub Actions environment', () async {
        // Проверяем переменные окружения GitHub Actions
        final isGitHubActions = Platform.environment['GITHUB_ACTIONS'] == 'true';
        final isCI = Platform.environment['CI'] == 'true';
        
        if (isGitHubActions || isCI) {
          print('Running in CI/GitHub Actions environment');
          
          // В CI окружении используем более короткие таймауты
          // и дополнительные проверки
          expect(Platform.environment['RUNNER_OS'], isNotNull);
        }
        
        // Тест должен работать в любом окружении
        final result = await service.addTorrent(sintelMagnetLink, '/tmp/test');
        expect(result['success'], isTrue);
      });

      test('should handle network timeouts gracefully', () async {
        // Симулируем медленную сеть
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('com.neo.neomovies_mobile/torrent'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'addTorrent') {
              // Симулируем задержку сети
              await Future.delayed(const Duration(milliseconds: 100));
              return _handleSintelMethodCall(methodCall);
            }
            return _handleSintelMethodCall(methodCall);
          },
        );
        
        final stopwatch = Stopwatch()..start();
        final result = await service.addTorrent(sintelMagnetLink, '/tmp/test');
        stopwatch.stop();
        
        expect(result['success'], isTrue);
        expect(stopwatch.elapsedMilliseconds, lessThan(5000)); // Максимум 5 секунд
      });

      test('should validate magnet link format', () {
        // Проверяем различные форматы магнет ссылок
        const validMagnets = [
          sintelMagnetLink,
          'magnet:?xt=urn:btih:1234567890abcdef1234567890abcdef12345678&dn=test',
        ];
        
        const invalidMagnets = [
          'not-a-magnet-link',
          'http://example.com/torrent',
          'magnet:invalid',
          '',
        ];
        
        for (final magnet in validMagnets) {
          expect(_isValidMagnetLink(magnet), isTrue, reason: 'Should accept valid magnet: $magnet');
        }
        
        for (final magnet in invalidMagnets) {
          expect(_isValidMagnetLink(magnet), isFalse, reason: 'Should reject invalid magnet: $magnet');
        }
      });
    });

    group('Performance Tests', () {
      test('should handle multiple concurrent operations', () async {
        // Тестируем параллельные операции
        final futures = <Future>[];
        
        // Параллельно выполняем несколько операций
        futures.add(service.addTorrent(sintelMagnetLink, '/tmp/test1'));
        futures.add(service.getAllTorrents());
        futures.add(service.getTorrentInfo(expectedTorrentHash));
        
        final results = await Future.wait(futures);
        
        expect(results.length, 3);
        expect(results[0], isA<Map<String, dynamic>>()); // addTorrent result
        expect(results[1], isA<List<TorrentInfo>>()); // getAllTorrents result  
        expect(results[2], anyOf(isA<TorrentInfo>(), isNull)); // getTorrentInfo result
      });

      test('should complete operations within reasonable time', () async {
        final stopwatch = Stopwatch()..start();
        
        await service.addTorrent(sintelMagnetLink, '/tmp/test');
        await service.getAllTorrents();
        await service.removeTorrent(expectedTorrentHash);
        
        stopwatch.stop();
        
        // Все операции должны завершиться быстро (меньше 1 секунды в тестах)
        expect(stopwatch.elapsedMilliseconds, lessThan(1000));
      });
    });
  });
}

/// Проверяет, является ли строка валидной магнет ссылкой
bool _isValidMagnetLink(String link) {
  if (!link.startsWith('magnet:?')) return false;
  
  // Проверяем наличие xt параметра с BitTorrent hash
  final btihPattern = RegExp(r'xt=urn:btih:[a-fA-F0-9]{40}');
  return btihPattern.hasMatch(link);
}

/// Mock обработчик для Sintel торрента
dynamic _handleSintelMethodCall(MethodCall methodCall) {
  switch (methodCall.method) {
    case 'addTorrent':
      final magnetUri = methodCall.arguments['magnetUri'] as String;
      if (magnetUri.contains('08ada5a7a6183aae1e09d831df6748d566095a10')) {
        return {
          'success': true,
          'torrentHash': '08ada5a7a6183aae1e09d831df6748d566095a10',
        };
      }
      return {'success': false, 'error': 'Invalid magnet link'};

    case 'getTorrentInfo':
      final hash = methodCall.arguments['torrentHash'] as String;
      if (hash == '08ada5a7a6183aae1e09d831df6748d566095a10') {
        return _getSintelTorrentData();
      }
      return null;

    case 'getAllTorrents':
      return [_getSintelTorrentData()];

    case 'pauseTorrent':
    case 'resumeTorrent':
    case 'removeTorrent':
      return {'success': true};

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
        message: 'Method ${methodCall.method} not implemented in mock',
      );
  }
}

/// Возвращает mock данные для Sintel торрента
Map<String, dynamic> _getSintelTorrentData() {
  return {
    'name': 'Sintel (2010) [1080p]',
    'infoHash': '08ada5a7a6183aae1e09d831df6748d566095a10',
    'state': 'downloading',
    'progress': 0.15, // 15% загружено
    'downloadSpeed': 1500000, // 1.5 MB/s
    'uploadSpeed': 200000, // 200 KB/s
    'totalSize': 734003200, // ~700 MB
    'downloadedSize': 110100480, // ~105 MB
    'seeders': 45,
    'leechers': 12,
    'ratio': 0.8,
    'addedTime': DateTime.now().subtract(const Duration(minutes: 30)).millisecondsSinceEpoch,
    'files': [
      {
        'name': 'Sintel.2010.1080p.mkv',
        'size': 734003200,
        'path': '/storage/emulated/0/Download/Torrents/Sintel/Sintel.2010.1080p.mkv',
        'priority': FilePriority.high.value,
      },
      {
        'name': 'Sintel.2010.720p.mp4',
        'size': 367001600, // ~350 MB
        'path': '/storage/emulated/0/Download/Torrents/Sintel/Sintel.2010.720p.mp4',
        'priority': FilePriority.normal.value,
      },
      {
        'name': 'subtitles/Sintel.srt',
        'size': 52428, // ~51 KB
        'path': '/storage/emulated/0/Download/Torrents/Sintel/subtitles/Sintel.srt',
        'priority': FilePriority.normal.value,
      },
      {
        'name': 'README.txt',
        'size': 2048,
        'path': '/storage/emulated/0/Download/Torrents/Sintel/README.txt',
        'priority': FilePriority.low.value,
      },
    ],
  };
}