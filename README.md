# LogViewer

Высокопроизводительное десктопное приложение для просмотра и анализа логов из **Grafana** с источниками данных **Loki** и **VictoriaLogs**. Написано на **C++20** и **Qt 6 (QML)**.

## 🚀 Возможности

- **Поиск с подсветкой**: LogsQL/LogQL, моментальный поиск через debounce, подсветка совпадений прямо в строке.
- **История поиска**: автозапись последних 10 запросов, выпадашка с быстрым восстановлением.
- **Inline-раскрытие деталей**: клик по строке плавно показывает полное сообщение и все поля с действиями `🔍` (фильтр) и `📋` (копировать).
- **Адаптивная таблица**: колонки Time/Level/Service/Message сами подстраиваются под ширину окна, message переходит в multi-line на узких экранах. Колонки можно тащить за разделители — ширина запоминается.
- **Пагинация по времени**: page-based, кнопки `« First / ‹ Newer / Older › / Last »` + индикатор страницы.
- **Обзор полей (Available Fields)**: overlay-сайдбар с фасетами всех значений за выбранный диапазон, клик → toggle-фильтр.
- **Auto-refresh и Tail-режим**: split-кнопка `↻ + ▾` рядом с поиском — выбрать `5s / 10s / 30s / 1m` или `Tail` (= `tail -f`, прыжок на самую свежую страницу).
- **Time-range picker (Grafana-стиль)**: presets `Last 5 min — 7 days, Today` + absolute From/To с календарём.
- **Темы Dark / Light**: переключение `🌙 / ☀` в тулбаре, выбор сохраняется.
- **Discovery namespace/app**: автоматическое определение метов (`_namespace`, `namespace`, `env`, `project` для NS; `_appName`, `app`, `service`, `job` для App), полное перечисление через LogsQL stats.
- **Persistence**: запоминается последний выбранный namespace, app, time range, ширины колонок, тема, история поиска.
- **Keyboard shortcuts**: `j/k`/`↑↓` навигация, `Enter` раскрыть, `[/]` страница назад/вперёд, `Shift+[/]` First/Last, `F5` refresh, `⌘F` поиск, `Esc` сброс.

## 📦 Установка

### Windows (Chocolatey)
```powershell
choco install log-viewer
```
Обновление до последней версии:
```powershell
choco upgrade log-viewer
```

### macOS (Homebrew)
```bash
brew install --cask bakhritdinov/tap/log-viewer
```
Обновление:
```bash
brew upgrade --cask log-viewer
```

### Ubuntu (PPA)
```bash
sudo add-apt-repository ppa:bakhritdinov/log-viewer
sudo apt update
sudo apt install log-viewer
```
Обновление:
```bash
sudo apt update && sudo apt upgrade log-viewer
```

### Прямая загрузка
Установщики и portable-сборки для всех платформ доступны на странице релизов:

👉 **[github.com/bakhritdinov/log-viewer/releases/latest](https://github.com/bakhritdinov/log-viewer/releases/latest)**

- Windows: `LogViewer-Windows-x64.exe` (NSIS-installer) или `LogViewer-Windows-Portable.zip`.
- macOS: `LogViewer-macOS-Universal.dmg` (Intel + Apple Silicon).
- Linux: `LogViewer-Linux.AppImage` (никакая установка не нужна) или `.deb`.

## 🛠 Технологический стек

- **Язык**: C++ 20
- **Фреймворк**: Qt 6.x (Core, Quick, Network, Svg, Gui)
- **UI**: QML + Qt Quick Controls 2 (singleton-Theme, переиспользуемые компоненты)
- **Сборка**: CMake 3.16+
- **Стиль**: GitHub Dark / Light themes

## 📦 Сборка проекта

### Требования
- CMake 3.16 или выше
- Qt 6 (модули: Core, Quick, Network, Svg, Gui)
- Компилятор с поддержкой C++ 20 (GCC 10+, Clang 11+, MSVC 2019+)

### Инструкция по сборке

```bash
git clone https://github.com/bakhritdinov/log-viewer.git
cd log-viewer

cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j

# Запуск
./build/LogViewer            # Linux
open build/LogViewer.app     # macOS
build\LogViewer.exe          # Windows
```

## 🖥 Использование

### Настройка подключения
1. Запустите приложение.
2. Нажмите `⚙ Settings` в правом верхнем углу.
3. Заполните для DEV и/или PROD:
   - **Grafana URL** — базовый URL вашего Grafana, например `https://grafana.example.com`.
   - **Datasource UID** — UID источника данных Loki/VictoriaLogs.
   - **API Token** — рекомендуется (Bearer-токен сервис-аккаунта Grafana).
   - **Login / Password** — fallback Basic auth, если не используете токен.
4. **Save** → переключайтесь между DEV и PROD сегментами в верхней панели.

### Сочетания клавиш

| Клавиша | Действие |
|---|---|
| `⌘F` / `Ctrl+F` | Фокус на поле поиска |
| `Esc` | Очистить поиск, вернуть фокус таблице |
| `F5` | Обновить запрос |
| `j` / `↓` | Следующая строка |
| `k` / `↑` | Предыдущая строка |
| `Enter` / `Space` | Раскрыть/свернуть детали строки |
| `[` / `]` | Page Newer / Older |
| `Shift+[` / `Shift+]` | First / Last page |

## 📊 Структура данных (Loki / VictoriaLogs)

Для корректной работы фильтрации логи должны иметь определённые метки:

### Обязательные (автоопределение)
- **Namespace label** — для группировки по окружению (по умолчанию `_namespace`, fallback: `namespace`, `env`, `project`).
- **App label** — для идентификации сервиса (по умолчанию `_appName`, fallback: `app`, `service`, `job`).

### Рекомендуемые
- `level` — для цветовой индикации (ERROR красный, WARN жёлтый, INFO нейтрально). Если метки нет — пытается найти в теле сообщения.
- `trace_id` / `traceId` — клик правой кнопкой → «Fetch Trace Context (±5m)».
- `pod` / `host.name` — отображается как источник.

### Структура сообщения
- **Time** / **ts** — временная метка.
- **Line** / **message** — текст сообщения.

---

Разработано для эффективного мониторинга и отладки микросервисов.
