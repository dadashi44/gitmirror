# core.sh — базовые примитивы: вывод, ошибки, временный каталог.

VERSION=1.0.0
PROG="${PROG:-gitmirror}"
CONFIG_NAME=.gitmirror
TAB="$(printf '\t')"
TMP=""

die()  { printf 'ошибка: %s\n' "$1" >&2; exit 1; }
warn() { printf 'внимание: %s\n' "$1" >&2; }

cleanup() { [ -n "${TMP:-}" ] && rm -rf "$TMP"; return 0; }
trap cleanup EXIT

mktmp() { TMP="$(mktemp -d)"; }

expand_tilde() { case "$1" in "~"|"~/"*) printf '%s' "$HOME${1#\~}" ;; *) printf '%s' "$1" ;; esac; }
