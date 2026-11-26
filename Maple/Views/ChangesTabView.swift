//
//  ChangesTabView.swift
//  Maple
//
//  Created by Pool Camacho on 4/13/26.
//

import SwiftUI

private struct HunkStagingToolbar: View {
    @Bindable var state: AppState
    @State private var showDiscardConfirm = false

    private var isStagedView: Bool {
        state.selectedFileChange?.isStaged ?? false
    }

    private var canDiscardLines: Bool {
        !isStagedView && state.selectedFileChange?.status != .untracked
    }

    private var selectedLineCount: Int {
        state.selectedLines.values.reduce(0) { $0 + $1.count }
    }

    private var modifiableLineCount: Int {
        guard let file = state.currentDiffFile else { return 0 }
        return file.hunks.reduce(0) { total, hunk in
            total + hunk.lines.reduce(0) { count, line in
                count + ((line.type == .addition || line.type == .deletion) ? 1 : 0)
            }
        }
    }

    private var allSelected: Bool {
        modifiableLineCount > 0 && selectedLineCount == modifiableLineCount
    }

    private var hasSelection: Bool { selectedLineCount > 0 }

    var body: some View {
        HStack(spacing: 8) {
            Button {
                if allSelected {
                    state.selectedLines = [:]
                } else {
                    state.selectedLines = Self.allLines(in: state.currentDiffFile)
                }
            } label: {
                Text(allSelected ? "Deselect all" : "Select all")
            }
            .disabled(modifiableLineCount == 0)

            Text("\(selectedLineCount) of \(modifiableLineCount) lines")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            if isStagedView {
                Button {
                    Task { await state.coordinator.unstageSelectedLines() }
                } label: {
                    Label("Unstage selected", systemImage: "minus.circle")
                }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(!hasSelection || state.operationInProgress)
            } else {
                if canDiscardLines {
                    Button {
                        showDiscardConfirm = true
                    } label: {
                        Label("Discard selected", systemImage: "arrow.uturn.backward")
                    }
                    .disabled(!hasSelection || state.operationInProgress)
                }

                Button {
                    Task { await state.coordinator.stageSelectedLines() }
                } label: {
                    Label("Stage selected", systemImage: "plus.circle")
                }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(!hasSelection || state.operationInProgress)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
        .alert("Discard Selected Lines?", isPresented: $showDiscardConfirm) {
            Button("Discard", role: .destructive) {
                Task { await state.coordinator.discardSelectedLines() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently reverts \(selectedLineCount) selected line(s) in the working tree. It cannot be undone.")
        }
    }

    private static func allLines(in file: DiffFile?) -> [Int: Set<Int>] {
        guard let file else { return [:] }
        var out: [Int: Set<Int>] = [:]
        for (hunkIndex, hunk) in file.hunks.enumerated() {
            let indices = DiffView.modifiableIndices(in: hunk)
            if !indices.isEmpty {
                out[hunkIndex] = indices
            }
        }
        return out
    }
}

struct ChangesTabView: View {
    @Bindable var state: AppState
    let availableWidth: CGFloat
    @AppStorage("changesLayout") private var layout: SplitLayout = .horizontal
    @AppStorage("changesSidebarWidth") private var sidebarWidth: Double = 280
    @AppStorage("changesTopRatio") private var topRatio: Double = 0.45
    @State private var dragStartSize: Double?

    private var blameAvailable: Bool {
        guard let file = state.selectedFileChange else { return false }
        return file.status != .untracked && file.status != .conflicted
    }

    private var showingConflict: Bool {
        state.selectedFileChange?.status == .conflicted
    }

    var body: some View {
        if layout == .vertical {
            GeometryReader { geometry in
                let totalHeight = max(geometry.size.height, 1)
                let topHeight = min(max(totalHeight * topRatio, 120), max(120, totalHeight - 140))

                VStack(spacing: 0) {
                    StagingAreaView(state: state)
                        .frame(height: topHeight)
                    SplitDivider(
                        axis: .vertical,
                        onDragChanged: { delta in
                            let base = dragStartSize ?? Double(topHeight)
                            if dragStartSize == nil { dragStartSize = base }
                            let nextHeight = min(max(base + delta, 120), max(120, totalHeight - 140))
                            topRatio = nextHeight / totalHeight
                        },
                        onDragEnded: { dragStartSize = nil }
                    )
                    fileContentPanel
                        .frame(maxHeight: .infinity)
                }
            }
        } else {
            let clampedWidth = min(max(sidebarWidth, 180), max(220, availableWidth - 240))
            HStack(spacing: 0) {
                StagingAreaView(state: state)
                    .frame(width: clampedWidth)
                SplitDivider(
                    axis: .horizontal,
                    onDragChanged: { delta in
                        let base = dragStartSize ?? clampedWidth
                        if dragStartSize == nil { dragStartSize = base }
                        sidebarWidth = min(max(base + delta, 180), max(220, availableWidth - 240))
                    },
                    onDragEnded: { dragStartSize = nil }
                )
                fileContentPanel
                    .frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder
    private var fileContentPanel: some View {
        VStack(spacing: 0) {
            if showingConflict {
                ConflictView(state: state, file: state.selectedFileChange)
            } else {
                HStack {
                    Spacer()

                    Picker("View", selection: $state.changesViewMode) {
                        ForEach(AppState.ChangesViewMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()

                    Spacer()

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
                    .accessibilityLabel("Changes layout")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .onChange(of: blameAvailable) { _, available in
                    if !available && state.changesViewMode == .blame {
                        state.changesViewMode = .diff
                    }
                }
                .onChange(of: state.changesViewMode) { _, mode in
                    if mode == .blame {
                        Task { await state.coordinator.loadBlame() }
                    }
                }

                Divider()

                switch state.changesViewMode {
                case .diff:
                    if state.currentDiffFile != nil {
                        HunkStagingToolbar(state: state)
                        Divider()
                    }
                    DiffView(
                        fileName: state.selectedFileChange?.path,
                        diffLines: state.currentDiffLines,
                        diffFile: state.currentDiffFile,
                        selection: state.currentDiffFile != nil ? $state.selectedLines : nil
                    )
                case .blame:
                    BlameView(fileName: state.selectedFileChange?.path, blameLines: state.currentBlameLines)
                }
            }
        }
    }
}
