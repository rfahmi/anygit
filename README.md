<div align="center">

# AnyGit

[![Platform](https://img.shields.io/badge/platform-macOS%2026%2B-lightgrey)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-6-orange)](https://swift.org)
[![License: MIT](https://img.shields.io/github/license/rfahmi/anygit)](LICENSE)

A **free, fast, native** macOS Git client built with SwiftUI. Forked from [Maple](https://github.com/poolcamacho/Maple) and evolved for daily personal & open-source workflows.

</div>

## Features

- **Real commit graph:** Lane assignment, curved edges per parent, and clear merge nodes.
- **Interactive staging:** Stage or unstage at the file, hunk, or individual `+` / `-` line level (`Cmd+S`), plus `Cmd+Return` to commit.
- **Diff & Blame:** Syntax-colored diffs, line numbers, and per-line Blame (author, hash, date).
- **Merge & rebase conflict UX:** Automatic conflict detection (`UU`, `AA`, `DD`) with Abort / Continue / Skip and Use Ours / Use Theirs.
- **Toolbar branch switcher:** Click the branch pill to search and switch local or remote branches (auto-creates local tracking branches instead of detached `HEAD`), plus full branch management in the Branches tab.
- **Stash & tag management:** Save, pop, apply, and drop stashes; create and delete lightweight or annotated tags.
- **Repository management:** Open multiple repositories, clone from URL, remove opened repos from the sidebar, and open directly in your IDE, terminal, or Finder.
- **Resizable split panes:** Drag horizontal or vertical dividers across the sidebar, Changes, and History views.
- **Auto refresh & search:** Git-directory file watcher (worktree & submodule aware) and live filtering across changes, commits, branches, and stashes.

## Install

1. Download the latest `.dmg` from [Releases](https://github.com/rfahmi/anygit/releases).
2. Open it and drag `AnyGit.app` into `Applications`.
3. If macOS Gatekeeper warns on an ad-hoc build, run:
   ```bash
   xattr -cr /Applications/AnyGit.app
   ```

## Building from source

Requires Xcode 26+ (Swift 6) and Git:

```bash
git clone https://github.com/rfahmi/anygit.git
cd anygit
open Maple.xcodeproj
```

Or build via CLI:

```bash
xcodebuild build -scheme Maple -configuration Release -destination 'platform=macOS' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO DEVELOPMENT_TEAM=""
```

## Credits & License

AnyGit is forked from [Maple](https://github.com/poolcamacho/Maple) by **Pool Camacho**, licensed under the [MIT License](LICENSE).
