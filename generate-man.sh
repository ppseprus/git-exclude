#!/bin/sh
# Generate git-exclude.1 from git-exclude.1.md with pandoc.
#
#   ./generate-man.sh            generate from git-exclude.1.md
#   ./generate-man.sh <file.md>  generate from another file, used by the
#                             pre-commit hook for the staged version
set -e
src="${1:-$(dirname "$0")/git-exclude.1.md}"
# -smart: without it pandoc turns every -- in the synopsis into an en dash.
pandoc -s -f markdown-smart -t man -M date="$(LC_ALL=C date "+%B %d, %Y")" "$src" -o "$(dirname "$0")/git-exclude.1"
