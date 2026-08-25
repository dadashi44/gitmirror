# git.sh — всё, что знает про устройство git-репозиториев.

# регулярка «таб + любая из почт + конец строки»
email_regex() {
  printf '%s' "$1" | tr ',' '\n' | sed 's/^ *//; s/ *$//; /^$/d; s/[.[\*^$]/\\&/g' |
    paste -sd'|' - | sed "s/^/$TAB(/; s/\$/)\$/"
}

label_from_remote() {
  local url; url="$(git -C "$1" remote get-url origin 2>/dev/null || true)"
  [ -z "$url" ] && { basename "$1"; return; }
  printf '%s' "$url" | sed -e 's#^[a-z+]*://##' -e 's#^[^@/]*@##' -e 's#:#/#' -e 's#\.git$##'
}

count_commits() {  # <путь> <почты>
  git -C "$1" log --all --pretty="%H${TAB}%ae" 2>/dev/null | grep -icE "$(email_regex "$2")" || true
}

# ключи уже отражённых коммитов: метка@короткий-sha из сообщений зеркала
mirror_seen_keys() {
  git -C "$MIRROR" log --format='%s' 2>/dev/null | sed -n 's/.*(\(.*\))$/\1/p' | sort -u
}

# коммиты источника, ещё не попавшие в зеркало → ts, tz, дата, ключ
source_pending() {  # <путь> <метка> <регулярка> <файл-seen>
  local src="$1" label="$2" re="$3" seen="$4"
  git -C "$src" log --all --pretty="%H${TAB}%at${TAB}%ai${TAB}%ae" | grep -iE "$re" |
  while IFS="$TAB" read -r sha ts iso _; do
    key="$label@$(printf '%s' "$sha" | cut -c1-7)"
    grep -qxF "$key" "$seen" && continue
    printf '%s\t%s\t%s\t%s\n' "$ts" "${iso##* }" "${iso% *}" "$key"
  done
}

# пустой коммит с датой оригинала
mirror_commit() {  # <ts> <tz> <дата> <ключ> <имя> <почта>
  GIT_AUTHOR_DATE="$1 $2" GIT_COMMITTER_DATE="$1 $2" \
  git -C "$MIRROR" -c user.name="$5" -c user.email="$6" \
    commit -q --allow-empty -m "activity $3 ($4)"
}
