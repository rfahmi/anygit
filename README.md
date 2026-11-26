<div align="center">

# AnyGit

[![Platform](https://img.shields.io/badge/platform-macOS%2026%2B-lightgrey)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-6-orange)](https://swift.org)
[![License: MIT](https://img.shields.io/github/license/rfahmi/anygit)](LICENSE)

A **free, fast, native** macOS Git client built with SwiftUI. Forked from [Maple](https://github.com/poolcamacho/Maple) and evolved for daily personal & open-source workflows.

![AnyGit History tab with commit graph and diff](docs/screenshots/commit-graph.png)

</div>

## Why AnyGit

Most Git GUIs on macOS are Electron based, locked behind a subscription, or oversimplified to the point of hiding what Git actually does. AnyGit is none of those. It shells out to the `git` binary you already have, shows the full topology of your history, and stays out of the way when you know what you are doing.

## Features

- **Real commit graph.** Lane assignment, curved edges per parent, merge nodes rendered as a ring so joins stay legible across busy histories.
- **Interactive staging.** Tick a checkbox on any hunk header, or any individual `+` / `-` line, and stage only what you want. `Cmd+S` stages (or unstages) the current selection. Works in reverse too: view the staged diff and surgically peel changes back into the working tree.
- **Diff viewer with Blame toggle.** Syntax coloured hunks, line numbers, and per line author / hash / date when Blame is on.
- **Merge and rebase with conflict UX.** Detects `UU`, `AA`, `DD` automatically, shows an operation banner with Abort / Continue / Skip, and lets you resolve per file with Use Ours or Use Theirs.
- **Branch management.** Local and remote branches, checkout (including remote to local tracking), create, rename, delete.
- **Stash support.** Save, pop, apply, drop with custom messages.
- **Search.** Filter the active tab live: changes by path, commits by message / author / SHA, branches, and stashes.
- **Auto refresh.** A file-system watcher on the repository's git directory (refs, `HEAD`, index) picks up changes made outside the app, including in worktrees and submodules.
- **Adaptive layout.** The toolbar, sidebar, and panels collapse gracefully from a wide desktop down to a compact laptop window.

## Screenshots

### Merge conflict resolution

![Merge conflict view with operation banner and per file Use Ours / Use Theirs](docs/screenshots/conflict-resolution.png)

### Branch management

![Branches tab with local and remote branches](docs/screenshots/branches.png)

## Install

Grab the latest release from [Releases](https://github.com/rfahmi/anygit/releases/latest) (if available), or build from source below and drag `AnyGit.app` into `Applications`.

## Requirements

- macOS 26+ (Apple Silicon recommended, Intel supported)
- Git installed (ships with Xcode Command Line Tools)

## Building from source

- Xcode 26+ (Swift 6 toolchain)

```bash
git clone https://github.com/rfahmi/anygit.git
cd anygit
open Maple.xcodeproj
```

Build and run from Xcode with `Cmd+R`, or build a Release binary via CLI:

```bash
xcodebuild build -scheme Maple -configuration Release -destination 'platform=macOS'
```

## Architecture

```
Models/     Pure Sendable data (AppState, GitModels, StashModels)
Services/   GitService (actor, runs git via Process),
            GitCoordinator (@MainActor, orchestration),
            command extensions, CommitGraphBuilder,
            DiffParser, StatusParser, ConflictParser, FileWatcher
Views/      One file per view, all async work through the coordinator
Utils/      FolderPicker, DateExtensions
```

## Roadmap

### Done

- [x] Direct integration with the `git` binary via `Process`, with hardened stdin and pipe cleanup
- [x] Live `git status`, `git log`, `git diff` parsing
- [x] Commit, push, pull, fetch
- [x] Branch create, checkout, delete, rename
- [x] Stash save, pop, apply, drop
- [x] Auto refresh via a git-directory watcher (worktree and submodule aware)
- [x] Responsive layout with adaptive breakpoints
- [x] Separated architecture (Models / Services / Views / Utils)
- [x] Blame view with per line author, hash, date
- [x] Commit graph with real branch topology
- [x] Merge and rebase with conflict resolution UI
- [x] Interactive staging - hunk level (select hunks with checkboxes, stage or unstage)
- [x] Interactive staging - line level (pick individual `+` / `-` lines within a hunk)
- [x] `Cmd+S` stages / unstages the current selection
- [x] Search filtering across changes, commits, branches, and stashes
- [x] Confirmation prompts before destructive actions (delete branch, drop stash, abort)
- [x] Set upstream on first push (prompts for `git push -u`)
- [x] Actionable messages for common git failures (auth, network, no upstream, lock)
- [x] Remembers open repositories and selection across launches
- [x] `Cmd+Return` to commit
- [x] Signed and notarized `.dmg` releases via GitHub Actions
- [x] Unit and integration test suite running in CI

- [x] Tag management (create lightweight or annotated, list, delete)
- [x] Clone a repository from a URL

### Next

- [ ] Remote management (add, remove, configure)
- [ ] Command palette for frequent operations
- [ ] Settings and preferences

## Contributing

Contributions are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for the workflow and [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) for community expectations. Security issues go through the private flow in [SECURITY.md](SECURITY.md).

## Credits & License

AnyGit is forked from [Maple](https://github.com/poolcamacho/Maple) by **Pool Camacho**, licensed under the [MIT License](LICENSE).
