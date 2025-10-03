# Integration Tests

Этот каталог содержит интеграционные тесты для NeoMovies Mobile App.

## Описание тестов

### `torrent_integration_test.dart`
Тестирует торрент функциональность с использованием реальной магнет ссылки на короткометражный фильм **Sintel** от Blender Foundation.

**Что тестируется:**
- ✅ Парсинг реальной магнет ссылки
- ✅ Добавление, пауза, возобновление и удаление торрентов
- ✅ Получение информации о торрентах и файлах
- ✅ Управление приоритетами файлов
- ✅ Обнаружение видео файлов
- ✅ Производительность операций
- ✅ Обработка ошибок и таймаутов

**Используемые данные:**
- **Фильм**: Sintel (2010) - официальный короткометражный фильм от Blender Foundation
- **Лицензия**: Creative Commons Attribution 3.0
- **Размер**: ~700MB (1080p версия)
- **Официальный сайт**: https://durian.blender.org/

### `ci_environment_test.dart`
Проверяет корректность работы тестового окружения в CI/CD pipeline.

**Что тестируется:**
- ✅ Определение GitHub Actions окружения
- ✅ Валидация Dart/Flutter среды
- ✅ Проверка сетевого подключения
- ✅ Доступность тестовой инфраструктуры

## Запуск тестов

### Локально
```bash
# Все интеграционные тесты
flutter test test/integration/

# Конкретный тест
flutter test test/integration/torrent_integration_test.dart
flutter test test/integration/ci_environment_test.dart
```

### В GitHub Actions
Тесты автоматически запускаются в CI pipeline:
```yaml
- name: Run Integration tests  
  run: flutter test test/integration/ --reporter=expanded
  env:
    CI: true
    GITHUB_ACTIONS: true
```

## Особенности

### Mock Platform Channel
Все тесты используют mock Android platform channel, поэтому:
- ❌ Реальная загрузка торрентов НЕ происходит
- ✅ Тестируется вся логика обработки без Android зависимостей
- ✅ Работают на любой платформе (Linux/macOS/Windows)
- ✅ Быстрое выполнение в CI

### Переменные окружения
Тесты адаптируются под разные окружения:
- `GITHUB_ACTIONS=true` - запуск в GitHub Actions
- `CI=true` - запуск в любой CI системе
- `RUNNER_OS` - операционная система в GitHub Actions

### Безопасность
- Используется только **открытый контент** под Creative Commons лицензией
- Никакие авторские права не нарушаются
- Mock тесты не выполняют реальные сетевые операции

## Магнет ссылка Sintel

```
magnet:?xt=urn:btih:08ada5a7a6183aae1e09d831df6748d566095a10
&dn=Sintel
&tr=udp://tracker.opentrackr.org:1337
&ws=https://webtorrent.io/torrents/
```

**Почему Sintel?**
- 🎬 Профессиональное качество (3D анимация)
- 📜 Свободная лицензия (Creative Commons)
- 🌐 Широко доступен в торрент сетях
- 🧪 Часто используется для тестирования
- 📏 Подходящий размер для тестов (~700MB)

## Troubleshooting

### Таймауты в CI
Если тесты превышают лимиты времени:
```dart
// Увеличьте таймауты для CI
final timeout = Platform.environment['CI'] == 'true' 
    ? Duration(seconds: 10) 
    : Duration(seconds: 5);
```

### Сетевые ошибки
В ограниченных CI средах:
```dart
try {
  // Сетевая операция
} catch (e) {
  // Graceful fallback
  print('Network unavailable in CI: $e');
}
```

### Platform Channel ошибки
Убедитесь, что mock правильно настроен:
```dart
TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
    .setMockMethodCallHandler(
  const MethodChannel('com.neo.neomovies_mobile/torrent'),
  (MethodCall methodCall) async {
    return _handleMethodCall(methodCall);
  },
);
```