# init — создать репозиторий-зеркало и конфиг.

cmd_init() {
  local dir="" name="" emails=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --name)  name="$2"; shift 2 ;;
      --email) emails="$2"; shift 2 ;;
      -*) die "неизвестный флаг: $1" ;;
      *) dir="$1"; shift ;;
    esac
  done
  [ -n "$dir" ] || die "не указан каталог зеркала"
  dir="$(expand_tilde "$dir")"
  [ -n "$name" ]   || die "имя не задано"
  [ -n "$emails" ] || die "почта не задана"
  [ -e "$dir" ] && [ -n "$(ls -A "$dir" 2>/dev/null)" ] && die "$dir существует и не пуст"

  mkdir -p "$dir"; dir="$(cd "$dir" && pwd)"
  git -C "$dir" init -q -b main
  printf 'name=%s\nemails=%s\n' "$name" "$emails" > "$dir/$CONFIG_NAME"
  printf '%s\nsync.log\n' "$CONFIG_NAME" > "$dir/.gitignore"
  cat > "$dir/README.md" <<'README'
# Activity mirror

Зеркало активности из приватных репозиториев, размещённых вне GitHub.
Содержит только пустые коммиты с датами авторства — без исходного кода
и без оригинальных сообщений коммитов.

Синхронизация: `gitmirror sync`
README
  git -C "$dir" add .gitignore README.md
  git -C "$dir" -c user.name="$name" -c user.email="${emails%%,*}" \
    commit -q -m "Инициализация зеркала активности"
  MIRROR="$dir"
  printf 'зеркало создано: %s\n' "$dir"
}
