# sync — перенести недостающие коммиты в зеркало.

cmd_sync() {
  resolve_mirror

  local name emails re
  name="$(cfg_get name)"; emails="$(cfg_get emails)"
  [ -n "$emails" ] || die "в конфиге нет emails"
  re="$(email_regex "$emails")"

  mktmp
  cfg_sources > "$TMP/sources"
  [ -s "$TMP/sources" ] || die "нет источников — добавь через $PROG add"

  local added=0
  while IFS='|' read -r src label; do
    [ -d "$src/.git" ] || { warn "пропуск: $src не найден"; continue; }
    git -C "$src" log --all --pretty="%H${TAB}%at${TAB}%ai${TAB}%ae" | grep -iE "$re" |
    while IFS="$TAB" read -r sha ts iso _; do
      key="$label@$(printf '%s' "$sha" | cut -c1-7)"
      GIT_AUTHOR_DATE="$ts ${iso##* }" GIT_COMMITTER_DATE="$ts ${iso##* }" \
      git -C "$MIRROR" -c user.name="$name" -c user.email="${emails%%,*}" \
        commit -q --allow-empty -m "activity ${iso% *} ($key)"
    done
  done < "$TMP/sources"
  echo 'готово'
}
