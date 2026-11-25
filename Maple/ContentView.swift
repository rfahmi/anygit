//
//  ContentView.swift
//  Maple
//
//  Created by Pool Camacho on 4/13/26.
//

import SwiftUI

struct ContentView: View {
    @State private var state = AppState()
    @State private var columnVisibility = NavigationSplitViewVisibility.automatic
    @State private var showNewBranch = false
    @State private var showStashSave = false
    @State private var showMerge = false
    @State private var showRebase = false
    @State private var showClone = false

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(state: state, showClone: $showClone)
                .navigationSplitViewColumnWidth(min: 160, ideal: 220, max: 300)
        } detail: {
            if state.selectedRepository != nil {
                DetailAreaView(
                    state: state,
                    showNewBranch: $showNewBranch,
                    showStashSave: $showStashSave,
                    showMerge: $showMerge,
                    showRebase: $showRebase
                )
            } else {
                WelcomeView(state: state)
            }
        }
        .navigationTitle(state.selectedRepository?.name ?? "AnyGit")
        .frame(minWidth: 520, minHeight: 400)
        .onChange(of: state.selectedFileChange) {
            Task {
                await state.coordinator.loadFileDiff()
                if state.changesViewMode == .blame {
                    await state.coordinator.loadBlame()
                }
            }
        }
        .onChange(of: state.selectedCommit) {
            Task { await state.coordinator.loadCommitDiff() }
        }
        .onChange(of: state.selectedRepository?.path) { _, newPath in
            // Selecting a different repo in the sidebar must re-point the file
            // watcher and reload its data; keyed on `path` so branch-only updates
            // to the same repo don't retrigger a load.
            guard newPath != nil else { return }
            Task { await state.coordinator.selectRepository() }
        }
        .onAppear {
            state.setupWatcher()
            Task { await state.coordinator.restorePersistedRepositories() }
        }
        .confirmationDialog(
            "Set upstream and push?",
            isPresented: Binding(
                get: { state.pendingUpstreamPush != nil },
                set: { if !$0 { state.pendingUpstreamPush = nil } }
            ),
            titleVisibility: .visible,
            presenting: state.pendingUpstreamPush
        ) { pending in
            Button("Push and set upstream") {
                Task { await state.coordinator.pushSettingUpstream(remote: pending.remote, branch: pending.branch) }
            }
            Button("Cancel", role: .cancel) { state.pendingUpstreamPush = nil }
        } message: { pending in
            Text("Branch \"\(pending.branch)\" has no upstream yet. Push it to \(pending.remote) and track it?")
        }
        .sheet(isPresented: $showNewBranch) {
            NewBranchDialog(state: state)
        }
        .sheet(isPresented: $showStashSave) {
            StashSaveDialog(state: state)
        }
        .sheet(isPresented: $showMerge) {
            MergeDialog(state: state)
        }
        .sheet(isPresented: $showRebase) {
            RebaseDialog(state: state)
        }
        .sheet(isPresented: $showClone) {
            CloneDialog(state: state)
        }
    }
}

// MARK: - Detail Area

struct DetailAreaView: View {
    @Bindable var state: AppState
    @Binding var showNewBranch: Bool
    @Binding var showStashSave: Bool
    @Binding var showMerge: Bool
    @Binding var showRebase: Bool

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width

            VStack(spacing: 0) {
                ToolbarView(
                    state: state,
                    availableWidth: width,
                    showNewBranch: $showNewBranch,
                    showStashSave: $showStashSave,
                    showMerge: $showMerge,
                    showRebase: $showRebase
                )

                Divider()

                if state.operationState.isInProgress {
                    OperationBanner(state: state)
                }

                if state.isLoading {
                    ProgressView("Loading repository...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    DetailTabBar(
                        selection: $state.currentTab,
                        unpushedCommitCount: state.unpushedCommitCount
                    )
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)

                    Divider()

                    if let error = state.errorMessage {
                        VStack {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.title)
                                .foregroundStyle(.orange)
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)

                            Button("Dismiss") {
                                state.errorMessage = nil
                            }
                            .buttonStyle(.plain)
                            .font(.caption)
                            .foregroundStyle(.blue)
                            .padding(.top, 4)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        switch state.currentTab {
                        case .changes:
                            ChangesTabView(state: state, availableWidth: width)
                        case .history:
                            HistoryTabView(state: state, availableWidth: width)
                        case .branches:
                            BranchesTabView(state: state, availableWidth: width)
                        case .stashes:
                            StashesTabView(state: state)
                        case .tags:
                            TagsTabView(state: state)
                        }
                    }
                }
            }
        }
    }
}

private struct DetailTabBar: View {
    @Binding var selection: AppState.DetailTab
    let unpushedCommitCount: Int

    var body: some View {
        HStack(spacing: 2) {
            ForEach(AppState.DetailTab.allCases, id: \.self) { tab in
                let isSelected = selection == tab

                Button {
                    selection = tab
                } label: {
                    HStack(spacing: 5) {
                        Text(tab.rawValue)
                            .font(.subheadline)
                            .fontWeight(isSelected ? .semibold : .regular)

                        if tab == .history && unpushedCommitCount > 0 {
                            Text("\(unpushedCommitCount)")
                                .font(.system(size: 10, weight: .semibold))
                                .monospacedDigit()
                                .foregroundStyle(isSelected ? .white : .orange)
                                .padding(.horizontal, 5)
                                .frame(minWidth: 16, minHeight: 16)
                                .background(
                                    isSelected ? Color.white.opacity(0.22) : Color.orange.opacity(0.18),
                                    in: Capsule()
                                )
                        }
                    }
                    .foregroundStyle(isSelected ? .white : .primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5)
                    .background(
                        isSelected ? Color.accentColor : Color.clear,
                        in: RoundedRectangle(cornerRadius: 6)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    ContentView()
}
