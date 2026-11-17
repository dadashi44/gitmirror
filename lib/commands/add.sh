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
  [ -n "$src" ] || ask src 'Путь к репозиторию-источнику'
  src="$(expand_tilde "$src")"
  [ -d "$src/.git" ] || die "$src не git-репозиторий"
  src="$(cd "$src" && pwd)"
  [ -n "$label" ] || label="$(label_from_remote "$src")"
  cfg_add_source "$src" "$label" || { step_warn 'уже добавлен' "$label"; return 0; }
  step_run 'источник добавлен' 'считаю коммиты…'
  local n; n="$(count_commits "$src" "$(cfg_get emails)")"
  step_ok 'источник добавлен' "$label"
  kv 'путь'     "$(tildify "$src")"
  kv 'коммитов' "$(num "${n:-0}")"
}
