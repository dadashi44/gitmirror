# gitmirror

Переносит вашу коммит-активность из приватных репозиториев (GitLab, Bitbucket,
самохостед — что угодно) в репозиторий-зеркало на GitHub, чтобы работа вне
GitHub отражалась в графике вкладов.

В зеркало попадают **только пустые коммиты** с датами авторства оригиналов.
Ни исходного кода, ни оригинальных сообщений коммитов — ничего, что может
утечь наружу вместе с рабочим проектом.

## Установка

```sh
git clone <этот-репозиторий> ~/gitmirror
ln -s ~/gitmirror/bin/gitmirror /usr/local/bin/gitmirror
```

Зависимости: bash, git, стандартный coreutils. Работает на macOS (bash 3.2) и Linux.

## Структура

```
bin/gitmirror   точка входа: разбор аргументов и маршрутизация
lib/core.sh               вывод, ошибки, временный каталог
lib/ui.sh                 справка, вопросы в терминале, подтверждения
lib/config.sh             поиск зеркала, чтение и запись .gitmirror
lib/git.sh                всё, что знает про устройство git-репозиториев
lib/commands/*.sh         по файлу на команду: setup, init, add, sync, status
```

Точка входа резолвит симлинки, поэтому её можно класть в `PATH` ссылкой.
Библиотеки только объявляют функции — `set -euo pipefail` живёт в `bin/`.

## Быстрый старт

```sh
gitmirror setup
```

Скрипт спросит всё в терминале: каталог зеркала, имя и почту для коммитов,
пути к репозиториям-источникам, GitHub remote — и предложит сразу
синхронизироваться.

Дальше, после каждого рабочего дня:

```sh
gitmirror sync
```

## Команды

| Команда | Что делает |
|---|---|
| `setup` | интерактивная настройка с нуля |
| `init [каталог]` | создать зеркало (спросит имя и почты) |
| `add [путь]` | добавить источник; метка берётся из `origin` |
| `sync` | добавить недостающие коммиты и запушить |
| `status` | статистика: сколько коммитов, по источникам, по годам |
| `sources` | список источников |

Флаги `sync`: `--dry-run`, `--no-push`, `--no-fetch`, `--since ГГГГ-ММ-ДД`.
Общий флаг: `--mirror <каталог>`; вместо него можно задать `$GITMIRROR_DIR`.

## Как это работает

1. В каждом источнике берутся все коммиты (`git log --all`), где автор — одна
   из ваших почт. Мерж-коммиты включаются, squash-мержи тоже.
2. Для каждого создаётся пустой коммит с тем же `GIT_AUTHOR_DATE`
   и сообщением `activity <дата> (<метка>@<короткий-sha>)`.
3. Это сообщение служит ключом дедупликации: повторный `sync` не создаст дублей.
4. Зеркало пушится в GitHub.

Коммиты идут в хронологическом порядке. `sort -u` при сортировке использовать
нельзя — он схлопывает коммиты с совпадающими до секунды датами.

## Чтобы коммиты появились в графике

- Почта из `--email` должна быть **подтверждена** в GitHub (Settings → Emails).
- Коммиты должны лежать в **дефолтной ветке** зеркала.
- Репозиторий не должен быть форком.
- Для приватного зеркала — включить Settings → Public profile →
  **Include private contributions on my profile**.

## Автозапуск (macOS, launchd)

`~/Library/LaunchAgents/com.user.activity-mirror.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>com.user.activity-mirror</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/local/bin/gitmirror</string>
    <string>sync</string>
  </array>
  <key>StartCalendarInterval</key>
  <dict><key>Hour</key><integer>21</integer><key>Minute</key><integer>0</integer></dict>
  <key>StandardOutPath</key><string>/tmp/activity-mirror.log</string>
  <key>StandardErrorPath</key><string>/tmp/activity-mirror.log</string>
  <key>EnvironmentVariables</key>
  <dict>
    <key>GITMIRROR_DIR</key><string>/Users/ВАШ_ЮЗЕР/activity-mirror</string>
    <key>PATH</key><string>/usr/bin:/bin:/usr/local/bin:/opt/homebrew/bin</string>
    <key>GIT_TERMINAL_PROMPT</key><string>0</string>
  </dict>
</dict>
</plist>
```

```sh
launchctl load ~/Library/LaunchAgents/com.user.activity-mirror.plist
```

Для автопуша без запросов пароля используйте SSH-remote: при HTTPS токен
в keychain протухнет, и задача начнёт молча падать.

Cron-аналог для Linux:

```
0 21 * * * GITMIRROR_DIR=$HOME/activity-mirror /usr/local/bin/gitmirror sync >> /tmp/activity-mirror.log 2>&1
```

## Ограничения

- Merge request / pull request как сущности не переносятся — в git от них
  остаётся только merge-коммит, он и попадает в зеркало. Ревью чужого кода
  отразить нечем.
- Скрипт читает **локальные клоны** и делает в них `fetch`, так что источники
  должны быть склонированы на машину.
- Активность без содержимого: график заполнится, но как портфолио зеркало
  не работает. Держите его приватным.

## Лицензия

[MIT](LICENSE) — используйте, изменяйте и распространяйте свободно,
сохраняя копирайт.
