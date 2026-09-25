# git-exclude

Keep your own notes and working files in the repo without committing them. Manage `.git/info/exclude` from the terminal, as `git exclude`.

## Usage

```
git exclude                        open .git/info/exclude
git exclude [--] <path>...         exclude paths, anchored to the repository root
git exclude remove [--] <path>...  remove them again, rm works too
git exclude -h                     show usage
git exclude --version              show version
```

Several paths at once, each reported on its own line:

```console
$ git exclude notes.md scripts/
Excluded '/notes.md'
Excluded '/scripts'
$ git exclude notes.md
Already excluded '/notes.md'
$ git exclude remove notes.md
Removed '/notes.md'
```

## Origin

Working inside a repository often produces files that belong with the repo but must never be committed. Think of them as notes scribbled in the margins of your own copy of a book. Adding them to `.gitignore` turns your clutter into noise for everyone else.

Git already has a place for exactly this: read [.gitignore Isn't the Only Way To Ignore Files in Git](https://nelson.cloud/.gitignore-isnt-the-only-way-to-ignore-files-in-git/) by Nelson Figueroa.

Every clone has a local excludes file: `.git/info/exclude`. It lives with the repository uncommitted. Reaching it, though, means knowing the path by heart, opening a file buried inside `.git`, and hand-writing gitignore patterns. This script removes that friction in a terminal.

## Installation

### Homebrew

This also installs the man page, so `git exclude --help` and `git help exclude` work.

```sh
brew install ppseprus/tap/git-exclude
```

### On your PATH

Symlink the script into a directory that is already on your PATH, or put its own directory there.

```sh
ln -s "$PWD/git-exclude" ~/bin/git-exclude
```

That gives you `git exclude -h`. For `--help` as well, put `git-exclude.1` in a `man1` directory on your MANPATH, since git answers `--help` by opening the man page rather than running the command.

### How git finds this

No alias entry is needed. When you run `git <command>` and it is not a core git program, git looks for an executable named `git-<command>` on PATH and runs it, passing the arguments through. This is git's own behaviour and works the same on macOS, Linux and Git for Windows. Git tries the PATH lookup before aliases, so an old `exclude` alias would be shadowed by this script and should be deleted. A shell alias such as `g=git` keeps working, since `g exclude` expands to `git exclude` before git sees it.

## Notes

**A script, not a git alias.** An alias would do the simple case in one line, but a script gets real quoting, multiple lines, subcommands and shellcheck. The two differ in one way that matters here: git runs a `!` alias from the top of the repository and hands it the subdirectory in `GIT_PREFIX`, whereas an external script runs where you typed the command and asks for the subdirectory with `git rev-parse --show-prefix`.

**One command, subcommands.** Git's own convention is a subcommand under the noun, as in `git remote add` and `git remote rm`, or `git worktree add` and `git worktree remove`. So removal is `git exclude remove` rather than a separate `git unexclude` or `git include`, with `rm` accepted as an alias the way `git remote` accepts it. A bare `git exclude` opens the file.

**Patterns are anchored.** Every entry is written as `/<path from the repository root>`, so `build` never accidentally matches every `build` directory in the tree. A leading `./` is dropped, and absolute paths or paths containing `..` are refused rather than written as patterns git would never match. Trailing slashes are stripped so `git exclude remove build/` matches what `git exclude build` wrote. Git treats `/build` as matching either a file or a directory.

**Removal refuses to guess.** A path is turned into a pattern exactly as adding would turn it, then that pattern is matched against the file line for line with `grep -vxF`, so a `*` or `[` in a name is never read as a glob or a regex. If a file is hidden by a broader pattern nobody wrote for it, such as `notes/` covering `notes/todo.md`, nothing is removed and the command reports `Not excluded`, rather than deleting that pattern and un-excluding everything else it covered. Removing rewrites the file in place, so an excludes file you have symlinked elsewhere stays a symlink.

**One line per path.** Each path gets `Excluded`, `Already excluded`, `Removed` or `Not excluded`, followed by the quoted pattern, the shape of git's own `Already on 'main'` and `Switched to branch 'main'`. A path is never written twice.

**The editor is git's.** Opening the file goes through `git var GIT_EDITOR`, so it honours `core.editor` the way `git commit` does, including editors invoked with arguments such as `code --wait`.

**Worktrees are handled.** The file is found through `git rev-parse --git-common-dir`, which is where git reads `info/exclude` from in a linked worktree too.

**A bare repository is refused.** An excludes file only has meaning against a work tree, so `git exclude` stops with git's own `this operation must be run in a work tree`, as `git commit` does. That also keeps it from writing into a directory that is itself a bare repository committed inside another one, where the config, `core.editor` included, would be supplied by whoever wrote that commit.

**Carriage returns are not handled.** Lines are compared byte for byte, so a pattern that some editor wrote with a trailing carriage return is neither deduplicated nor removed. Excludes files written by this command never contain one.

**Special characters are not escaped.** Nothing escapes `*`, `?`, `[`, `#`, `!`, `\` or trailing spaces in a file name before writing it as a pattern. Names like that are rare among the files you set aside, and the local excludes file is yours to fix by hand when it happens.

## Development

The man page is written in `git-exclude.1.md` and generated with `pandoc` by `./generate-man.sh`; the generated `git-exclude.1` is committed so that installing needs no `pandoc`. `./test.sh` runs the tests and needs only sh and git. The hooks in `hooks/` rebuild the man page when its source is committed and run the tests before a push. Enable them once per clone:

```sh
git config core.hooksPath hooks
```

## See also

The [Git Ignores & Excludes](https://marketplace.visualstudio.com/items?itemName=ppseprus.vscode-git-ignores-and-excludes) extension for VS Code manages the same file from the explorer, and shows which rule ignores or excludes any file.

## License

[MIT](LICENSE)
