//
//  CommitHistoryView.swift
//  Maple
//
//  Created by Pool Camacho on 4/13/26.
//

import SwiftUI
import AppKit

struct CommitHistoryView: View {
    @Bindable var state: AppState
    var availableWidth: CGFloat = 800
    @Binding var layout: SplitLayout

    @State private var branchTargetCommit: GitCommit?
    @State private var resetTargetCommit: GitCommit?
    @State private var detailsTargetCommit: GitCommit?

    init(
        state: AppState,
        availableWidth: CGFloat = 800,
        layout: Binding<SplitLayout> = .constant(.vertical)
    ) {
        self.state = state
        self.availableWidth = availableWidth
        self._layout = layout
    }

    private var showAuthor: Bool { availableWidth > 550 }
    private var showDate: Bool { availableWidth > 450 }
    private var showSHA: Bool { availableWidth > 380 }

    private let rowHeight: CGFloat = 30
    private let laneWidth: CGFloat = 14

    private var visibleCommits: [GitCommit] {
        state.filteredCommits
    }

    private var workingTreeLabel: String {
        let count = state.fileChanges.count
        if count == 0 { return "No changes" }
        return count == 1 ? "1 uncommitted change" : "\(count) uncommitted changes"
    }

    private func displayCommits(from commits: [GitCommit]) -> [GitCommit] {
        guard state.searchText.isEmpty,
              let currentBranch = state.selectedRepository?.currentBranch,
              let head = commits.first(where: { $0.refs.contains(currentBranch) || $0.branch == currentBranch }) else {
            return commits
        }
        let workingTree = GitCommit(
            id: CommitGraphBuilder.workingTreeNodeID,
            shortID: "",
            message: workingTreeLabel,
            author: "",
            date: Date(),
            branch: nil,
            parents: [head.id]
        )
        return [workingTree] + commits
    }

    private var publishedBranchNames: Set<String> {
        Set(
            state.branches
                .filter(\.isRemote)
                .compactMap { branch in
                    guard let slash = branch.name.firstIndex(of: "/") else { return nil }
                    return String(branch.name[branch.name.index(after: slash)...])
                }
        )
    }

    /// Returns selected commits in oldest-to-newest order when the right-clicked
    /// commit is part of a multi-selection, or just `[clicked]` otherwise.
    private func cherryPickTargets(clicked: GitCommit, in commits: [GitCommit]) -> [GitCommit] {
        guard state.selectedCommits.contains(clicked), state.selectedCommits.count > 1 else {
            return [clicked]
        }
        // `commits` is newest-first, so reversing index order replays oldest-first.
        return commits.reversed().filter { state.selectedCommits.contains($0) }
    }

    private func checkoutableBranches(for commit: GitCommit) -> [GitBranch] {
        let refs = Set(commit.refs.isEmpty ? (commit.branch.map { [$0] } ?? []) : commit.refs)
        guard !refs.isEmpty else { return [] }

        let matching = state.branches.filter {
            !$0.isCurrent && !$0.name.hasSuffix("/HEAD") && refs.contains($0.name)
        }
        let localNames = Set(matching.filter { !$0.isRemote }.map(\.name))
        return matching.filter { branch in
            if !branch.isRemote { return true }
            let shortName = branch.name.split(separator: "/", maxSplits: 1).last.map(String.init) ?? branch.name
            return !localNames.contains(shortName)
        }
    }

    var body: some View {
        // Build the graph layout once per render (it was previously rebuilt two
        // to three times: for the header width, the column header, and each row).
        let commits = visibleCommits
        let graphCommits = displayCommits(from: commits)
        let currentLayout = CommitGraphBuilder.build(
            from: graphCommits,
            currentBranch: state.selectedRepository?.currentBranch
        )
        let graphW = max(40, CGFloat(currentLayout.laneCount) * laneWidth + 12)

        VStack(spacing: 0) {
            HStack {
                Text("Commit History")
                    .font(.headline)
                Spacer()
                if state.unpushedCommitCount > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 10, weight: .bold))
                        Text("\(state.unpushedCommitCount) unpushed")
                    }
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.15), in: Capsule())
                }
                Text("\(commits.count) commits")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("Branch scope", selection: $state.showAllBranchesInHistory) {
                    Text("Current").tag(false)
                    Text("All").tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
                .help("Show current branch or all branches")
                .onChange(of: state.showAllBranchesInHistory) {
                    Task { await state.coordinator.reloadHistory() }
                }
                Picker("Layout", selection: $layout) {
                    ForEach(SplitLayout.allCases, id: \.self) { option in
                        Image(systemName: option.systemImage)
                            .help(option.helpText)
                            .tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
                .accessibilityLabel("History layout")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.bar)

            Divider()

            HStack(spacing: 0) {
                Text("Graph")
                    .frame(width: graphW, alignment: .leading)
                    .padding(.leading, 12)
                Text("Message")
                    .frame(maxWidth: .infinity, alignment: .leading)
                if showAuthor {
                    Text("Author")
                        .frame(width: 100, alignment: .leading)
                }
                if showDate {
                    Text("Date")
                        .frame(width: 80, alignment: .trailing)
                }
                if showSHA {
                    Text("SHA")
                        .frame(width: 64, alignment: .trailing)
                }
            }
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .padding(.trailing, 12)
            .padding(.vertical, 6)
            .background(.quaternary.opacity(0.5))

            Divider()

            ScrollViewReader { proxy in
                List(selection: $state.selectedCommits) {
                    ForEach(Array(graphCommits.enumerated()), id: \.element.id) { index, commit in
                        let isWorkingTree = commit.id == CommitGraphBuilder.workingTreeNodeID
                        let row = CommitRow(
                            commit: commit,
                            rowIndex: index,
                            commits: graphCommits,
                            unpushedCommitIDs: state.unpushedCommitIDs,
                            currentBranch: state.selectedRepository?.currentBranch,
                            publishedBranchNames: publishedBranchNames,
                            hasWorkingTreeChanges: !state.fileChanges.isEmpty,
                            layout: currentLayout,
                            graphWidth: graphW,
                            laneWidth: laneWidth,
                            rowHeight: rowHeight,
                            showAuthor: showAuthor,
                            showDate: showDate,
                            showSHA: showSHA
                        )
                        .id("\(commit.id)-\(commit.refs.joined(separator: ","))")
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))

                        if isWorkingTree {
                            row
                                .onTapGesture {
                                    state.currentTab = .changes
                                }
                        } else {
                            row
                                .tag(commit)
                                .contextMenu {
                                    commitContextMenu(for: commit, in: commits)
                                }
                        }
                    }
                }
                .listStyle(.plain)
                .onChange(of: state.selectedRepository?.currentBranch) { _, newBranch in
                    guard let newBranch,
                          let target = commits.first(where: { $0.refs.contains(newBranch) || $0.branch == newBranch }) else {
                        return
                    }
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo("\(target.id)-\(target.refs.joined(separator: ","))", anchor: .center)
                    }
                }
            }
        }
        .sheet(item: $branchTargetCommit) { commit in
            NewBranchDialog(state: state, startPoint: commit)
        }
        .sheet(item: $resetTargetCommit) { commit in
            ResetToCommitDialog(state: state, commit: commit)
        }
        .sheet(item: $detailsTargetCommit) { commit in
            CommitDetailsDialog(state: state, commit: commit)
        }
    }

    @ViewBuilder
    private func commitContextMenu(for commit: GitCommit, in commits: [GitCommit]) -> some View {
        let targets = cherryPickTargets(clicked: commit, in: commits)
        let checkoutBranches = targets.count == 1 ? checkoutableBranches(for: commit) : []

        if !checkoutBranches.isEmpty {
            ForEach(checkoutBranches) { branch in
                Button {
                    Task { await state.coordinator.checkoutBranch(branch) }
                } label: {
                    Label("Checkout \(branch.name)", systemImage: "arrow.triangle.branch")
                }
                .disabled(state.operationInProgress)
            }
            Divider()
        }

        Button {
            Task { await state.coordinator.performCherryPick(commits: targets) }
        } label: {
            let label = targets.count == 1
                ? "Cherry-pick \(targets[0].shortID)"
                : "Cherry-pick \(targets.count) commits"
            Label(label, systemImage: "arrow.uturn.right")
        }
        .disabled(state.operationInProgress)

        if targets.count == 1 {
            Divider()

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(commit.id, forType: .string)
                state.successMessage = "Copied \(commit.shortID)"
            } label: {
                Label("Copy Commit ID", systemImage: "doc.on.doc")
            }

            Button {
                detailsTargetCommit = commit
            } label: {
                Label("Commit Details…", systemImage: "info.circle")
            }

            Divider()

            Button {
                branchTargetCommit = commit
            } label: {
                Label("Create branch at commit…", systemImage: "arrow.triangle.branch")
            }

            if let branch = state.selectedRepository?.currentBranch {
                Button {
                    resetTargetCommit = commit
                } label: {
                    Label("Reset \(branch) to this commit…", systemImage: "arrow.counterclockwise")
                }
            }
        }
    }
}

struct CommitRow: View {
    let commit: GitCommit
    let rowIndex: Int
    let commits: [GitCommit]
    let unpushedCommitIDs: Set<String>
    var currentBranch: String?
    var publishedBranchNames: Set<String> = []
    var hasWorkingTreeChanges: Bool = false
    let layout: CommitGraphLayout
    let graphWidth: CGFloat
    let laneWidth: CGFloat
    let rowHeight: CGFloat
    var showAuthor: Bool = true
    var showDate: Bool = true
    var showSHA: Bool = true

    private var branchColor: Color {
        CommitGraphColors.color(forLane: layout.node(atRow: rowIndex)?.lane ?? 0)
    }

    private var mergedBadges: [(label: String, isSynced: Bool)] {
        let allRefs = commit.refs.isEmpty ? (commit.branch.map { [$0] } ?? []) : commit.refs
        guard !allRefs.isEmpty else { return [] }

        let refSet = Set(allRefs)
        var consumedRemotes = Set<String>()
        var badges: [(label: String, isSynced: Bool)] = []

        for ref in allRefs {
            if consumedRemotes.contains(ref) { continue }
            let originRef = "origin/\(ref)"
            if !ref.contains("/"), refSet.contains(originRef) {
                consumedRemotes.insert(originRef)
                badges.append((label: ref, isSynced: true))
            } else {
                badges.append((label: ref, isSynced: false))
            }
        }
        return badges
    }

    var body: some View {
        HStack(spacing: 0) {
            CommitGraphRowCanvas(
                rowIndex: rowIndex,
                commits: commits,
                unpushedCommitIDs: unpushedCommitIDs,
                layout: layout,
                laneWidth: laneWidth,
                rowHeight: rowHeight
            )
            .frame(width: graphWidth, height: rowHeight)

            HStack(spacing: 6) {
                if commit.id == CommitGraphBuilder.workingTreeNodeID {
                    Text(commit.message)
                        .foregroundStyle(hasWorkingTreeChanges ? .primary : .secondary)
                        .fontWeight(hasWorkingTreeChanges ? .medium : .regular)
                        .lineLimit(1)
                } else {
                    ForEach(mergedBadges, id: \.label) { badge in
                        let isLocalOnly = !badge.isSynced
                            && !badge.label.contains("/")
                            && !publishedBranchNames.contains(badge.label)
                        BranchTag(
                            name: badge.label,
                            isSyncedWithOrigin: badge.isSynced,
                            isCurrent: badge.label == currentBranch,
                            isLocalOnly: isLocalOnly,
                            color: branchColor
                        )
                    }
                    Text(commit.message)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if commit.id != CommitGraphBuilder.workingTreeNodeID {
                if showAuthor {
                    Text(commit.author)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .frame(width: 100, alignment: .leading)
                }

                if showDate {
                    Text(commit.date.relativeDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 80, alignment: .trailing)
                }

                if showSHA {
                    Text(commit.shortID)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .frame(width: 64, alignment: .trailing)
                }
            }
        }
        .padding(.trailing, 12)
        .frame(height: rowHeight)
        .contentShape(Rectangle())
    }
}

#Preview {
    CommitHistoryView(state: AppState(), availableWidth: 800)
        .frame(width: 800, height: 400)
}
