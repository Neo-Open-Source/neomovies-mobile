# NeoMovies Mobile 🎬

Мобильное приложение для просмотра фильмов и сериалов, созданное на Flutter.

[![Download](https://img.shields.io/github/v/release/Neo-Open-Source/neomovies-mobile?label=Download&style=for-the-badge&logo=github)](https://github.com/Neo-Open-Source/neomovies-mobile/releases/latest)

## Возможности

- 📱 Кроссплатформенное приложение (Android/iOS(пока не реализовано))
- 🎥 Просмотр фильмов и сериалов через WebView
- 🌙 Поддержка динамической темы
- 💾 Локальное кэширование данных
- 🔒 Безопасное хранение данных
- 🚀 Быстрая загрузка контента
- 🎨 Современный Material Design интерфейс

## Технологии

- **Flutter** - основной фреймворк
- **Provider** - управление состоянием
- **Hive** - локальная база данных
- **HTTP** - сетевые запросы
- **WebView** - воспроизведение видео
- **Cached Network Image** - кэширование изображений
- **Google Fonts** - красивые шрифты

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
API_URL=your_api_url_here
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

### iOS
```bash
flutter build ios --release
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
- **iOS**: iOS 11.0+

## Участие в разработке

1. Форкните репозиторий
2. Создайте ветку для новой функции (`git checkout -b feature/amazing-feature`)
3. Внесите изменения и закоммитьте (`git commit -m 'Add amazing feature'`)
4. Отправьте изменения в ветку (`git push origin feature/amazing-feature`)
5. Создайте Pull Request

## Лицензия

Этот проект лицензирован под Apache 2.0 License - подробности в файле [LICENSE](LICENSE).

## Контакты

Если у вас есть вопросы или предложения, создайте issue в этом репозитории.