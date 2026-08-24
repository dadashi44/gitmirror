# config.sh — поиск каталога зеркала и работа с .gitmirror.

MIRROR="${MIRROR:-}"

resolve_mirror() {
  if [ -n "$MIRROR" ]; then :
  elif [ -n "${GITMIRROR_DIR:-}" ]; then MIRROR="$GITMIRROR_DIR"
  elif [ -f "./$CONFIG_NAME" ]; then MIRROR="$(pwd)"
  else die "зеркало не найдено: укажи --mirror, задай \$GITMIRROR_DIR или запусти $PROG setup"; fi
  MIRROR="$(expand_tilde "$MIRROR")"
  [ -f "$MIRROR/$CONFIG_NAME" ] || die "в $MIRROR нет $CONFIG_NAME — сначала $PROG init"
}

cfg_get()     { sed -n "s/^$1=//p" "$MIRROR/$CONFIG_NAME" | head -1; }

cfg_sources() { sed -n 's/^source=//p' "$MIRROR/$CONFIG_NAME"; }

cfg_add_source() {  # <путь> <метка>
  grep -qxF "source=$1|$2" "$MIRROR/$CONFIG_NAME" && return 1
  printf 'source=%s|%s\n' "$1" "$2" >> "$MIRROR/$CONFIG_NAME"
}
