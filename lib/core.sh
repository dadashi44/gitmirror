# core.sh — базовые примитивы: вывод, ошибки, временный каталог.

VERSION=0.1.0
PROG="${PROG:-gitmirror}"
CONFIG_NAME=.gitmirror
TAB="$(printf '\t')"
TMP=""

die()  { printf 'ошибка: %s\n' "$1" >&2; exit 1; }

warn() { printf 'внимание: %s\n' "$1" >&2; }
