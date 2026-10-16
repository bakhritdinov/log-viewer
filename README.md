# LogViewer

Приложение для просмотра и анализа логов из **Grafana** (источники **VictoriaLogs** и **Loki**): на компьютере (Windows, macOS, Linux) и на телефоне (PWA). Написано на **C++20** и **Qt 6 (QML)**.

## 🚀 Возможности

- **Поиск** словами и условиями `key:value`, `key:~regex`, `-key:value`, части через `AND`; подсказки полей и значений по загруженным записям; подсветка найденного; недавние и сохранённые запросы (`Ctrl+1…9`).
- **Источник и период**: namespace и приложение с поиском и недавними, пресеты от 5 минут до 7 дней, «Сегодня», «Вчера» и свой интервал.
- **Загрузка пакетами** до выбранного предела с «Загрузить ещё» и остановкой; обновление не стирает показанные записи, пока не пришли новые; автообновление.
- **Гистограмма** ERROR / WARN по времени: клик по столбцу или уровню сужает выборку.
- **Детали записи**: сообщение (красивый JSON или запись целиком), поля с «показать только» / «исключить» / «копировать», поле как колонка таблицы.
- **Контекст и трейс** вокруг записи (±30 с / ±1 мин / ±5 мин, записи того же `trace_id` во всех сервисах).
- **Шаблоны**: похожие WARN и ERROR сгруппированы (числа, id и время становятся `*`), с количеством, трендом и значениями переменных.
- **Live tail**: новые строки сверху, пауза, буфер.
- **Ссылки «Поделиться»** на выборку (`logviewer://…` на компьютере, адрес PWA на телефоне) с фиксированным или относительным периодом и выделенной записью.
- **Окружения** (DEV, PROD и свои) с проверкой подключения; пароли и токены — в системном хранилище ключей.
- **Языки**: русский, oʻzbekcha, English. **Темы**: тёмная, светлая, как в системе.

## 📦 Установка

### Windows (Chocolatey)
```powershell
choco install log-viewer
```
Обновление: `choco upgrade log-viewer`.

### macOS (Homebrew)
```bash
brew install --cask bakhritdinov/tap/log-viewer
```
Обновление: `brew upgrade --cask log-viewer`.

### Linux (AppImage)
Скачайте `LogViewer-Linux.AppImage` со страницы релизов, сделайте исполняемым и запустите — Qt внутри, установка не нужна:
```bash
chmod +x LogViewer-Linux.AppImage
./LogViewer-Linux.AppImage
```
Пакеты PPA и `.deb` выпускались для версий 2.x: системный Qt в Ubuntu 22.04/24.04 старше нужного 3.x Qt 6.8.

### Телефон (PWA)
Откройте **https://bakhritdinov.github.io/log-viewer/** в Chrome (Android) или Safari (iOS) и установите на экран — приложение предложит это само. Grafana должна разрешить этот адрес (CORS) — см. [docs/PWA.md](docs/PWA.md).

### Прямая загрузка
Все сборки — на странице релизов: 👉 **[github.com/bakhritdinov/log-viewer/releases/latest](https://github.com/bakhritdinov/log-viewer/releases/latest)**

- Windows: `LogViewer-Windows-x64.exe` (установщик) или `LogViewer-Windows-Portable.zip`.
- macOS: `LogViewer-macOS-Universal.dmg` (Intel + Apple Silicon).
- Linux: `LogViewer-Linux.AppImage`.
- PWA для своего сервера: `LogViewer-PWA.zip`.

### Переход с 2.x
При первом запуске 3.x берёт окружения, логины, пароли и токены, последний источник, период и тему версии 2.x — вводить заново ничего не нужно. Настройки 2.x остаются на месте: кто не обновился, продолжает работать как раньше. Настройки Ecotone (его больше нет) удаляются.

## 🖥 Использование

### Первый запуск
1. Откройте **Настройки → Подключения** (`Ctrl+,`).
2. Для окружения (DEV, PROD или нового) укажите:
   - **URL Grafana**, например `https://grafana.example.com`;
   - **UID источника логов** (Grafana → Connections → Data sources → последняя часть URL);
   - авторизацию: **логин и пароль**, **API-токен** сервис-аккаунта или без неё.
3. **Проверить подключение** → **Сохранить и подключиться**. Namespace и приложения находятся автоматически.

### Сочетания клавиш

| Клавиша | Действие |
|---|---|
| `F5` / `Ctrl+R` | Обновить |
| `Ctrl+K` | Выбрать источник |
| `Ctrl+T` | Выбрать период |
| `Ctrl+L` | Поделиться ссылкой |
| `Ctrl+,` | Настройки |
| `?` | Все сочетания клавиш |
| `Ctrl+F` | Поиск |
| `Ctrl+S` | Сохранить запрос |
| `Ctrl+1…9` | Запустить сохранённый запрос |
| `Tab` | Принять подсказку |
| `↑` / `↓` | Предыдущая / следующая запись |
| `[` / `]` | Страница новее / старее |
| `Shift+[` / `Shift+]` | Первая / последняя страница |
| `Esc` | Закрыть детали или фокус; остановить загрузку |
| `Space` | Пауза / продолжение live tail |

## 📊 Логи

Namespace и приложение определяются автоматически по меткам потока (`_namespace` / `namespace` / …, `_appName` / `app` / `service` / `job` …); если в ваших логах другие метки, задайте их в окружении (на компьютере — раздел «Дополнительно», на телефоне — «Свои метки»). Желательны поля `level` (цвета и фильтры по уровню) и `trace_id` (трейс вокруг записи).

## 🛠 Сборка

### Требования
- CMake 3.16+, компилятор с C++20 (MSVC 2022, GCC 11+, Clang 14+).
- Qt 6.8+: Core, Quick, Quick Controls 2, Quick Shapes, Network, Linguist Tools.
- Linux: `libsecret-1-dev` (пароли в Secret Service). QtKeychain скачивается при конфигурации.

### Компьютер
```bash
git clone https://github.com/bakhritdinov/log-viewer.git
cd log-viewer
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j

./build/LogViewer          # Linux
open build/LogViewer.app   # macOS
build\LogViewer.exe        # Windows
```

Тесты: `-DLOGVIEWER_TESTS=ON`, затем `ctest --test-dir build`. Мобильный интерфейс на компьютере (для разработки): `-DLOGVIEWER_UI=mobile`.

### Браузер (PWA)
Qt 6.8 для WebAssembly (`wasm_singlethread`) и Emscripten 3.1.56:
```bash
<qt-wasm>/bin/qt-cmake -S . -B build-wasm -DCMAKE_BUILD_TYPE=Release -DQT_HOST_PATH=<qt-desktop>
cmake --build build-wasm --target LogViewer
```
Страница, манифест, service worker и иконки появляются рядом с `LogViewer.wasm` в `build-wasm/src/platform`.

### Устройство кода
`src/core` (логика, без UI) → `src/app` (view-модели) → `src/ui/shared` (общие компоненты) → `src/ui/desktop` или `src/ui/mobile` (дизайн выбирается при сборке) → `src/platform` (запуск, хранилище ключей, ссылки, страница PWA). План и решения переписывания — [docs/REWRITE_PLAN.md](docs/REWRITE_PLAN.md).
