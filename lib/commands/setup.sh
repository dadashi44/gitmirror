# setup — интерактивная настройка с нуля.

cmd_setup() {
  echo "=== $PROG: настройка ==="
  echo
  local dir name emails p remote
  ask dir    'Каталог для зеркала' "$HOME/activity-mirror"
  ask name   'Имя автора для коммитов' "$(git config --global user.name || true)"
  ask emails 'Почта, которой ты коммитишь (несколько — через запятую)' "$(git config --global user.email || true)"
  echo
  cmd_init "$dir" --name "$name" --email "$emails"
  echo
  echo 'Теперь источники — репозитории, из которых брать активность.'
  echo 'Пустая строка завершает ввод.'
  while :; do
    ask p '  Путь к репозиторию' ''
    [ -z "$p" ] && break
    p="$(expand_tilde "$p")"
    if [ -d "$p/.git" ]; then cmd_add "$p"; else echo "  пропуск: $p не git-репозиторий"; fi
  done
  echo
  ask remote 'GitHub remote (git@github.com:user/repo.git, пусто — пропустить)' ''
  if [ -n "$remote" ]; then
    git -C "$MIRROR" remote add origin "$remote" 2>/dev/null ||
      git -C "$MIRROR" remote set-url origin "$remote"
    echo "remote задан: $remote"
  fi
  echo
  confirm 'Синхронизировать сейчас?' && cmd_sync
  echo
  echo "Готово. Дальше: GITMIRROR_DIR=$MIRROR $PROG sync"
  echo "Не забудь включить Include private contributions on my profile в настройках GitHub."
}
