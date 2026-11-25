//
//  Dialogs.swift
//  Maple
//
//  Created by Pool Camacho on 4/13/26.
//

import SwiftUI
import AppKit

struct CloneDialog: View {
    @Bindable var state: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var url = ""
    @State private var destinationParent: URL?

    private var trimmedURL: String { url.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var repoName: String { GitService.repositoryName(fromCloneURL: trimmedURL) }
    private var canClone: Bool { !trimmedURL.isEmpty && destinationParent != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Clone Repository")
                .font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                Text("Repository URL")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("https://github.com/user/repo.git", text: $url)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 420)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Destination")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Button("Choose Folder...") { pickFolder() }
                    Text(destinationParent?.path ?? "No folder chosen")
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            if let parent = destinationParent, !trimmedURL.isEmpty {
                Text("Clones into \(parent.appendingPathComponent(repoName).path)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Clone") { clone() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canClone)
            }
        }
        .padding(24)
        .frame(width: 480)
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose where to clone the repository"
        panel.prompt = "Choose"
        if panel.runModal() == .OK {
            destinationParent = panel.url
        }
    }

    private func clone() {
        guard let parent = destinationParent else { return }
        let cloneURL = trimmedURL
        dismiss()
        Task {
            try? await Task.sleep(for: .milliseconds(100))
            await state.coordinator.cloneRepository(url: cloneURL, into: parent.path)
        }
    }
}

struct NewBranchDialog: View {
    @Bindable var state: AppState
    var startPoint: GitCommit? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var branchName = ""
    @State private var checkoutAfterCreate = true

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let startPoint {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Create Branch at \(startPoint.shortID)")
                        .font(.headline)
                    Text(startPoint.message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            } else {
                Text("New Branch")
                    .font(.headline)
            }

            TextField("Branch name", text: $branchName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 320)
                .onSubmit { create() }

            if startPoint != nil {
                Toggle("Checkout branch after creating", isOn: $checkoutAfterCreate)
                    .toggleStyle(.checkbox)
                    .font(.caption)
            }

            HStack(spacing: 12) {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Create") {
                    create()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(branchName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
    }

    private func create() {
        let name = branchName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let targetCommit = startPoint?.id
        let shouldCheckout = startPoint == nil ? true : checkoutAfterCreate
        dismiss()
        // Delay the async work so the sheet finishes dismissing
        Task {
            try? await Task.sleep(for: .milliseconds(100))
            await state.coordinator.createNewBranch(name: name, startPoint: targetCommit, checkout: shouldCheckout)
        }
    }
}

struct ResetToCommitDialog: View {
    @Bindable var state: AppState
    let commit: GitCommit
    @Environment(\.dismiss) private var dismiss
    @State private var mode: GitResetMode = .mixed

    private var branchName: String {
        state.selectedRepository?.currentBranch ?? "HEAD"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Reset \(branchName) to \(commit.shortID)")
                    .font(.headline)
                Text(commit.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(GitResetMode.allCases) { option in
                    Button {
                        mode = option
                    } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: mode == option ? "largecircle.fill.circle" : "circle")
                                .foregroundStyle(mode == option ? Color.accentColor : .secondary)
                                .padding(.top, 2)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(option.title)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundStyle(option == .hard ? .red : .primary)
                                Text(option.summary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer()
                        }
                        .padding(8)
                        .background(
                            mode == option ? Color.accentColor.opacity(0.1) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 6)
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(width: 440)

            HStack(spacing: 12) {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)

                if mode == .hard {
                    Button("Reset", role: .destructive) { performReset() }
                        .keyboardShortcut(.defaultAction)
                } else {
                    Button("Reset") { performReset() }
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(24)
    }

    private func performReset() {
        let selectedMode = mode
        dismiss()
        Task {
            try? await Task.sleep(for: .milliseconds(100))
            await state.coordinator.resetCurrentBranch(to: commit, mode: selectedMode)
        }
    }
}

struct StashSaveDialog: View {
    @Bindable var state: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var message = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("Stash Changes")
                .font(.headline)

            TextField("Stash message (optional)", text: $message)
                .textFieldStyle(.roundedBorder)
                .frame(width: 300)
                .onSubmit { save() }

            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Stash") {
                    save()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
    }

    private func save() {
        let msg = message.trimmingCharacters(in: .whitespaces)
        dismiss()
        Task {
            try? await Task.sleep(for: .milliseconds(100))
            await state.coordinator.performStashSave(message: msg.isEmpty ? nil : msg)
        }
    }
}

struct NewTagDialog: View {
    @Bindable var state: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var tagName = ""
    @State private var message = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("New Tag")
                .font(.headline)

            TextField("Tag name", text: $tagName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 320)
                .onSubmit { create() }

            TextField("Message (optional, makes an annotated tag)", text: $message)
                .textFieldStyle(.roundedBorder)
                .frame(width: 320)

            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Create") {
                    create()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(tagName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
    }

    private func create() {
        let name = tagName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let msg = message.trimmingCharacters(in: .whitespaces)
        dismiss()
        Task {
            try? await Task.sleep(for: .milliseconds(100))
            await state.coordinator.createTag(name: name, message: msg.isEmpty ? nil : msg)
        }
    }
}

// MARK: - Merge

struct MergeDialog: View {
    @Bindable var state: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var selected: String = ""

    private var candidateBranches: [GitBranch] {
        let current = state.selectedRepository?.currentBranch
        return state.branches.filter { !$0.isCurrent && $0.name != current }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Merge Branch Into \(state.selectedRepository?.currentBranch ?? "current")")
                .font(.headline)

            Picker("Branch", selection: $selected) {
                Text("Choose a branch…").tag("")
                ForEach(candidateBranches) { branch in
                    Label(branch.name, systemImage: branch.isRemote ? "globe" : "arrow.triangle.branch")
                        .tag(branch.name)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 320)

            Text("A new merge commit will be created. If conflicts arise, you'll be able to resolve them from the Changes tab.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: 340, alignment: .leading)

            HStack(spacing: 12) {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Merge") { start() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(selected.isEmpty)
            }
        }
        .padding(24)
    }

    private func start() {
        let branch = selected
        dismiss()
        Task {
            try? await Task.sleep(for: .milliseconds(100))
            await state.coordinator.performMerge(branch: branch)
        }
    }
}

// MARK: - Rebase

struct RebaseDialog: View {
    @Bindable var state: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var selected: String = ""

    private var candidateBranches: [GitBranch] {
        let current = state.selectedRepository?.currentBranch
        return state.branches.filter { !$0.isCurrent && $0.name != current }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Rebase \(state.selectedRepository?.currentBranch ?? "current") onto…")
                .font(.headline)

            Picker("Onto", selection: $selected) {
                Text("Choose a branch…").tag("")
                ForEach(candidateBranches) { branch in
                    Label(branch.name, systemImage: branch.isRemote ? "globe" : "arrow.triangle.branch")
                        .tag(branch.name)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 320)

            Text(
                "Commits from the current branch will be replayed on top of the selected branch. "
                + "Conflicts can be resolved per-commit from the Changes tab."
            )
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: 340, alignment: .leading)

            HStack(spacing: 12) {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Rebase") { start() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(selected.isEmpty)
            }
        }
        .padding(24)
    }

    private func start() {
        let branch = selected
        dismiss()
        Task {
            try? await Task.sleep(for: .milliseconds(100))
            await state.coordinator.performRebase(onto: branch)
        }
    }
}

struct CommitDetailsDialog: View {
    @Bindable var state: AppState
    let commit: GitCommit
    @Environment(\.dismiss) private var dismiss
    @State private var details: GitCommitDetails?
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Commit Details")
                    .font(.headline)
                Spacer()
                Button("Copy SHA") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(commit.id, forType: .string)
                    state.successMessage = "Copied \(commit.shortID)"
                }
                .controlSize(.small)
                Button("Close") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .controlSize(.small)
            }

            Divider()

            if let details {
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 12) {
                        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 6) {
                            detailRow("Commit", value: details.sha, monospaced: true)
                            detailRow("Author", value: "\(details.authorName) <\(details.authorEmail)>")
                            detailRow("Author Date", value: details.authorDate)
                            if details.committerName != details.authorName
                                || details.committerEmail != details.authorEmail
                                || details.committerDate != details.authorDate {
                                detailRow("Committer", value: "\(details.committerName) <\(details.committerEmail)>")
                                detailRow("Commit Date", value: details.committerDate)
                            }
                            if !details.parents.isEmpty {
                                detailRow("Parents", value: details.parents.joined(separator: "\n"), monospaced: true)
                            }
                            if !details.refs.isEmpty {
                                detailRow("Refs", value: details.refs.joined(separator: ", "), monospaced: true)
                            }
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Message")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                            Text(details.fullMessage)
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                                .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 6))
                        }

                        if !details.statSummary.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Files Changed")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)
                                Text(details.statSummary)
                                    .font(.system(.caption, design: .monospaced))
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(10)
                                    .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 6))
                            }
                        }
                    }
                }
            } else if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ProgressView("Loading commit details…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(20)
        .frame(width: 560, height: 460)
        .task {
            guard let path = state.currentRepoPath else { return }
            do {
                details = try await state.git.commitDetails(for: commit.id, in: path)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    @ViewBuilder
    private func detailRow(_ label: String, value: String, monospaced: Bool = false) -> some View {
        GridRow {
            Text(label)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .frame(width: 85, alignment: .trailing)
            Text(value)
                .font(monospaced ? .system(.caption, design: .monospaced) : .callout)
                .textSelection(.enabled)
        }
    }
}
