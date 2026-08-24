# add — зарегистрировать репозиторий-источник.

cmd_add() {
  local src="" label=""
  while [ $# -gt 0 ]; do
    case "$1" in
      -*) die "неизвестный флаг: $1" ;;
      *) if [ -z "$src" ]; then src="$1"; else label="$1"; fi; shift ;;
    esac
  done
  resolve_mirror
  [ -n "$src" ] || die "не указан путь к репозиторию"
  src="$(expand_tilde "$src")"
  [ -d "$src/.git" ] || die "$src не git-репозиторий"
  src="$(cd "$src" && pwd)"
  [ -n "$label" ] || label="$(label_from_remote "$src")"
  cfg_add_source "$src" "$label" || { echo "уже добавлен: $label"; return; }
  printf 'источник добавлен: %s\n  путь: %s\n  твоих коммитов: %s\n' \
    "$label" "$src" "$(count_commits "$src" "$(cfg_get emails)")"
}
