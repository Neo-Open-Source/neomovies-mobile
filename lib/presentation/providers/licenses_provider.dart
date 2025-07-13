import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yaml/yaml.dart';

import '../../data/models/library_license.dart';

const Map<String, String> _licenseOverrides = {
  'archive': 'MIT',
  'args': 'BSD-3-Clause',
  'async': 'BSD-3-Clause',
  'boolean_selector': 'BSD-3-Clause',
  'characters': 'BSD-3-Clause',
  'clock': 'Apache-2.0',
  'collection': 'BSD-3-Clause',
  'convert': 'BSD-3-Clause',
  'crypto': 'BSD-3-Clause',
  'cupertino_icons': 'MIT',
  'dbus': 'MIT',
  'fake_async': 'Apache-2.0',
  'file': 'Apache-2.0',
  'flutter_lints': 'BSD-3-Clause',
  'flutter_secure_storage_linux': 'BSD-3-Clause',
  'flutter_secure_storage_macos': 'BSD-3-Clause',
  'flutter_secure_storage_platform_interface': 'BSD-3-Clause',
  'flutter_secure_storage_web': 'BSD-3-Clause',
  'flutter_secure_storage_windows': 'BSD-3-Clause',
  'http_parser': 'BSD-3-Clause',
  'intl': 'BSD-3-Clause',
  'js': 'BSD-3-Clause',
  'leak_tracker': 'BSD-3-Clause',
  'lints': 'BSD-3-Clause',
  'matcher': 'BSD-3-Clause',
  'material_color_utilities': 'BSD-3-Clause',
  'meta': 'BSD-3-Clause',
  'petitparser': 'MIT',
  'platform': 'BSD-3-Clause',
  'plugin_platform_interface': 'BSD-3-Clause',
  'pool': 'BSD-3-Clause',
  'posix': 'MIT',
  'source_span': 'BSD-3-Clause',
  'stack_trace': 'BSD-3-Clause',
  'stream_channel': 'BSD-3-Clause',
  'string_scanner': 'BSD-3-Clause',
  'term_glyph': 'BSD-3-Clause',
  'test_api': 'BSD-3-Clause',
  'typed_data': 'BSD-3-Clause',
  'uuid': 'MIT',
  'vector_math': 'BSD-3-Clause',
  'vm_service': 'BSD-3-Clause',
  'win32': 'BSD-3-Clause',
  'xdg_directories': 'MIT',
  'xml': 'MIT',
  'yaml': 'MIT',
};

class LicensesProvider with ChangeNotifier {
  final ValueNotifier<List<LibraryLicense>> _licenses = ValueNotifier([]);
  final ValueNotifier<bool> _isLoading = ValueNotifier(false);
  final ValueNotifier<String?> _error = ValueNotifier(null);

  LicensesProvider() {
    loadLicenses();
  }

  ValueNotifier<List<LibraryLicense>> get licenses => _licenses;
  ValueNotifier<bool> get isLoading => _isLoading;
  ValueNotifier<String?> get error => _error;

  Future<void> loadLicenses({bool forceRefresh = false}) async {
    _isLoading.value = true;
    _error.value = null;

    try {
      final cachedLicenses = await _loadFromCache();
      if (cachedLicenses != null && !forceRefresh) {
        _licenses.value = cachedLicenses;
        // Still trigger background update for licenses that were loading or failed
        final toUpdate = cachedLicenses.where((l) => l.license == 'loading...' || l.license == 'unknown').toList();
        if (toUpdate.isNotEmpty) {
          _fetchFullLicenseInfo(toUpdate);
        }
      } else {
        _licenses.value = await _fetchInitialLicenses();
        _fetchFullLicenseInfo(_licenses.value.where((l) => l.license == 'loading...').toList());
      }
    } catch (e) {
      _error.value = 'Failed to load licenses: $e';
    }

    _isLoading.value = false;
  }

  Future<List<LibraryLicense>?> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('licenses_cache');
      if (jsonStr != null) {
        final List<dynamic> jsonList = jsonDecode(jsonStr);
        return jsonList.map((e) => LibraryLicense.fromMap(e)).toList();
      }
    } catch (_) {}
    return null;
  }

  Future<List<LibraryLicense>> _fetchInitialLicenses() async {
    final result = <LibraryLicense>[];
    try {
      final lockFileContent = await rootBundle.loadString('pubspec.lock');
      final doc = loadYaml(lockFileContent);
      final packages = doc['packages'] as YamlMap;

      final pubspecContent = await rootBundle.loadString('pubspec.yaml');
      final pubspec = loadYaml(pubspecContent);
      result.add(LibraryLicense(
        name: pubspec['name'],
        version: pubspec['version'],
        license: 'Apache 2.0',
        url: 'https://gitlab.com/foxixius/neomovies_mobile',
        description: pubspec['description'],
      ));

      for (final key in packages.keys) {
        final name = key.toString();
        final package = packages[key];
        if (package['source'] != 'hosted') continue;

        final version = package['version'].toString();
        result.add(LibraryLicense(
          name: name,
          version: version,
          license: 'loading...',
          url: 'https://pub.dev/packages/$name',
          description: '',
        ));
      }
    } catch (e) {
      _error.value = 'Failed to load initial license list: $e';
    }
    return result;
  }

  void _fetchFullLicenseInfo(List<LibraryLicense> toFetch) async {
    final futures = toFetch.map((lib) async {
      try {
        final url = 'https://pub.dev/api/packages/${lib.name}';
        final resp = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body) as Map<String, dynamic>;
          final pubspec = data['latest']['pubspec'] as Map<String, dynamic>;
          String licenseType = (pubspec['license'] ?? 'unknown').toString();
          if (licenseType == 'unknown' && _licenseOverrides.containsKey(lib.name)) {
            licenseType = _licenseOverrides[lib.name]!;
          }
          final repoUrl = (pubspec['repository'] ?? pubspec['homepage'] ?? 'https://pub.dev/packages/${lib.name}').toString();
          final description = (pubspec['description'] ?? '').toString();
          return lib.copyWith(license: licenseType, url: repoUrl, description: description);
        }
      } catch (_) {}
      return lib.copyWith(license: 'unknown');
    }).toList();

    final updatedLicenses = await Future.wait(futures);

    final currentList = List<LibraryLicense>.from(_licenses.value);
    bool hasChanged = false;
    for (final updated in updatedLicenses) {
      final index = currentList.indexWhere((e) => e.name == updated.name);
      if (index != -1 && currentList[index].license != updated.license) {
        currentList[index] = updated;
        hasChanged = true;
      }
    }

    if (hasChanged) {
      _licenses.value = currentList;
      _saveToCache(currentList);
    }
  }

  Future<String> fetchLicenseText(LibraryLicense library) async {
    if (library.licenseText != null) return library.licenseText!;

    final cached = (await _loadFromCache())?.firstWhere((e) => e.name == library.name, orElse: () => library);
    if (cached?.licenseText != null) {
      return cached!.licenseText!;
    }

    try {
      final text = await _fetchLicenseTextFromRepo(library.url);
      if (text != null) {
        final updatedLibrary = library.copyWith(licenseText: text);
        final currentList = List<LibraryLicense>.from(_licenses.value);
        final index = currentList.indexWhere((e) => e.name == library.name);
        if (index != -1) {
          currentList[index] = updatedLibrary;
          _licenses.value = currentList;
          _saveToCache(currentList);
        }
        return text;
      }
    } catch (_) {}
    return library.license;
  }

  Future<String?> _fetchLicenseTextFromRepo(String repoUrl) async {
    try {
      final uri = Uri.parse(repoUrl);
      final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (segments.length < 2) return null;

      final author = segments[0];
      final repo = segments[1].replaceAll('.git', '');
      final branches = ['main', 'master', 'HEAD']; // Common branch names
      final filenames = ['LICENSE', 'LICENSE.md', 'LICENSE.txt', 'LICENSE-2.0.txt']; // Common license filenames

      String? rawUrlBase;
      if (repoUrl.contains('github.com')) {
        rawUrlBase = 'https://raw.githubusercontent.com/$author/$repo';
      } else if (repoUrl.contains('gitlab.com')) {
        rawUrlBase = 'https://gitlab.com/$author/$repo/-/raw';
      } else {
        return null; // Unsupported provider
      }

      for (final branch in branches) {
        for (final filename in filenames) {
          final url = '$rawUrlBase/$branch/$filename';
          try {
            final resp = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
            if (resp.statusCode == 200 && resp.body.isNotEmpty) {
              return resp.body;
            }
          } catch (_) {
            // Ignore timeout or other errors and try next candidate
          }
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> _saveToCache(List<LibraryLicense> licenses) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(licenses.map((e) => e.toMap()).toList());
      await prefs.setString('licenses_cache_v2', jsonStr);
    } catch (_) {}
  }
}
