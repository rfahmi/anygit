//
//  GitCoordinator.swift
//  Maple
//
//  Created by Pool Camacho on 4/13/26.
//

import SwiftUI

@MainActor
final class GitCoordinator {
    let state: AppState
    var git: GitService { state.git }
    let recentRepos = RecentRepositoriesStore()

    init(state: AppState) {
        self.state = state
    }

    // MARK: - Persistence

    /// Restores the repositories that were open last session and re-selects the
    /// one that was active. Invalid or missing paths are dropped. Call once on
    /// launch.
    func restorePersistedRepositories() async {
        let paths = recentRepos.loadPaths()
        guard !paths.isEmpty else { return }

        var restored: [GitRepository] = []
        for path in paths {
            guard await git.validateRepository(at: path) == nil else { continue }
            let name = await git.repositoryName(at: path)
            let branch = (try? await git.currentBranch(in: path)) ?? "unknown"
            restored.append(GitRepository(name: name, path: path, currentBranch: branch))
        }

        state.repositories = restored
        recentRepos.save(paths: restored.map(\.path)) // prune paths that no longer resolve

        // Re-selecting drives the watcher + data load through the selection
        // onChange (see ContentView).
        if let selectedPath = recentRepos.loadSelectedPath(),
           let repo = restored.first(where: { $0.path == selectedPath }) {
            state.selectedRepository = repo
        }
    }

    // MARK: - Operation helpers

    enum RefreshStrategy {
        case load
        case refresh
        case none
    }

    func runOperation(
        refresh strategy: RefreshStrategy = .load,
        success: String? = nil,
        errorHandler: ((Error) async -> Void)? = nil,
        work: (String) async throws -> Void
    ) async {
        guard let path = state.currentRepoPath else { return }
        state.operationInProgress = true
        state.errorMessage = nil
        state.successMessage = nil
        do {
            try await work(path)
            switch strategy {
            case .load: await loadRepositoryData()
            case .refresh: await refresh()
            case .none: break
            }
            if let success {
                state.successMessage = success
            }
        } catch {
            if let errorHandler {
                await errorHandler(error)
            } else {
                state.errorMessage = error.localizedDescription
            }
        }
        state.operationInProgress = false
    }

    func runLightOperation(
        refresh strategy: RefreshStrategy = .refresh,
        success: String? = nil,
        work: (String) async throws -> Void
    ) async {
        guard let path = state.currentRepoPath else { return }
        do {
            try await work(path)
            switch strategy {
            case .load: await loadRepositoryData()
            case .refresh: await refresh()
            case .none: break
            }
            if let success {
                state.successMessage = success
            }
        } catch {
            state.errorMessage = error.localizedDescription
        }
    }

    // MARK: - Open repository

    func openRepository(at path: String) async {
        await openRepositories(at: [path])
    }

    func openRepositories(at paths: [String]) async {
        guard !paths.isEmpty else { return }

        var lastOpened: GitRepository?
        var failures: [String] = []

        for path in paths {
            if let validationError = await git.validateRepository(at: path) {
                let folderName = URL(fileURLWithPath: path).lastPathComponent
                failures.append("\(folderName): \(validationError)")
                continue
            }

            if let existing = state.repositories.first(where: { $0.path == path }) {
                lastOpened = existing
                continue
            }

            let name = await git.repositoryName(at: path)
            let branch: String
            do {
                branch = try await git.currentBranch(in: path)
            } catch {
                branch = "unknown"
            }

            let repo = GitRepository(name: name, path: path, currentBranch: branch)
            state.repositories.append(repo)
            lastOpened = repo
        }

        if !state.repositories.isEmpty {
            recentRepos.save(paths: state.repositories.map(\.path))
        }

        if let repo = lastOpened {
            // Setting the selection drives the watcher + data load through
            // `selectRepository()` (see ContentView's onChange). Opening the folder
            // that is already selected won't retrigger, so load explicitly too.
            let wasAlreadySelected = state.selectedRepository?.path == repo.path
            state.selectedRepository = repo
            if wasAlreadySelected {
                await selectRepository()
            }
        }

        if !failures.isEmpty {
            state.errorMessage = failures.joined(separator: "\n")
        }
    }

    // MARK: - Clone

    /// Clones `url` into `parentDirectory`, then opens the cloned repo. Surfaces
    /// classified errors (auth, network) on failure.
    func cloneRepository(url: String, into parentDirectory: String) async {
        state.operationInProgress = true
        state.errorMessage = nil
        state.successMessage = nil
        defer { state.operationInProgress = false }

        do {
            let name = GitService.repositoryName(fromCloneURL: url)
            let path = try await git.clone(url: url, into: parentDirectory, name: name)
            await openRepository(at: path)
            state.successMessage = "Cloned into \(name)"
        } catch {
            state.errorMessage = error.localizedDescription
        }
    }

    // MARK: - Repository selection

    /// Re-points the file watcher and loads data for the currently selected
    /// repository. Invoked whenever the sidebar selection changes.
    func selectRepository() async {
        guard let path = state.currentRepoPath else { return }
        recentRepos.save(selectedPath: path)
        // Resolve the real git dirs so the watcher follows refs/index correctly in
        // worktrees and submodules; skip watching if they can't be resolved
        // (manual refresh still works).
        if let paths = await git.repositoryPaths(in: path) {
            state.watcher.watch(gitDir: paths.gitDir, commonDir: paths.commonDir)
        } else {
            state.watcher.stop()
        }
        await loadRepositoryData()
    }

    // MARK: - Load all data for selected repo

    func loadRepositoryData() async {
        guard let path = state.currentRepoPath else { return }
        state.isLoading = true
        state.errorMessage = nil

        do {
            async let statusTask = git.status(in: path)
            async let logTask = git.log(in: path)
            async let branchTask = git.branches(in: path)
            async let currentBranchTask = git.currentBranch(in: path)
            async let stashTask = git.stashList(in: path)
            async let tagTask = git.tags(in: path)
            async let unpushedTask = git.unpushedCommitIDs(in: path)

            let (status, log, branchList, branch, stashList, tagList, unpushedIDs) = try await (
                statusTask, logTask, branchTask, currentBranchTask, stashTask, tagTask, unpushedTask
            )

            // The selection can change while these awaits are in flight (fast
            // repo switching, or a watcher-driven refresh). Discard stale results
            // so one repo's data never renders under another repo's selection.
            guard state.currentRepoPath == path else { return }

            state.fileChanges = status
            state.commits = log
            state.branches = branchList
            state.stashes = stashList
            state.tags = tagList
            state.unpushedCommitIDs = unpushedIDs
            state.operationState = git.detectOperationState(in: path)

            if let index = state.repositories.firstIndex(where: { $0.path == path }) {
                state.repositories[index].currentBranch = branch
                state.selectedRepository = state.repositories[index]
            }

            state.selectedCommit = nil
            state.selectedCommits = []
            state.selectedFileChange = nil
            state.currentDiffLines = []
            state.currentDiffFile = nil
            state.selectedLines = [:]
            state.commitDiffFiles = []
        } catch {
            guard state.currentRepoPath == path else { return }
            state.errorMessage = error.localizedDescription
        }

        guard state.currentRepoPath == path else { return }
        state.isLoading = false
    }

    // MARK: - Refresh (lightweight)

    func refresh() async {
        guard let path = state.currentRepoPath else { return }

        do {
            async let statusTask = git.status(in: path)
            async let logTask = git.log(in: path)
            async let branchTask = git.branches(in: path)
            async let currentBranchTask = git.currentBranch(in: path)
            async let stashTask = git.stashList(in: path)
            async let tagTask = git.tags(in: path)
            async let unpushedTask = git.unpushedCommitIDs(in: path)

            let (status, log, branchList, branch, stashList, tagList, unpushedIDs) = try await (
                statusTask, logTask, branchTask, currentBranchTask, stashTask, tagTask, unpushedTask
            )

            // Drop results if the selected repo changed mid-refresh (e.g. a
            // watcher event for the previous repo landing after a switch).
            guard state.currentRepoPath == path else { return }

            state.fileChanges = status
            state.commits = log
            state.branches = branchList
            state.stashes = stashList
            state.tags = tagList
            state.unpushedCommitIDs = unpushedIDs
            state.operationState = git.detectOperationState(in: path)

            if let index = state.repositories.firstIndex(where: { $0.path == path }) {
                state.repositories[index].currentBranch = branch
            }
        } catch {
            state.errorMessage = error.localizedDescription
        }
    }

    // MARK: - Load diffs

    func loadFileDiff() async {
        guard let path = state.currentRepoPath, let file = state.selectedFileChange else {
            state.currentDiffLines = []
            state.currentDiffFile = nil
            state.selectedLines = [:]
            return
        }

        state.selectedLines = [:]

        do {
            if file.status == .untracked {
                state.currentDiffLines = try await git.diffForUntrackedFile(file.path, in: path)
                state.currentDiffFile = nil
            } else {
                // Tracked files render from the structured `currentDiffFile`, so we
                // do not also materialize the flattened line array (it would double
                // the memory of a large diff for no benefit).
                state.currentDiffFile = try await git.diffFile(for: file.path, staged: file.isStaged, in: path)
                state.currentDiffLines = []
            }
        } catch {
            state.currentDiffLines = []
            state.currentDiffFile = nil
        }
    }

    func loadBlame() async {
        guard let path = state.currentRepoPath, let file = state.selectedFileChange else {
            state.currentBlameLines = []
            return
        }

        // Untracked files have no history to blame.
        if file.status == .untracked {
            state.currentBlameLines = []
            return
        }

        do {
            state.currentBlameLines = try await git.blame(for: file.path, in: path)
        } catch {
            state.currentBlameLines = []
        }
    }

    func loadCommitDiff() async {
        guard let path = state.currentRepoPath, let commit = state.selectedCommit else {
            state.commitDiffFiles = []
            return
        }

        do {
            state.commitDiffFiles = try await git.diffFilesForCommit(commit.id, in: path)
        } catch {
            state.commitDiffFiles = []
        }
    }

    // MARK: - Stage / Unstage

    func stageFile(_ file: GitFileChange) async {
        await runLightOperation { path in
            try await git.stage(file: file.path, in: path)
        }
        await reconcileSelectedFileDiff()
    }

    func unstageFile(_ file: GitFileChange) async {
        await runLightOperation { path in
            try await git.unstage(file: file.path, in: path)
        }
        await reconcileSelectedFileDiff()
    }

    func stageAllFiles() async {
        await runLightOperation { path in
            try await git.stageAll(in: path)
        }
        await reconcileSelectedFileDiff()
    }

    func unstageAllFiles() async {
        await runLightOperation { path in
            try await git.unstageAll(in: path)
        }
        await reconcileSelectedFileDiff()
    }

    // MARK: - Hunk / line staging

    /// Stages the selected `+` / `-` lines of the currently viewed (unstaged)
    /// file by piping a reconstructed patch to `git apply --cached`. When an
    /// entire hunk's worth of lines is selected the result is identical to the
    /// whole-hunk patch.
    func stageSelectedLines() async {
        guard let file = state.currentDiffFile,
              !state.selectedLines.isEmpty else { return }
        let patch = file.patchText(forLines: state.selectedLines)
        guard !patch.isEmpty else { return }

        await runLightOperation { path in
            try await git.applyPatch(patch, cached: true, in: path)
        }
        await reconcileSelectedFileDiff()
    }

    /// Unstages the selected `+` / `-` lines of the currently viewed (staged)
    /// file by piping the reverse patch to `git apply --cached --reverse`.
    func unstageSelectedLines() async {
        guard let file = state.currentDiffFile,
              !state.selectedLines.isEmpty else { return }
        let patch = file.patchText(forLines: state.selectedLines, reverse: true)
        guard !patch.isEmpty else { return }

        await runLightOperation { path in
            try await git.applyPatch(patch, cached: true, reverse: true, in: path)
        }
        await reconcileSelectedFileDiff()
    }

    private func reconcileSelectedFileDiff() async {
        guard let selected = state.selectedFileChange else { return }
        if state.fileChanges.contains(selected) {
            await loadFileDiff()
        } else {
            state.selectedFileChange = nil
            state.currentDiffFile = nil
            state.currentDiffLines = []
            state.selectedLines = [:]
        }
    }

    // MARK: - Commit

    @discardableResult
    func performCommit(message: String, amend: Bool = false) async -> Bool {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        var succeeded = false
        await runOperation(refresh: .load, success: "Committed successfully") { path in
            try await git.commit(message: trimmed, amend: amend, in: path)
            succeeded = true
        }
        return succeeded
    }

    func generateCommitMessage() async -> String? {
        guard let path = state.currentRepoPath else { return nil }
        state.errorMessage = nil
        do {
            let summary = try await git.stagedDiffForCommitMessage(in: path)
            return try await CommitMessageGenerator.generate(from: summary)
        } catch {
            state.errorMessage = error.localizedDescription
            return nil
        }
    }

    // MARK: - Push / Pull / Fetch

    func performPush() async {
        guard let path = state.currentRepoPath else { return }

        // If the branch already tracks an upstream, push straight away.
        if await git.upstreamBranch(in: path) != nil {
            await pushCurrentBranch()
            return
        }

        // No upstream: pick a remote and ask the user to set one, rather than
        // failing with a raw "has no upstream branch" error.
        let remotes = await git.remotes(in: path)
        guard let remote = remotes.contains("origin") ? "origin" : remotes.first else {
            state.errorMessage = "No remote is configured. Add a remote before pushing."
            return
        }
        let branch = (try? await git.currentBranch(in: path)) ?? ""
        guard !branch.isEmpty, !branch.hasPrefix("(") else {
            state.errorMessage = "Cannot set an upstream on a detached HEAD."
            return
        }
        state.pendingUpstreamPush = AppState.PendingUpstreamPush(remote: remote, branch: branch)
    }

    private func pushCurrentBranch() async {
        var successOverride: String?
        await runOperation(refresh: .refresh) { path in
            let output = try await git.push(in: path)
            successOverride = output.isEmpty ? "Pushed successfully" : output
        }
        if let successOverride {
            state.successMessage = successOverride
        }
    }

    /// Pushes the current branch to `remote` and sets it as the upstream. Invoked
    /// from the "set upstream and push" confirmation.
    func pushSettingUpstream(remote: String, branch: String) async {
        state.pendingUpstreamPush = nil
        var successOverride: String?
        await runOperation(refresh: .refresh) { path in
            let output = try await git.push(remote: remote, branch: branch, setUpstream: true, in: path)
            successOverride = output.isEmpty ? "Pushed and set upstream to \(remote)/\(branch)" : output
        }
        if let successOverride {
            state.successMessage = successOverride
        }
    }

    func performPull() async {
        var successOverride: String?
        await runOperation(refresh: .load) { path in
            let output = try await git.pull(in: path)
            successOverride = output.isEmpty ? "Pulled successfully" : output
        }
        if let successOverride {
            state.successMessage = successOverride
        }
    }

    func performFetch() async {
        await runOperation(refresh: .refresh, success: "Fetched successfully") { path in
            _ = try await git.fetch(in: path)
        }
    }
}
