#!/usr/bin/env bash
# e2e-тесты gitmirror: настоящие git-репозитории во временном каталоге,
# локальный bare-репозиторий вместо GitHub, без сети.
# Запуск: bash test/e2e.sh  (на macOS стоит гонять и системным /bin/bash 3.2)
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REAL_GIT="$(command -v git)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# изоляция от пользовательского git-конфига (подпись коммитов, хуки и т.п.)
export HOME="$WORK/home" GIT_CONFIG_NOSYSTEM=1 NO_COLOR=
mkdir -p "$HOME"
unset GITMIRROR_DIR MIRROR

PASS=0 FAIL=0 CUR=""

# --- обёртка git: подменяет ответы на push, остальное — настоящий git ------
mkdir -p "$WORK/bin"
cat > "$WORK/bin/git" <<EOF
#!/usr/bin/env bash
for a in "\$@"; do
  if [ "\$a" = push ] && [ -n "\${FAKE_PUSH:-}" ]; then
    n=\$(( \$(cat "\$FAKE_PUSH_COUNT" 2>/dev/null || echo 0) + 1 ))
    echo "\$n" > "\$FAKE_PUSH_COUNT"
    if [ "\$n" -le "\${FAKE_PUSH_FAILS:-0}" ]; then
      case "\$FAKE_PUSH" in
        5xx)  echo 'remote: Internal Server Error' >&2
              echo ' ! [remote rejected] HEAD -> main (Internal Server Error)' >&2 ;;
        auth) echo "fatal: Authentication failed for 'https://example.invalid/repo.git/'" >&2 ;;
      esac
      exit 1
    fi
    break
  fi
done
exec "$REAL_GIT" "\$@"
EOF
chmod +x "$WORK/bin/git"
export PATH="$WORK/bin:$PATH"

# --- утилиты ---------------------------------------------------------------
gm() { "$BASH" "$ROOT/bin/gitmirror" --mirror "$T/mirror" "$@" 2>&1; }

fail() { FAIL=$((FAIL+1)); printf '  ✗ %s: %s\n' "$CUR" "$1"; }
ok()   { :; }
assert_eq()       { [ "$1" = "$2" ] || fail "${3:-} ожидалось «$2», получено «$1»"; }
assert_contains() { case "$1" in *"$2"*) ;; *) fail "${3:-} нет «$2» в выводе:
$1" ;; esac; }
assert_not_contains() { case "$1" in *"$2"*) fail "${3:-} лишнее «$2» в выводе" ;; esac; }

# коммит в источник: <репо> <почта> <unix-время> <сообщение>
src_commit() {
  GIT_AUTHOR_DATE="$3 +0300" GIT_COMMITTER_DATE="$3 +0300" \
  "$REAL_GIT" -C "$1" -c user.name=dev -c user.email="$2" -c commit.gpgsign=false \
    commit -q --allow-empty -m "$4"
}

mirror_count() { "$REAL_GIT" -C "$T/mirror" rev-list --count HEAD; }

# свежее окружение: источник с 3 своими коммитами (2 из них в одну секунду,
# один в 2023 году, один с другой почтой в другом регистре) и 1 чужим
setup_env() {
  T="$WORK/$1"; mkdir -p "$T"
  "$REAL_GIT" init -q -b main "$T/src"
  src_commit "$T/src" me@example.com     1685577600 'secret one'    # 2023-06-01
  src_commit "$T/src" me@example.com     1740787200 'secret two'    # 2025-03-01
  src_commit "$T/src" Me.Alt@Example.com 1740787200 'secret three'  # та же секунда
  src_commit "$T/src" other@example.com  1740790000 'foreign'
  "$BASH" "$ROOT/bin/gitmirror" init "$T/mirror" --name me \
    --email 'me@example.com,me.alt@example.com' >/dev/null 2>&1 || fail 'init упал'
  gm add "$T/src" src >/dev/null || fail 'add упал'
  "$REAL_GIT" init -q --bare -b main "$T/remote.git"
  "$REAL_GIT" -C "$T/mirror" remote add origin "$T/remote.git"
  unset FAKE_PUSH FAKE_PUSH_FAILS
  export FAKE_PUSH_COUNT="$T/push-count" GITMIRROR_PUSH_DELAY=0
}

run() { CUR="$1"; local before=$FAIL; "$1"; [ "$FAIL" = "$before" ] && PASS=$((PASS+1)) && printf '  ✓ %s\n' "$1"; }

# --- тесты -----------------------------------------------------------------

test_sync_adds_only_my_commits() {
  setup_env t1
  local out; out="$(gm sync --no-fetch --no-push)"
  assert_contains "$out" 'добавлено коммитов'
  assert_eq "$(mirror_count)" 4 'init + 3 своих:'
}

test_second_sync_is_noop() {
  setup_env t2
  gm sync --no-fetch --no-push >/dev/null
  local out; out="$(gm sync --no-fetch --no-push)"
  assert_contains "$out" 'зеркало актуально'
  assert_eq "$(mirror_count)" 4 'повтор не должен дублировать:'
}

test_same_second_commits_not_collapsed() {
  setup_env t3
  gm sync --no-fetch --no-push >/dev/null
  local n; n="$("$REAL_GIT" -C "$T/mirror" log --format=%at | grep -c '^1740787200$')"
  assert_eq "$n" 2 'коммиты с одной секундой:'
}

test_no_code_or_messages_leak() {
  setup_env t4
  gm sync --no-fetch --no-push >/dev/null
  local files log
  files="$("$REAL_GIT" -C "$T/mirror" ls-tree --name-only HEAD | tr '\n' ' ')"
  assert_eq "$files" '.gitignore README.md ' 'файлы в зеркале:'
  log="$("$REAL_GIT" -C "$T/mirror" log --format=%B)"
  assert_not_contains "$log" 'secret'
  assert_not_contains "$log" 'foreign'
  assert_eq "$("$REAL_GIT" -C "$T/mirror" log --format=%ae | sort -u | tr '\n' ' ')" 'me@example.com ' 'автор:'
}

test_dates_match_source() {
  setup_env t5
  gm sync --no-fetch --no-push >/dev/null
  local want got
  want="$("$REAL_GIT" -C "$T/src" log --format='%at %ae' | grep -iv other@ | cut -d' ' -f1 | sort | tr '\n' ' ')"
  got="$("$REAL_GIT" -C "$T/mirror" log --format=%at HEAD~3..HEAD 2>/dev/null | sort | tr '\n' ' ')"
  assert_eq "$got" "$want" 'даты:'
}

test_since_filters_old() {
  setup_env t6
  gm sync --no-fetch --no-push --since 2024-01-01 >/dev/null
  assert_eq "$(mirror_count)" 3 'init + 2 коммита после 2024:'
}

test_dry_run_writes_nothing() {
  setup_env t7
  local out; out="$(gm sync --no-fetch --dry-run)"
  assert_contains "$out" 'ничего не записано'
  assert_eq "$(mirror_count)" 1 'после dry-run:'
  assert_eq "$(cat "$FAKE_PUSH_COUNT" 2>/dev/null || echo 0)" 0 'пушей:'
}

test_no_push_leaves_remote() {
  setup_env t8
  gm sync --no-fetch --no-push >/dev/null
  assert_eq "$("$REAL_GIT" -C "$T/remote.git" rev-list --all | wc -l | tr -d ' ')" 0 'коммитов в remote:'
}

test_push_reaches_remote() {
  setup_env t9
  local out; out="$(gm sync --no-fetch)"
  assert_contains "$out" 'запушено'
  assert_eq "$("$REAL_GIT" -C "$T/remote.git" rev-parse main 2>/dev/null)" "$("$REAL_GIT" -C "$T/mirror" rev-parse HEAD)" 'remote main:'
}

test_push_retries_on_5xx() {
  setup_env t10
  export FAKE_PUSH=5xx FAKE_PUSH_FAILS=2
  local out; out="$(gm sync --no-fetch)"
  assert_contains "$out" 'сервер ответил 5xx · попытка 2/4'
  assert_contains "$out" 'запушено'
  assert_eq "$(cat "$FAKE_PUSH_COUNT")" 3 'попыток:'
  assert_eq "$("$REAL_GIT" -C "$T/remote.git" rev-parse main 2>/dev/null)" "$("$REAL_GIT" -C "$T/mirror" rev-parse HEAD)" 'remote main:'
}

test_push_gives_up_after_retries() {
  setup_env t11
  export FAKE_PUSH=5xx FAKE_PUSH_FAILS=99 GITMIRROR_PUSH_RETRIES=3
  local out; out="$(gm sync --no-fetch)"
  unset GITMIRROR_PUSH_RETRIES
  assert_contains "$out" 'сервер отвечает 5xx, 3 попыток'
  assert_eq "$(cat "$FAKE_PUSH_COUNT")" 3 'попыток:'
}

test_auth_error_not_retried() {
  setup_env t12
  export FAKE_PUSH=auth FAKE_PUSH_FAILS=99
  local out; out="$(gm sync --no-fetch)"
  assert_contains "$out" 'нет доступа'
  assert_eq "$(cat "$FAKE_PUSH_COUNT")" 1 'попыток:'
}

test_no_ansi_in_pipe() {
  setup_env t13
  local out esc; esc="$(printf '\033')"
  out="$(gm sync --no-fetch --no-push; gm status; gm sources; "$BASH" "$ROOT/bin/gitmirror" --help 2>&1)"
  assert_not_contains "$out" "$esc" 'escape-коды:'
}

test_status_counts() {
  setup_env t14
  gm sync --no-fetch --no-push >/dev/null
  local out; out="$(gm status)"
  assert_contains "$out" 'коммитов  4'
  assert_contains "$out" 'src'
  assert_contains "$out" '2025'
}

test_unknown_flag_fails() {
  setup_env t15
  local out code=0; out="$(gm sync --bogus)" || code=$?
  assert_eq "$code" 1 'код выхода:'
  assert_contains "$out" 'неизвестный флаг'
}

# --- запуск ----------------------------------------------------------------
printf 'gitmirror e2e · bash %s · %s\n' "$BASH_VERSION" "$("$REAL_GIT" --version)"
for t in $(declare -F | awk '{print $3}' | grep '^test_'); do run "$t"; done
printf '\nпройдено: %s, упало: %s\n' "$PASS" "$FAIL"
[ "$FAIL" = 0 ]
