# NeoMovies Mobile 🎬

Мобильное приложение для просмотра фильмов и сериалов, созданное на Flutter.

[![Download](https://img.shields.io/github/v/release/Neo-Open-Source/neomovies-mobile?label=Download&style=for-the-badge&logo=github)](https://github.com/Neo-Open-Source/neomovies-mobile/releases/latest)

## Установка

1. Клонируйте репозиторий:
```bash
git clone https://gitlab.com/foxixus/neomovies_mobile.git
cd neomovies_mobile
```

2. Установите зависимости:
```bash
flutter pub get
```

3. Создайте файл `.env` в корне проекта:
```
API_URL=api.neomovies.ru
```

4. Запустите приложение:
```bash
flutter run
```

## Сборка

### Android APK
```bash
flutter build apk --release
```

## Структура проекта

```
lib/
├── main.dart                 # Точка входа
├── models/                   # Модели данных
├── services/                 # API сервисы
├── providers/                # State management
├── screens/                  # Экраны приложения
├── widgets/                  # Переиспользуемые виджеты
└── utils/                    # Утилиты и константы
```

## Системные требования

- **Flutter SDK**: 3.8.1+
- **Dart**: 3.8.1+
- **Android**: API 21+ (Android 5.0+)

## Лицензия

Apache 2.0 License - [LICENSE](LICENSE).

## Контакты

neo.movies.mail@gmail.com

## Благодарность

Огромная благодарность создателям проекта [LAMPAC](https://github.com/immisterio/Lampac)