//
//  GitCoordinator+Operations.swift
//  Maple
//
//  Created by Pool Camacho on 4/13/26.
//

import Foundation

// MARK: - Branch, merge, rebase, cherry-pick, stash, and tag operations

extension GitCoordinator {

    func checkoutBranch(_ branch: GitBranch) async {
        await runOperation(refresh: .load) { path in
            if branch.isRemote {
                try await git.checkoutRemoteBranch(branch.name, in: path)
            } else {
                try await git.checkout(branch: branch.name, in: path)
            }
        }
    }

    func createNewBranch(name: String, startPoint: String? = nil, checkout: Bool = true) async {
        guard !name.isEmpty else { return }
        await runOperation(refresh: .load, success: "Branch '\(name)' created") { path in
            try await git.createBranch(name: name, startPoint: startPoint, checkout: checkout, in: path)
        }
    }

    func resetCurrentBranch(to commit: GitCommit, mode: GitResetMode) async {
        await runOperation(refresh: .load, success: "Reset to \(commit.shortID) (\(mode.title))") { path in
            try await git.reset(to: commit.id, mode: mode, in: path)
        }
    }

    func performMerge(branch: String) async {
        guard !branch.isEmpty else { return }
        var successOverride: String?
        await runOperation(
            refresh: .load,
            errorHandler: { [weak self] error in
                guard let self else { return }
                await self.loadRepositoryData()
                if self.state.operationState.isInProgress {
                    self.state.errorMessage = "Merge has conflicts. Resolve them and click Continue."
                } else {
                    self.state.errorMessage = error.localizedDescription
                }
            }
        ) { path in
            let output = try await git.merge(branch: branch, in: path)
            successOverride = output.isEmpty ? "Merged \(branch)" : output
        }
        if let successOverride {
            state.successMessage = successOverride
        }
    }

    func abortMerge() async {
        await runOperation(refresh: .load, success: "Merge aborted") { path in
            try await git.mergeAbort(in: path)
        }
    }

    func continueMerge() async {
        await runOperation(refresh: .load, success: "Merge completed") { path in
            try await git.mergeContinue(in: path)
        }
    }

    func performRebase(onto branch: String) async {
        guard !branch.isEmpty else { return }
        var successOverride: String?
        await runOperation(
            refresh: .load,
            errorHandler: { [weak self] error in
                guard let self else { return }
                await self.loadRepositoryData()
                if self.state.operationState.isInProgress {
                    self.state.errorMessage = "Rebase has conflicts. Resolve them and click Continue."
                } else {
                    self.state.errorMessage = error.localizedDescription
                }
            }
        ) { path in
            let output = try await git.rebase(onto: branch, in: path)
            successOverride = output.isEmpty ? "Rebased onto \(branch)" : output
        }
        if let successOverride {
            state.successMessage = successOverride
        }
    }

    func abortRebase() async {
        await runOperation(refresh: .load, success: "Rebase aborted") { path in
            try await git.rebaseAbort(in: path)
        }
    }

    func continueRebase() async {
        await runOperation(
            refresh: .load,
            success: "Rebase continued",
            errorHandler: { [weak self] error in
                guard let self else { return }
                await self.loadRepositoryData()
                if self.state.operationState.isInProgress {
                    self.state.errorMessage = "More conflicts remain. Resolve them and click Continue."
                } else {
                    self.state.errorMessage = error.localizedDescription
                }
            }
        ) { path in
            try await git.rebaseContinue(in: path)
        }
    }

    func performCherryPick(commits: [GitCommit]) async {
        guard !commits.isEmpty else { return }
        let hashes = commits.map(\.id)
        let label = commits.count == 1 ? commits[0].shortID : "\(commits.count) commits"
        await runOperation(
            refresh: .load,
            success: "Cherry-picked \(label)",
            errorHandler: { [weak self] error in
                guard let self else { return }
                await self.loadRepositoryData()
                if self.state.operationState.isInProgress {
                    self.state.errorMessage = "Cherry-pick has conflicts. Resolve them and click Continue."
                } else {
                    self.state.errorMessage = error.localizedDescription
                }
            }
        ) { path in
            try await git.cherryPick(commits: hashes, in: path)
        }
    }

    func abortCherryPick() async {
        await runOperation(refresh: .load, success: "Cherry-pick aborted") { path in
            try await git.cherryPickAbort(in: path)
        }
    }

    func continueCherryPick() async {
        await runOperation(
            refresh: .load,
            success: "Cherry-pick continued",
            errorHandler: { [weak self] error in
                guard let self else { return }
                await self.loadRepositoryData()
                if self.state.operationState.isInProgress {
                    self.state.errorMessage = "More conflicts remain. Resolve them and click Continue."
                } else {
                    self.state.errorMessage = error.localizedDescription
                }
            }
        ) { path in
            try await git.cherryPickContinue(in: path)
        }
    }

    func skipRebase() async {
        await runOperation(refresh: .load) { path in
            try await git.rebaseSkip(in: path)
        }
    }

    func useOurs(file: GitFileChange) async {
        await runLightOperation { path in
            try await git.checkoutOurs(file: file.path, in: path)
        }
    }

    func useTheirs(file: GitFileChange) async {
        await runLightOperation { path in
            try await git.checkoutTheirs(file: file.path, in: path)
        }
    }

    func deleteLocalBranch(_ branch: GitBranch) async {
        await runLightOperation { path in
            try await git.deleteBranch(name: branch.name, in: path)
        }
    }

    // MARK: - Stash operations

    func performStashSave(message: String?) async {
        await runOperation(refresh: .load, success: "Changes stashed") { path in
            try await git.stashSave(message: message, in: path)
        }
    }

    func performStashPop(index: Int = 0) async {
        await runLightOperation(refresh: .load, success: "Stash popped") { path in
            try await git.stashPop(index: index, in: path)
        }
    }

    func performStashApply(index: Int = 0) async {
        await runLightOperation(refresh: .load) { path in
            try await git.stashApply(index: index, in: path)
        }
    }

    func performStashDrop(index: Int) async {
        await runLightOperation(refresh: .load) { path in
            try await git.stashDrop(index: index, in: path)
        }
    }

    // MARK: - Tag operations

    func createTag(name: String, message: String?) async {
        guard !name.isEmpty else { return }
        await runOperation(refresh: .load, success: "Tag '\(name)' created") { path in
            try await git.createTag(name: name, message: message, in: path)
        }
    }

    func deleteTag(_ tag: GitTag) async {
        await runLightOperation(refresh: .load) { path in
            try await git.deleteTag(name: tag.name, in: path)
        }
    }

    // MARK: - Repository management

    /// Removes a repository from the open list and updates persisted state.
    /// Does not delete anything on disk.
    func removeRepository(_ repository: GitRepository) {
        state.repositories.removeAll { $0.path == repository.path }
        recentRepos.save(paths: state.repositories.map(\.path))

        guard state.selectedRepository?.path == repository.path else { return }

        if let next = state.repositories.first {
            state.selectedRepository = next
            return
        }

        state.watcher.stop()
        recentRepos.save(selectedPath: nil)
        state.selectedRepository = nil
        state.commits = []
        state.fileChanges = []
        state.branches = []
        state.stashes = []
        state.tags = []
        state.currentDiffLines = []
        state.currentDiffFile = nil
        state.selectedLines = [:]
        state.commitDiffFiles = []
        state.currentBlameLines = []
        state.selectedCommit = nil
        state.selectedCommits = []
        state.selectedFileChange = nil
        state.unpushedCommitIDs = []
        state.operationState = .idle
        state.errorMessage = nil
        state.successMessage = nil
    }

    // MARK: - Discard changes

    func discardFile(_ file: GitFileChange) async {
        guard !file.isStaged else { return }
        await runLightOperation { path in
            try await git.discard(file: file.path, status: file.status, in: path)
        }
        await reconcileSelectedFileDiff()
    }

    func discardAllFiles() async {
        await runLightOperation { path in
            try await git.discardAll(in: path)
        }
        await reconcileSelectedFileDiff()
    }

    /// Discards the selected `+` / `-` lines of the currently viewed unstaged
    /// file by applying the reverse patch directly to the working tree.
    func discardSelectedLines() async {
        guard let selected = state.selectedFileChange,
              !selected.isStaged,
              selected.status != .untracked,
              let file = state.currentDiffFile,
              !state.selectedLines.isEmpty else { return }
        let patch = file.patchText(forLines: state.selectedLines, reverse: true)
        guard !patch.isEmpty else { return }

        await runLightOperation { path in
            try await git.applyPatch(patch, cached: false, reverse: true, in: path)
        }
        await reconcileSelectedFileDiff()
    }
}
