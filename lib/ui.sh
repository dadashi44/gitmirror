# ui.sh — общение с пользователем: подсказки, вопросы, подтверждения.

usage() {
  cat <<USAGE
${S_B}$PROG${S_RST} ${S_DIM}$VERSION${S_RST} — синхронизация активности приватных репозиториев в GitHub

${S_B}Команды${S_RST}
  ${S_CYN}setup${S_RST}            интерактивная настройка с нуля: зеркало, источники, remote
  ${S_CYN}init${S_RST} [каталог]   создать зеркало (спросит имя и почты, если не переданы)
  ${S_CYN}add${S_RST} [путь]       добавить источник (спросит путь, если не передан)
  ${S_CYN}sync${S_RST}             добавить пустые коммиты для новых исходных коммитов и запушить
  ${S_CYN}status${S_RST}           статистика зеркала
  ${S_CYN}sources${S_RST}          список источников

${S_B}Флаги${S_RST}
  sync    --dry-run  --no-push  --no-fetch  --since ГГГГ-ММ-ДД
  init    --name <имя>  --email <почта>[,<почта>...]
  общий   --mirror <каталог>

${S_DIM}Каталог зеркала ищется так: --mirror, затем \$GITMIRROR_DIR, затем текущий
каталог, если в нём лежит $CONFIG_NAME. Цвета отключаются в пайпе и с NO_COLOR.${S_RST}

${S_B}Быстрый старт${S_RST}
  $PROG setup
USAGE
}

# ask <переменная> <вопрос> [дефолт] — читает с терминала, не из пайпа
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
