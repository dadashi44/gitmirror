# sync — перенести недостающие коммиты в зеркало и запушить.

cmd_sync() {
  local dry=0 push=1 fetch=1 since_ts=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --dry-run)  dry=1; shift ;;
      --no-push)  push=0; shift ;;
      --no-fetch) fetch=0; shift ;;
      --since)
        since_ts="$(date -j -f '%Y-%m-%d' "$2" +%s 2>/dev/null || date -d "$2" +%s 2>/dev/null || true)"
        [ -n "$since_ts" ] || die "не разобрал дату: $2"
        shift 2 ;;
      -*) die "неизвестный флаг: $1" ;;
      *) die "лишний аргумент: $1" ;;
    esac
  done
  [ -f "${MIRROR:-}/$CONFIG_NAME" ] || resolve_mirror

  local name emails re
  name="$(cfg_get name)"; emails="$(cfg_get emails)"
  [ -n "$emails" ] || die "в конфиге нет emails"
  re="$(email_regex "$emails")"

  mktmp
  : > "$TMP/pending"
  mirror_seen_keys > "$TMP/seen"
  cfg_sources > "$TMP/sources"
  [ -s "$TMP/sources" ] || die "нет источников — добавь через $PROG add"

  local total i=0 ok=0 failed="" src label
  total="$(wc -l < "$TMP/sources" | tr -d ' ')"

  # 1. fetch
  if [ "$fetch" = 1 ]; then
    while IFS='|' read -r src label; do
      i=$((i+1))
      step_run 'fetch источников' "$i/$total · $label"
      [ -d "$src/.git" ] || { failed="$failed $label"; continue; }
      if git -C "$src" fetch --all --quiet --prune 2>/dev/null; then ok=$((ok+1))
      else failed="$failed $label"; fi
    done < "$TMP/sources"
    if [ -z "$failed" ]; then step_ok 'fetch источников' "$ok/$total"
    else
      step_warn 'fetch источников' "$ok/$total"
      for label in $failed; do warn "fetch не удался: $label"; done
    fi
  else
    step_ok 'fetch источников' 'пропущен (--no-fetch)'
  fi

  # 2. поиск новых коммитов
  i=0
  while IFS='|' read -r src label; do
    i=$((i+1))
    step_run 'поиск новых коммитов' "$i/$total · $label"
    [ -d "$src/.git" ] || { warn "пропуск: $src не найден"; continue; }
    source_pending "$src" "$label" "$re" "$TMP/seen" "$since_ts" >> "$TMP/pending"
  done < "$TMP/sources"

  if [ ! -s "$TMP/pending" ]; then
    step_ok 'новых коммитов' 'нет — зеркало актуально'
    return 0
  fi
  # -u здесь нельзя: он дедуплицирует по ключу сортировки и схлопнет коммиты,
  # совпадающие по дате до секунды
  sort -t"$TAB" -k1,1n "$TMP/pending" > "$TMP/sorted"
  local found; found="$(wc -l < "$TMP/sorted" | tr -d ' ')"
  step_ok 'новых коммитов' "$found"

  if [ "$dry" = 1 ]; then sync_preview "$found"; return 0; fi

  # 3. пустые коммиты в зеркало
  local added=0 ts tz human key
  while IFS="$TAB" read -r ts tz human key; do
    mirror_commit "$ts" "$tz" "$human" "$key" "$name" "${emails%%,*}"
    added=$((added+1))
    step_run 'добавление в зеркало' "$added/$found"
  done < "$TMP/sorted"
  step_ok 'добавлено коммитов' "$added"

  # 4. пуш
  if [ "$push" = 1 ]; then sync_push
  else step_warn 'пуш' 'пропущен (--no-push)'; fi
  return 0
}

sync_preview() {  # <сколько найдено>
  local human key
  printf '\n'
  head -20 "$TMP/sorted" | cut -f3,4 | while IFS="$TAB" read -r human key; do
    printf '  %s%s%s  %s\n' "$S_DIM" "$human" "$S_RST" "$key"
  done
  [ "$1" -gt 20 ] && printf '  %s… и ещё %s%s\n' "$S_DIM" "$(( $1 - 20 ))" "$S_RST"
  printf '\n%s--dry-run: в зеркало ничего не записано%s\n' "$S_DIM" "$S_RST"
  return 0
}

sync_push() {
  local branch title
  if ! git -C "$MIRROR" remote get-url origin >/dev/null 2>&1; then
    step_warn 'пуш' 'remote не задан'
    return 0
  fi
  branch="$(git -C "$MIRROR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo HEAD)"
  title="пуш в origin/$branch"

  local tries="${GITMIRROR_PUSH_RETRIES:-4}" delay=5 n=1 err s
  while :; do
    step_run "$title" "попытка $n/$tries"
    if err=$(git -C "$MIRROR" push --quiet origin HEAD 2>&1); then
      step_ok "$title" 'запушено'; return 0
    fi
    if ! push_is_server_error "$err"; then
      if push_is_auth_error "$err"; then step_fail "$title" 'нет доступа — проверь токен и права'
      else step_fail "$title" 'отклонено'; fi
      quote_err "$err"
      return 0
    fi
    if [ "$n" -ge "$tries" ]; then
      step_fail "$title" "сервер отвечает 5xx, $tries попыток"
      warn 'похоже на сбой хостинга: коммиты сохранены локально, запусти sync позже'
      return 0
    fi
    step_retry "$title" "сервер ответил 5xx · попытка $n/$tries"
    [ "$n" = 1 ] && quote_err "$err"
    if [ "$TTY" = 1 ]; then
      s="$delay"
      while [ "$s" -gt 0 ]; do step_run "$title" "повтор через ${s}с"; sleep 1; s=$((s - 1)); done
    else
      sleep "$delay"
    fi
    n=$((n + 1)); delay=$((delay * 2))
  done
}

# 5xx от сервера — временная ошибка, имеет смысл повторить.
push_is_server_error() {
  printf '%s' "$1" | grep -qiE 'Internal Server Error|Bad Gateway|Service Unavailable|Gateway Time-?out|returned error: 5[0-9][0-9]|HTTP 5[0-9][0-9]'
}

push_is_auth_error() {
  printf '%s' "$1" | grep -qiE 'Authentication failed|Permission denied|returned error: 40[13]|could not read Username|Repository not found'
}
