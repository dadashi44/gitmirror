# setup — интерактивная настройка с нуля.

cmd_setup() {
  printf '%s%s%s %sнастройка%s\n\n' "$S_B" "$PROG" "$S_RST" "$S_DIM" "$S_RST"
  local dir name emails p remote
  heading '1. Зеркало'
  ask dir    'Каталог для зеркала' "$HOME/activity-mirror"
  ask name   'Имя автора для коммитов' "$(git config --global user.name || true)"
  ask emails 'Почта, которой ты коммитишь (несколько — через запятую)' "$(git config --global user.email || true)"
  cmd_init "$dir" --name "$name" --email "$emails"

  heading '2. Источники'
  printf '%sРепозитории, из которых брать активность. Пустая строка завершает ввод.%s\n' "$S_DIM" "$S_RST"
  while :; do
    ask p 'Путь к репозиторию' ''
    [ -z "$p" ] && break
    p="$(expand_tilde "$p")"
    if [ -d "$p/.git" ]; then cmd_add "$p"; else step_warn 'пропуск' "$p — не git-репозиторий"; fi
  done

  heading '3. GitHub'
  ask remote 'Remote (git@github.com:user/repo.git, пусто — пропустить)' ''
  if [ -n "$remote" ]; then
    git -C "$MIRROR" remote add origin "$remote" 2>/dev/null ||
      git -C "$MIRROR" remote set-url origin "$remote"
    step_ok 'remote задан' "$remote"
  fi

  heading '4. Синхронизация'
  confirm 'Синхронизировать сейчас?' && cmd_sync

  heading 'Готово'
  printf '  Дальше: %sGITMIRROR_DIR=%s %s sync%s\n' "$S_CYN" "$(tildify "$MIRROR")" "$PROG" "$S_RST"
  printf '  %sНе забудь включить «Include private contributions on my profile» в настройках GitHub.%s\n' "$S_DIM" "$S_RST"
}
