# Changelog

All notable changes to this command are recorded here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## 0.1.0

2026-09-25

### Added

- `git exclude [--] <path>...`, writing each path to `.git/info/exclude` as a pattern anchored to the repository root, correct from any subdirectory. A leading `./` is dropped and trailing slashes are stripped. Each path is reported as `Excluded` or `Already excluded`, and is never written twice.
- `git exclude remove [--] <path>...`, removing those patterns again by exact line match, so a broader pattern that happens to cover the path is left alone. `rm` is accepted as an alias. Each path is reported as `Removed` or `Not excluded`, and the file keeps its inode, so an excludes file symlinked elsewhere stays a symlink.
- `git exclude` with no arguments, opening `.git/info/exclude` in the editor git would use for a commit message.
- `git exclude -h` for a usage summary and `git exclude --version` for the version.
- A `git-exclude(1)` man page, so `git exclude --help` and `git help exclude` work when it is installed.
- Arguments that could not become a usable pattern are refused before anything is written: absolute paths, paths containing `..`, empty paths, and paths containing a newline. An argument starting with `-` is a usage error unless it follows `--`, so a path named `remove`, `rm`, or `-x` goes there.
- Refuses to run in a bare repository, where an excludes file has no meaning.
