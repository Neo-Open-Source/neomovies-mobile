# 🚀 CI/CD Configuration для NeoMovies Mobile

## 📋 Обзор

Автоматическая сборка APK и TorrentEngine модуля с оптимизацией использования RAM.

---

## 🏗️ Конфигурации

### 1. **GitLab CI/CD** (`.gitlab-ci.yml`)

Основная конфигурация для GitLab:

#### **Stages:**
- **build** - Сборка APK и AAR
- **test** - Анализ кода и тесты
- **deploy** - Публикация релизов

#### **Jobs:**

| Job | Описание | Артефакты | Ветки |
|-----|----------|-----------|-------|
| `build:torrent-engine` | Сборка TorrentEngine AAR | `*.aar` | dev, feature/*, MR |
| `build:apk-debug` | Сборка Debug APK | `app-debug.apk` | dev, feature/*, MR |
| `build:apk-release` | Сборка Release APK | `app-arm64-v8a-release.apk` | только dev |
| `test:flutter-analyze` | Анализ Dart кода | - | dev, MR |
| `test:android-lint` | Android Lint | HTML отчеты | dev, MR |
| `deploy:release` | Публикация релиза | - | только tags (manual) |

### 2. **GitHub Actions** (`.github/workflows/build.yml`)

Альтернативная конфигурация для GitHub:

#### **Workflows:**

| Workflow | Триггер | Описание |
|----------|---------|----------|
| `build-torrent-engine` | push, PR | Сборка AAR модуля |
| `build-debug-apk` | push, PR | Debug APK для тестирования |
| `build-release-apk` | push to dev | Release APK (split-per-abi) |
| `code-quality` | push, PR | Flutter analyze + Android Lint |

---

## ⚙️ Оптимизация RAM

### **gradle.properties**

```properties
# Уменьшено с 4GB до 2GB
org.gradle.jvmargs=-Xmx2G -XX:MaxMetaspaceSize=1G

# Kotlin daemon с ограничением
kotlin.daemon.jvmargs=-Xmx1G -XX:MaxMetaspaceSize=512m

# Включены оптимизации
org.gradle.parallel=true
org.gradle.caching=true
org.gradle.configureondemand=true
```

### **CI переменные**

```bash
# В CI используется еще меньше RAM
GRADLE_OPTS="-Xmx1536m -XX:MaxMetaspaceSize=512m"
```

---

## 📦 Артефакты

### **TorrentEngine AAR:**
- Путь: `android/torrentengine/build/outputs/aar/`
- Файл: `torrentengine-release.aar`
- Срок хранения: 7 дней
- Размер: ~5-10 MB

### **Debug APK:**
- Путь: `build/app/outputs/flutter-apk/`
- Файл: `app-debug.apk`
- Срок хранения: 7 дней
- Размер: ~50-80 MB

### **Release APK:**
- Путь: `build/app/outputs/flutter-apk/`
- Файл: `app-arm64-v8a-release.apk`
- Срок хранения: 30 дней
- Размер: ~30-50 MB (split-per-abi)

---

## 🚦 Триггеры сборки

### **GitLab:**

**Автоматически запускается при:**
- Push в `dev` ветку
- Push в `feature/torrent-engine-integration`
- Создание Merge Request
- Push тега (для deploy)

**Ручной запуск:**
- Web UI → Pipelines → Run Pipeline
- Выбрать ветку и нажать "Run pipeline"

### **GitHub:**

**Автоматически запускается при:**
- Push в `dev` или `feature/torrent-engine-integration`
- Pull Request в `dev`

**Ручной запуск:**
- Actions → Build NeoMovies Mobile → Run workflow

---

## 🔧 Настройка GitLab Runner

Для локального тестирования CI/CD:

```bash
# 1. Установка GitLab Runner
curl -L https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh | sudo bash
sudo apt-get install gitlab-runner

# 2. Регистрация Runner
sudo gitlab-runner register \
  --url https://gitlab.com/ \
  --registration-token YOUR_TOKEN \
  --executor docker \
  --docker-image mingc/android-build-box:latest \
  --tag-list docker,android

# 3. Запуск
sudo gitlab-runner start
```

---

## 📊 Время сборки (примерно)

| Job | Время | RAM | CPU |
|-----|-------|-----|-----|
| TorrentEngine | ~5-10 мин | 1.5GB | 2 cores |
| Debug APK | ~15-20 мин | 2GB | 2 cores |
| Release APK | ~20-30 мин | 2GB | 2 cores |
| Flutter Analyze | ~2-3 мин | 512MB | 1 core |
| Android Lint | ~5-8 мин | 1GB | 2 cores |

---

## 🐳 Docker образы

### **mingc/android-build-box:latest**

Включает:
- Android SDK (latest)
- Flutter SDK
- Java 17
- Gradle
- Git, curl, wget

Размер: ~8GB

---

## 🔍 Кэширование

Для ускорения сборок используется кэширование:

```yaml
cache:
  paths:
    - .gradle/           # Gradle dependencies
    - .pub-cache/        # Flutter packages
    - android/.gradle/   # Android build cache
    - build/             # Flutter build cache
```

**Эффект:**
- Первая сборка: ~25 минут
- Последующие: ~10-15 минут (с кэшем)

---

## 📝 Логи и отладка

### **Просмотр логов GitLab:**

1. Перейти в **CI/CD → Pipelines**
2. Выбрать pipeline
3. Кликнуть на job для просмотра логов

### **Отладка локально:**

```bash
# Тестирование сборки TorrentEngine
cd android
./gradlew :torrentengine:assembleRelease \
  --no-daemon \
  --parallel \
  --stacktrace

# Тестирование Flutter APK
flutter build apk --debug --verbose
```

---

## 🚨 Troubleshooting

### **Gradle daemon crashed:**

**Проблема:** `Gradle build daemon disappeared unexpectedly`

**Решение:**
```bash
# Увеличить RAM в gradle.properties
org.gradle.jvmargs=-Xmx3G

# Или отключить daemon
./gradlew --no-daemon
```

### **Out of memory:**

**Проблема:** `OutOfMemoryError: Java heap space`

**Решение:**
```bash
# Увеличить heap в CI
GRADLE_OPTS="-Xmx2048m -XX:MaxMetaspaceSize=768m"
```

### **LibTorrent4j native libraries not found:**

**Проблема:** Нативные библиотеки не найдены

**Решение:**
- Убедиться что все архитектуры включены в `build.gradle.kts`
- Проверить `splits.abi` конфигурацию

---

## 📚 Дополнительные ресурсы

- [GitLab CI/CD Docs](https://docs.gitlab.com/ee/ci/)
- [GitHub Actions Docs](https://docs.github.com/actions)
- [Flutter CI/CD Guide](https://docs.flutter.dev/deployment/cd)
- [Gradle Performance](https://docs.gradle.org/current/userguide/performance.html)

---

## 🎯 Следующие шаги

1. **Настроить GitLab Runner** (если еще не настроен)
2. **Запушить изменения** в dev ветку
3. **Проверить Pipeline** в GitLab CI/CD
4. **Скачать артефакты** после успешной сборки
5. **Протестировать APK** на реальном устройстве

---

## 📞 Поддержка

При проблемах с CI/CD:
1. Проверьте логи pipeline
2. Убедитесь что Runner активен
3. Проверьте доступность Docker образа
4. Создайте issue с логами ошибки

---

**Создано с ❤️ для NeoMovies Mobile**
