#!/bin/sh
# Tests for git-exclude. Needs only sh and git. Each case runs in a fresh
# temporary repository. Output is TAP-shaped: one "ok" or "not ok" per
# check, and the exit status is non-zero if any check failed.
set -u
here=$(cd "$(dirname "$0")" && pwd)
tmp=$(mktemp -d "${TMPDIR:-/tmp}/git-exclude-test.XXXXXX")
trap 'rm -rf "$tmp"' EXIT

# Keep the user's git configuration out of the picture, and make sure no
# inherited repository variables can point the temporary repositories at a
# real one.
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com
PATH="$here:$PATH"
export PATH

n=0
failed=0
check() {
  n=$((n + 1))
  if [ "$2" = "$3" ]; then
    echo "ok $n - $1"
  else
    echo "not ok $n - $1"
    printf '  expected: %s\n  got:      %s\n' "$3" "$2"
    failed=1
  fi
}

# A fresh repository with a src/ subdirectory, and cd into it.
fresh() {
  rm -rf "$tmp/repo"
  mkdir -p "$tmp/repo/src"
  cd "$tmp/repo" || exit 1
  git init -q
}

# The user-written lines of the exclude file, comments stripped.
excludes() {
  grep -v '^#' "$tmp/repo/.git/info/exclude"
}

fresh
check "add from root reports Excluded" "$(git exclude a.txt)" "Excluded '/a.txt'"
check "add from root writes anchored line" "$(excludes)" "/a.txt"

fresh
check "add from subdirectory prefixes the path" \
  "$(cd src && git exclude b.txt)" "Excluded '/src/b.txt'"
check "add from subdirectory writes prefixed line" "$(excludes)" "/src/b.txt"

fresh
check "trailing slash is stripped" "$(git exclude build/)" "Excluded '/build'"

fresh
git exclude a.txt > /dev/null
check "second add reports Already excluded" "$(git exclude a.txt)" "Already excluded '/a.txt'"
check "second add writes nothing" "$(excludes)" "/a.txt"

fresh
git exclude a.txt b.txt > /dev/null
check "remove reports Removed" "$(git exclude remove a.txt)" "Removed '/a.txt'"
check "remove deletes only that line" "$(excludes)" "/b.txt"
check "rm is an alias for remove" "$(git exclude rm b.txt)" "Removed '/b.txt'"
check "exclude file is empty afterwards" "$(excludes)" ""

fresh
check "remove from subdirectory prefixes the path" \
  "$(cd src && git exclude b.txt > /dev/null && git exclude remove b.txt)" "Removed '/src/b.txt'"

fresh
git exclude build > /dev/null
check "remove of a path under a broader pattern reports Not excluded" \
  "$(git exclude remove build/out.txt)" "Not excluded '/build/out.txt'"
check "the broader pattern is left alone" "$(excludes)" "/build"

fresh
check "remove of an unknown path reports Not excluded" \
  "$(git exclude remove nope.txt)" "Not excluded '/nope.txt'"

fresh
git exclude 'a*b' axb > /dev/null
git exclude remove 'a*b' > /dev/null
check "glob characters are matched literally" "$(excludes)" "/axb"

fresh
check "backslashes are written literally" "$(git exclude 'a\tb')" "Excluded '/a\\tb'"
check "backslashes are stored literally" "$(excludes)" '/a\tb'
check "backslashes do not defeat the duplicate check" \
  "$(git exclude 'a\tb')" "Already excluded '/a\\tb'"
check "backslashes do not defeat remove" "$(git exclude remove 'a\tb')" "Removed '/a\\tb'"

fresh
printf '/old' > .git/info/exclude
git exclude new.txt > /dev/null
check "add after a line with no trailing newline keeps both lines" \
  "$(excludes)" "/old
/new.txt"

fresh
printf '/old\n' > .git/info/exclude
git exclude new.txt > /dev/null
check "add after a trailing newline inserts no blank line" \
  "$(cat .git/info/exclude)" "/old
/new.txt"

fresh
: > .git/info/exclude
git exclude a.txt > /dev/null
check "add to an empty exclude file writes one line" "$(cat .git/info/exclude)" "/a.txt"

fresh
rm .git/info/exclude
git exclude a.txt > /dev/null
check "add creates a missing exclude file" "$(cat .git/info/exclude)" "/a.txt"

fresh
git exclude -h > /dev/null 2>&1
check "-h exits 129" "$?" "129"
check "-h writes nothing" "$(excludes)" ""
check "-h prints usage" "$(git exclude -h 2>&1 | head -1)" "usage: git exclude [<path>...]"

fresh
git exclude remove > /dev/null 2>&1
check "remove with no paths exits 129" "$?" "129"

fresh
version=$(sed -n 's/^version=//p' "$here/git-exclude")
check "--version prints the version" "$(git exclude --version)" "git-exclude version $version"

fresh
check "no arguments opens the exclude file in GIT_EDITOR" \
  "$(GIT_EDITOR='echo EDITING' git exclude)" "EDITING $(git rev-parse --git-common-dir)/info/exclude"

fresh
git commit -q --allow-empty -m init
git worktree add -q "$tmp/wt"
check "linked worktree writes to the common exclude file" \
  "$(cd "$tmp/wt" && git exclude w.txt)" "Excluded '/w.txt'"
check "linked worktree line lands in the main repository" "$(excludes)" "/w.txt"

mkdir -p "$tmp/norepo"
cd "$tmp/norepo" || exit 1
git exclude a.txt > /dev/null 2>&1
check "outside a repository exits 128 like git" "$?" "128"
check "outside a repository -h still works" "$(git exclude -h > /dev/null 2>&1; echo $?)" "129"

echo "1..$n"
exit $failed
