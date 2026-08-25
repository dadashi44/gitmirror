# sync — перенести недостающие коммиты в зеркало.

cmd_sync() {
  local dry=0 fetch=1
  while [ $# -gt 0 ]; do
    case "$1" in
      --dry-run)  dry=1; shift ;;
      --no-fetch) fetch=0; shift ;;
      -*) die "неизвестный флаг: $1" ;;
      *) die "лишний аргумент: $1" ;;
    esac
  done
  resolve_mirror

  local name emails re
  name="$(cfg_get name)"; emails="$(cfg_get emails)"
  [ -n "$emails" ] || die "в конфиге нет emails"
  re="$(email_regex "$emails")"

  mktmp
  : > "$TMP/pending"
  mirror_seen_keys > "$TMP/seen"
  cfg_sources > "$TMP/sources"
  [ -s "$TMP/sources" ] || die "нет источников — добавь через $PROG add"

  while IFS='|' read -r src label; do
    [ -d "$src/.git" ] || { warn "пропуск: $src не найден"; continue; }
    if [ "$fetch" = 1 ]; then
      git -C "$src" fetch --all --quiet --prune 2>/dev/null || warn "fetch не удался для $label"
    fi
    git -C "$src" log --all --pretty="%H${TAB}%at${TAB}%ai${TAB}%ae" | grep -iE "$re" |
    while IFS="$TAB" read -r sha ts iso _; do
      key="$label@$(printf '%s' "$sha" | cut -c1-7)"
      grep -qxF "$key" "$TMP/seen" && continue
      printf '%s\t%s\t%s\t%s\n' "$ts" "${iso##* }" "${iso% *}" "$key"
    done >> "$TMP/pending"
  done < "$TMP/sources"

  if [ ! -s "$TMP/pending" ]; then echo 'новых коммитов нет'; return 0; fi
  # -u здесь нельзя: он дедуплицирует по ключу сортировки и схлопнет коммиты,
  # совпадающие по дате до секунды
  sort -t"$TAB" -k1,1n "$TMP/pending" > "$TMP/sorted"

  if [ "$dry" = 1 ]; then sync_preview; return 0; fi

  local added=0
  while IFS="$TAB" read -r ts tz human key; do
    GIT_AUTHOR_DATE="$ts $tz" GIT_COMMITTER_DATE="$ts $tz" \
    git -C "$MIRROR" -c user.name="$name" -c user.email="${emails%%,*}" \
      commit -q --allow-empty -m "activity $human ($key)"
    added=$((added+1))
  done < "$TMP/sorted"
  printf 'добавлено коммитов: %s\n' "$added"
}

sync_preview() {
  printf 'будет добавлено: %s\n' "$(wc -l < "$TMP/sorted" | tr -d ' ')"
  cut -f3,4 "$TMP/sorted" | head -20 | sed 's/^/  /'
  [ "$(wc -l < "$TMP/sorted")" -gt 20 ] && echo '  ...'
  return 0
}
