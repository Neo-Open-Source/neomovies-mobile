# NeoMovies Mobile (Expo)

Новый кроссплатформенный клиент NeoMovies на Expo/React Native с собственным UI/UX, без Material 3-стиля.

## Что уже сделано

- Базовая архитектура Expo Router (`Home` + `Search` tab).
- Новый визуальный foundation (цвета, радиусы, spacing).
- Подключен API-слой к `https://api.neomovies.ru/api/v1`.
- Экран `Home` загружает `/movies/popular`.
- Экран `Search` работает с `/search`.
- Подготовлен план для нативных расширений (`Kotlin + Rust` и `Swift`).

## Запуск

```bash
cp .env.example .env
pnpm install
pnpm start
```

## Переменные окружения

- `EXPO_PUBLIC_API_BASE_URL` — базовый URL `neomovies-api` (по умолчанию `https://api.neomovies.ru/api/v1`)
- `EXPO_PUBLIC_NEO_ID_BASE_URL` — URL NeoID (по умолчанию `https://id.neomovies.ru`)

Важно: секреты NeoID (`API_SECRET`, `API_KEY` и т.п.) нельзя хранить в мобильном клиенте.  
Они должны оставаться только на backend (`neomovies-api`).

## Следующий этап

- Подключить Neo ID OAuth/OIDC flow (`https://id.neomovies.ru`).
- Добавить хранение токенов и refresh flow.
- Вынести нативный модуль `neomovies-core` (Expo Modules).
