# status, sources — отчёты по состоянию зеркала.

cmd_status() {
  resolve_mirror
  local commits remote ahead state
  commits="$(git -C "$MIRROR" rev-list --count HEAD 2>/dev/null || echo 0)"
  remote="$(git -C "$MIRROR" remote get-url origin 2>/dev/null || true)"

  if [ -z "$remote" ]; then
    state="${S_DIM}remote не задан${S_RST}"
  elif ahead="$(git -C "$MIRROR" rev-list --count '@{u}..HEAD' 2>/dev/null)"; then
    if [ "$ahead" = 0 ]; then state="${S_GRN}✓ всё запушено${S_RST}"
    else state="${S_YEL}! не запушено: $ahead — запусти $PROG sync${S_RST}"; fi
  else
    state="${S_DIM}upstream не настроен${S_RST}"
  fi

  heading "$PROG status"
  kv 'зеркало'  "$(tildify "$MIRROR")"
  kv 'автор'    "$(cfg_get name) <$(cfg_get emails)>"
  kv 'коммитов' "$(num "$commits")"
  kv 'remote'   "${remote:-—}"
  kv 'статус'   "$state"

  heading 'по источникам'
  git -C "$MIRROR" log --format='%s' 2>/dev/null |
    sed -n 's/.*(\(.*\)@[0-9a-f]\{7,\})$/\1/p' | sort | uniq -c | sort -rn | bar_table 40

  heading 'по годам'
  git -C "$MIRROR" log --format='%ad' --date=format:%Y 2>/dev/null | sort | uniq -c | bar_table 6
}

# bar_table <ширина подписи> — строки «N подпись» из uniq -c → подпись, число, полоска
bar_table() {
  local data max=0 n label
  data="$(cat)"
  [ -n "$data" ] || { printf '  %s—%s\n' "$S_DIM" "$S_RST"; return 0; }
  while read -r n label; do
    if [ "$n" -gt "$max" ]; then max="$n"; fi
  done <<EOF
$data
EOF
  while read -r n label; do
    printf '  %s %7s  %s\n' "$(pad "$label" "$1")" "$(num "$n")" "$(bar "$n" "$max" 24)"
  done <<EOF
$data
EOF
}

cmd_sources() {
  resolve_mirror
  local p l
  cfg_sources | while IFS='|' read -r p l; do
    if [ -d "$p/.git" ]; then printf '%s✓%s ' "$S_GRN" "$S_RST"
    else printf '%s✗%s ' "$S_RED" "$S_RST"; fi
    printf '%s%s%s%s\n' "$(pad "$l" 44)" "$S_DIM" "$(tildify "$p")" "$S_RST"
  done
}
