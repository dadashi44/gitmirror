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

mirror_seen_keys() {
  git -C "$MIRROR" log --format='%s' 2>/dev/null | sed -n 's/.*(\(.*\))$/\1/p' | sort -u
}
