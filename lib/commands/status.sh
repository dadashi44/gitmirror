# status, sources — отчёты по состоянию зеркала.

cmd_status() {
  resolve_mirror
  printf 'зеркало:   %s\n' "$MIRROR"
  printf 'автор:     %s <%s>\n' "$(cfg_get name)" "$(cfg_get emails)"
  printf 'коммитов:  %s\n' "$(git -C "$MIRROR" rev-list --count HEAD 2>/dev/null || echo 0)"
  printf 'remote:    %s\n\n' "$(git -C "$MIRROR" remote get-url origin 2>/dev/null || echo '— не задан —')"
  echo 'по источникам:'
  git -C "$MIRROR" log --format='%s' 2>/dev/null |
    sed -n 's/.*(\(.*\)@[0-9a-f]\{7,\})$/\1/p' | sort | uniq -c | sed 's/^/  /'
  echo
  echo 'по годам:'
  git -C "$MIRROR" log --format='%ad' --date=format:%Y 2>/dev/null | sort | uniq -c | sed 's/^/  /'
}

cmd_sources() {
  resolve_mirror
  cfg_sources | while IFS='|' read -r p l; do printf '%-46s %s\n' "$l" "$p"; done
}
