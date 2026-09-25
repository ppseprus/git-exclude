% GIT-EXCLUDE(1) git-exclude | Git Manual

# NAME

git-exclude - manage .git/info/exclude from the command line

# SYNOPSIS

**git exclude** [--] \<path\>...\
**git exclude** (**remove**|**rm**) [--] \<path\>...\
**git exclude**\
**git exclude** [**-h** | **--version**]

# DESCRIPTION

Keeps your own notes and working files in a repository without committing them, by writing patterns to *.git/info/exclude*. Think of them as notes scribbled in the margins of your own copy of a book. Adding them to *.gitignore* would turn your clutter into noise for everyone else, whereas every clone has its own local excludes file, which lives with the repository and is never committed or shared.

With no arguments, opens the exclude file in the editor git would use for a commit message, honouring **GIT_EDITOR**, **core.editor**, **VISUAL** and **EDITOR** in that order.

Given paths, appends one pattern per path. Every pattern is anchored to the repository root, so running **git exclude build** inside *src/* writes */src/build* and never matches a *build* elsewhere in the tree. A leading *./* is dropped. Absolute paths and paths containing *..* are refused, since the pattern is written relative to the repository root and the path need not exist. Trailing slashes are stripped; git treats the anchored pattern as matching either a file or a directory of that name. The path does not have to exist yet. A path that starts with **-**, or is named **remove** or **rm**, goes after **--**, as with git's own commands. An empty path, a path containing a newline, an absolute path and a path containing **..** are each refused before anything is written, as is any use inside a bare repository, where an excludes file has no meaning. Each path is reported as **Excluded** or **Already excluded**, and is never written twice.

# COMMANDS

**remove** \<path\>..., **rm** \<path\>...
:   Removes the pattern that **git exclude** \<path\> would have written, by exact line match, and reports **Removed**. Characters such as **\*** and **[** in a path are matched literally. If the path is hidden by some broader pattern that was not written for it, nothing is removed and the command reports **Not excluded**, rather than un-excluding everything else that pattern covers.

Lines are compared byte for byte, so a pattern an editor wrote with a carriage return is not recognised as the same pattern and is neither deduplicated nor removed.

# OPTIONS

**-h**
:   Prints a short usage summary.

**--version**
:   Prints the version.

# FILES

*$GIT_DIR/info/exclude*
:   In a linked worktree this resolves to the common git directory, which is where git reads the file from.

# SEE ALSO

**gitignore**(5), **git-var**(1)

The Git Ignores & Excludes extension for VS Code manages the same file from the explorer, and shows which rule ignores or excludes any file: https://marketplace.visualstudio.com/items?itemName=ppseprus.vscode-git-ignores-and-excludes

The idea comes from ".gitignore Isn't the Only Way To Ignore Files in Git" by Nelson Figueroa: https://nelson.cloud/.gitignore-isnt-the-only-way-to-ignore-files-in-git/

# AUTHOR

ppseprus
