#!/bin/sh
# Tests for git-exclude. Needs only sh and git. Each case runs in a fresh
# temporary repository. Output is TAP-shaped: one "ok" or "not ok" per
# check, and the exit status is non-zero if any check failed.
set -u
here=$(cd "$(dirname "$0")" && pwd)
tmp=$(mktemp -d "${TMPDIR:-/tmp}/git-exclude-test.XXXXXX") || exit 1
# cd out first: a shell cannot delete the directory it sits in on Windows.
trap 'cd / && rm -rf "$tmp"' EXIT

# Keep the user's git configuration out of the picture, and make sure no
# inherited repository variables can point the temporary repositories at a
# real one.
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY

# Stop git's upward search at the temporary directory, so a TMPDIR that
# happens to sit inside a repository cannot stand in for the ones here.
export GIT_CEILING_DIRECTORIES="$tmp"
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
    printf '%s\n' "$3" | sed 's/^/# expected: /'
    printf '%s\n' "$2" | sed 's/^/# got:      /'
    failed=1
  fi
}

# A fresh repository with a src/ subdirectory, and cd into it.
fresh() {
  cd "$tmp" || exit 1
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
check "add from root actually ignores the file" "$(git check-ignore -q a.txt; echo $?)" "0"

fresh
check "add from subdirectory prefixes the path" \
  "$(cd src && git exclude b.txt)" "Excluded '/src/b.txt'"
check "add from subdirectory writes prefixed line" "$(excludes)" "/src/b.txt"
check "add from subdirectory actually ignores the file" \
  "$(git check-ignore -q src/b.txt; echo $?)" "0"

fresh
check "leading ./ is dropped" "$(git exclude ./a.txt)" "Excluded '/a.txt'"
check "repeated leading ./ is dropped" "$(git exclude ././b.txt)" "Excluded '/b.txt'"
check "leading ./ is dropped from a subdirectory" \
  "$(cd src && git exclude ./c.txt)" "Excluded '/src/c.txt'"
check "dropped ./ still ignores the file" "$(git check-ignore -q src/c.txt; echo $?)" "0"

fresh
git exclude "$tmp/repo/a.txt" > /dev/null 2>&1
check "absolute path is refused with 128" "$?" "128"
check "absolute path is reported as fatal" \
  "$(git exclude /x 2>&1 | cut -d' ' -f1)" "fatal:"
git exclude ../a.txt > /dev/null 2>&1
check "path with .. is refused with 128" "$?" "128"
git exclude a/../b.txt > /dev/null 2>&1
check "path with .. in the middle is refused with 128" "$?" "128"
git exclude good.txt /bad.txt > /dev/null 2>&1
check "a refused path means nothing is written" "$(excludes)" ""

fresh
check "trailing slash is stripped" "$(git exclude build/)" "Excluded '/build'"

fresh
check "repeated trailing slashes are stripped" "$(git exclude 'build//')" "Excluded '/build'"
check "remove matches what a double slash wrote" \
  "$(git exclude remove build)" "Removed '/build'"
check "three trailing slashes are stripped" "$(git exclude 'build///')" "Excluded '/build'"
git exclude // > /dev/null 2>&1
check "a path of only slashes is refused with 128" "$?" "128"

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
git exclude a.txt b.txt > /dev/null
mv .git/info/exclude "$tmp/shared"
ln -s "$tmp/shared" .git/info/exclude
git exclude remove a.txt > /dev/null
check "remove keeps a symlinked exclude file a symlink" \
  "$([ -L .git/info/exclude ] && echo yes)" "yes"
check "remove writes through the symlink" "$(grep -v '^#' "$tmp/shared")" "/b.txt"

fresh
chmod 600 .git/info/exclude
git exclude a.txt > /dev/null
git exclude remove a.txt > /dev/null
check "remove keeps the file mode" \
  "$(find .git/info/exclude -perm 600)" ".git/info/exclude"
check "remove leaves no temporary file" \
  "$([ -e .git/info/exclude.tmp ] && echo present || echo absent)" "absent"

fresh
git exclude a.txt b.txt > /dev/null
chmod 444 .git/info/exclude
git exclude remove a.txt > /dev/null 2>&1
check "remove on an unwritable exclude file exits 128" "$?" "128"
check "remove on an unwritable exclude file says so once" \
  "$(git exclude remove a.txt 2>&1 | grep -c '^fatal:')" "1"
check "remove on an unwritable exclude file leaves no temporary file" \
  "$([ -e .git/info/exclude.tmp ] && echo present || echo absent)" "absent"
check "remove on an unwritable exclude file changes nothing" "$(excludes)" "/a.txt
/b.txt"
chmod 644 .git/info/exclude

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
check "-h prints usage" "$(git exclude -h 2>&1 | head -1)" "usage: git exclude [--] <path>..."

fresh
git exclude remove > /dev/null 2>&1
check "remove with no paths exits 129" "$?" "129"
git exclude -- > /dev/null 2>&1
check "-- with no paths exits 129" "$?" "129"

fresh
printf '/a\nhand\n' > .git/info/exclude
git exclude remove "$(printf 'a\nhand')" > /dev/null 2>&1
check "a newline in an argument is refused with 128" "$?" "128"
check "a newline in an argument removes nothing" "$(excludes)" "/a
hand"

fresh
git exclude "" a.txt > /dev/null 2>&1
check "empty path is refused with 128" "$?" "128"
git exclude a.txt "" > /dev/null 2>&1
check "empty path anywhere means nothing is written" "$(excludes)" ""
git exclude ./ > /dev/null 2>&1
check "./ alone is refused with 128" "$?" "128"

fresh
check "edit is not a subcommand" "$(git exclude edit)" "Excluded '/edit'"
check "-- lets a file named rm be excluded" "$(git exclude -- rm)" "Excluded '/rm'"
check "-- lets a file named remove be removed" \
  "$(git exclude -- remove > /dev/null && git exclude remove -- remove)" "Removed '/remove'"
check "-- lets a path starting with - be excluded" "$(git exclude -- -x)" "Excluded '/-x'"
git exclude --remove y.txt > /dev/null 2>&1
check "an unknown option exits 129" "$?" "129"
check "an unknown option writes nothing" "$(excludes)" "/edit
/rm
/-x"

fresh
version=$(sed -n 's/^version=//p' "$here/git-exclude")
check "--version prints the version" "$(git exclude --version)" "git-exclude version $version"

fresh
check "no arguments opens the exclude file in GIT_EDITOR" \
  "$(GIT_EDITOR='echo EDITING' git exclude)" "EDITING $(git rev-parse --git-common-dir)/info/exclude"

fresh
chmod +x .git/info/exclude
GIT_EDITOR='' git exclude > /dev/null 2>&1
check "an empty editor is refused with 128" "$?" "128"
check "an empty editor does not run the exclude file" \
  "$(GIT_EDITOR='' git exclude 2>&1)" "fatal: no editor configured, set GIT_EDITOR or core.editor"

fresh
git commit -q --allow-empty -m init
git worktree add -q "$tmp/wt"
check "linked worktree writes to the common exclude file" \
  "$(cd "$tmp/wt" && git exclude w.txt)" "Excluded '/w.txt'"
check "linked worktree line lands in the main repository" "$(excludes)" "/w.txt"

rm -rf "$tmp/bare"
git init -q --bare "$tmp/bare"
cd "$tmp/bare" || exit 1
git exclude a.txt > /dev/null 2>&1
check "a bare repository refuses to exclude" "$?" "128"
check "a bare repository says so" \
  "$(git exclude a.txt 2>&1)" "fatal: this operation must be run in a work tree"
git exclude > /dev/null 2>&1
check "a bare repository refuses to open the editor" "$?" "128"
check "a bare repository has nothing written to it" \
  "$(grep -v '^#' "$tmp/bare/info/exclude" 2>/dev/null)" ""

fresh
git commit -q --allow-empty -m init
git worktree add -q "$tmp/wt2"
check "a linked worktree is not treated as bare" \
  "$(cd "$tmp/wt2" && git exclude w2.txt)" "Excluded '/w2.txt'"

mkdir -p "$tmp/norepo"
cd "$tmp/norepo" || exit 1
git exclude a.txt > /dev/null 2>&1
check "outside a repository exits 128 like git" "$?" "128"
check "outside a repository says so once" \
  "$(git exclude a.txt 2>&1 | grep -c '^fatal:')" "1"
check "outside a repository -h still works" "$(git exclude -h > /dev/null 2>&1; echo $?)" "129"

echo "1..$n"
exit $failed
