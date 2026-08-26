# ui.sh — общение с пользователем: подсказки, вопросы, подтверждения.

ask() {
  local __var="$1" __q="$2" __def="${3:-}" __ans="" __prompt
  [ -t 0 ] || die "нужен интерактивный терминал (или передай значение флагом)"
  if [ -n "$__def" ]; then __prompt="$__q [$__def]: "; else __prompt="$__q: "; fi
  read -r -e -p "$__prompt" __ans </dev/tty || true
  [ -z "$__ans" ] && __ans="$__def"
  eval "$__var=\$__ans"
}

confirm() {
  local __ans=""
  [ -t 0 ] || return 0
  read -r -p "$1 [Y/n]: " __ans </dev/tty || true
  case "$__ans" in [nN]*) return 1 ;; *) return 0 ;; esac
}
