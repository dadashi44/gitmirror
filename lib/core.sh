# core.sh — базовые примитивы: вывод, ошибки, временный каталог.

VERSION=1.0.0
PROG="${PROG:-gitmirror}"
CONFIG_NAME=.gitmirror
TAB="$(printf '\t')"
TMP=""

# цвета E_* и step_break — из style.sh, он грузится следом
die()  { step_break; printf '%s✗ ошибка:%s %s\n' "${E_RED:-}" "${E_RST:-}" "$1" >&2; exit 1; }
warn() { step_break; printf '%s! внимание:%s %s\n' "${E_YEL:-}" "${E_RST:-}" "$1" >&2; }

cleanup() { [ -n "${TMP:-}" ] && rm -rf "$TMP"; return 0; }
trap cleanup EXIT

mktmp() { TMP="$(mktemp -d)"; }

expand_tilde() { case "$1" in "~"|"~/"*) printf '%s' "$HOME${1#\~}" ;; *) printf '%s' "$1" ;; esac; }
