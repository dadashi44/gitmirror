# style.sh — оформление вывода: цвета, значки, строки шагов, полоски.
# Цвета и перерисовка строк — только в интерактивном терминале.
# В пайпе, логе launchd/cron или с NO_COLOR вывод остаётся простым текстом.

_style_on() { [ -t "$1" ] && [ -z "${NO_COLOR:-}" ] && [ "${TERM:-dumb}" != dumb ]; }

if _style_on 1; then
  TTY=1
  S_B=$'\033[1m' S_DIM=$'\033[2m' S_GRN=$'\033[32m' S_YEL=$'\033[33m'
  S_RED=$'\033[31m' S_CYN=$'\033[36m' S_RST=$'\033[0m' S_CLR=$'\r\033[K'
else
  TTY=0 S_B='' S_DIM='' S_GRN='' S_YEL='' S_RED='' S_CYN='' S_RST='' S_CLR=''
fi
if _style_on 2; then
  E_YEL=$'\033[33m' E_RED=$'\033[31m' E_DIM=$'\033[2m' E_RST=$'\033[0m'
else
  E_YEL='' E_RED='' E_DIM='' E_RST=''
fi

STEP_W=26   # ширина колонки с названием шага
STEP_OPEN=0 # на экране висит незавершённая строка шага

# pad <текст> <ширина> — дополнить пробелами по числу символов, не байт
pad() {
  local n=$(( $2 - ${#1} )); [ "$n" -lt 1 ] && n=1
  printf '%s%*s' "$1" "$n" ''
}

# 4356 → 4 356
num() {
  local s="$1" out=""
  while [ ${#s} -gt 3 ]; do out=" ${s: -3}$out"; s="${s:0:${#s}-3}"; done
  printf '%s%s' "$s" "$out"
}

# закрыть висящую строку шага перед любым другим выводом
step_break() { [ "$STEP_OPEN" = 1 ] && { printf '%s' "$S_CLR"; STEP_OPEN=0; }; return 0; }

_step_line() {  # <значок> <цвет> <текст> [детали]
  step_break
  printf '%s%s%s %s%s%s\n' "$2" "$1" "$S_RST" "$(pad "$3" "$STEP_W")" "$S_DIM" "${4:-}$S_RST"
}

# step_run <текст> [детали] — шаг в процессе; в терминале перерисовывается
step_run() {
  [ "$TTY" = 1 ] || return 0
  printf '%s%s… %s%s%s' "$S_CLR" "$S_CYN" "$S_RST" "$(pad "$1" "$STEP_W")" "$S_DIM${2:-}$S_RST"
  STEP_OPEN=1
}
step_ok()    { _step_line '✓' "$S_GRN" "$@"; }
step_warn()  { _step_line '!' "$S_YEL" "$@"; }
step_fail()  { _step_line '✗' "$S_RED" "$@"; }
step_retry() { _step_line '⟳' "$S_YEL" "$@"; }

# вывод внешней команды — приглушённо и с отступом, в stderr
quote_err() { step_break; printf '%s\n' "$1" | sed '/^$/d' | sed "s/^/  ${E_DIM}│${E_RST} /" >&2; }

# заголовок раздела и горизонтальная линия
heading() { step_break; printf '\n%s%s%s\n' "$S_B" "$1" "$S_RST"; }
rule()    { printf '%s%s%s\n' "$S_DIM" '────────────────────────────────────────' "$S_RST"; }

# пара «ключ значение» для отчётов
kv() { printf '  %s%s%s%s\n' "$S_DIM" "$(pad "$1" 10)" "$S_RST" "$2"; }

# bar <значение> <максимум> [ширина] — полоска из █
bar() {
  local w="${3:-20}" n=0 s=""
  [ "$2" -gt 0 ] && n=$(( ($1 * w + $2 - 1) / $2 ))
  while [ "$n" -gt 0 ]; do s="${s}█"; n=$((n - 1)); done
  printf '%s%s%s' "$S_GRN" "$s" "$S_RST"
}

# путь с ~ вместо $HOME
tildify() { case "$1" in "$HOME"/*) printf '~%s' "${1#"$HOME"}" ;; *) printf '%s' "$1" ;; esac; }
