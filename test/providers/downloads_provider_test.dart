import 'package:flutter_test/flutter_test.dart';
import 'package:neomovies_mobile/presentation/providers/downloads_provider.dart';

void main() {
  group('DownloadsProvider', () {
    late DownloadsProvider provider;

    setUp(() {
      provider = DownloadsProvider();
    });

    tearDown(() {
      provider.dispose();
    });

    test('initial state is correct', () {
      expect(provider.torrents, isEmpty);
      expect(provider.isLoading, isFalse);
      expect(provider.error, isNull);
    });

    test('formatSpeed formats bytes correctly', () {
      expect(provider.formatSpeed(1024), equals('1.0KB/s'));
      expect(provider.formatSpeed(1048576), equals('1.0MB/s'));
      expect(provider.formatSpeed(512), equals('512B/s'));
      expect(provider.formatSpeed(2048000), equals('2.0MB/s'));
    });

    test('formatDuration formats duration correctly', () {
      expect(provider.formatDuration(Duration(seconds: 30)), equals('30с'));
      expect(provider.formatDuration(Duration(minutes: 2, seconds: 30)), equals('2м 30с'));
      expect(provider.formatDuration(Duration(hours: 1, minutes: 30, seconds: 45)), equals('1ч 30м 45с'));
      expect(provider.formatDuration(Duration(hours: 2)), equals('2ч 0м 0с'));
    });

    test('provider implements ChangeNotifier', () {
      expect(provider, isA<ChangeNotifier>());
    });
  });
}