//
//  StagingAreaView.swift
//  Maple
//
//  Created by Pool Camacho on 4/13/26.
//

import SwiftUI
import AppKit

struct StagingAreaView: View {
    @Bindable var state: AppState
    @State private var commitMessage: String = ""
    @State private var amendMode: Bool = false
    @State private var isGeneratingMessage: Bool = false
    @State private var activeSection: String = "unstaged"
    @AppStorage("unstagedSplitRatio") private var splitRatio: Double = 0.5
    @State private var dragStartRatio: Double?
    @State private var isUnstagedCollapsed: Bool = false
    @State private var isStagedCollapsed: Bool = false

    private var stagedFiles: [GitFileChange] {
        state.filteredFileChanges.filter { $0.isStaged }
    }

    private var unstagedFiles: [GitFileChange] {
        state.filteredFileChanges.filter { !$0.isStaged }
    }

    var body: some View {
        VStack(spacing: 0) {
            if state.fileChanges.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .font(.title)
                        .foregroundStyle(.green)
                    Text("Working tree clean")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                GeometryReader { geometry in
                    let totalHeight = geometry.size.height
                    let dividerHeight: CGFloat = 7
                    let bothExpanded = !isUnstagedCollapsed && !isStagedCollapsed
                    let usableHeight = max(120, totalHeight - dividerHeight)
                    let unstagedHeight = min(max(60, usableHeight * splitRatio), usableHeight - 60)
                    let stagedHeight = max(60, usableHeight - unstagedHeight)

                    VStack(spacing: 0) {
                        FileChangeSection(
                            title: "Unstaged Changes",
                            count: unstagedFiles.count,
                            files: unstagedFiles,
                            selectedFile: $state.selectedFileChange,
                            sectionID: "unstaged",
                            activeSection: $activeSection,
                            isCollapsed: $isUnstagedCollapsed,
                            actionIcon: "plus.circle.fill",
                            actionColor: .green,
                            onAction: { file in Task { await state.coordinator.stageFile(file) } },
                            bulkActionLabel: "Stage All",
                            onBulkAction: { Task { await state.coordinator.stageAllFiles() } }
                        )
                        .frame(height: bothExpanded ? unstagedHeight : nil)
                        .frame(maxHeight: (!isUnstagedCollapsed && isStagedCollapsed) ? .infinity : nil)

                        if bothExpanded {
                            SplitResizeHandle(
                                onDragChanged: { translationY in
                                    let start = dragStartRatio ?? splitRatio
                                    if dragStartRatio == nil {
                                        dragStartRatio = start
                                    }
                                    let delta = Double(translationY / max(1, usableHeight))
                                    splitRatio = min(max(start + delta, 0.15), 0.85)
                                },
                                onDragEnded: {
                                    dragStartRatio = nil
                                },
                                onDoubleClick: {
                                    splitRatio = 0.5
                                }
                            )
                            .frame(height: dividerHeight)
                        } else {
                            Divider()
                        }

                        FileChangeSection(
                            title: "Staged Changes",
                            count: stagedFiles.count,
                            files: stagedFiles,
                            selectedFile: $state.selectedFileChange,
                            sectionID: "staged",
                            activeSection: $activeSection,
                            isCollapsed: $isStagedCollapsed,
                            actionIcon: "minus.circle.fill",
                            actionColor: .red,
                            onAction: { file in Task { await state.coordinator.unstageFile(file) } },
                            bulkActionLabel: "Unstage All",
                            onBulkAction: { Task { await state.coordinator.unstageAllFiles() } }
                        )
                        .frame(height: bothExpanded ? stagedHeight : nil)
                        .frame(maxHeight: (isUnstagedCollapsed && !isStagedCollapsed) ? .infinity : nil)

                        if isUnstagedCollapsed && isStagedCollapsed {
                            Spacer(minLength: 0)
                        }
                    }
                }
                .frame(maxHeight: .infinity)

                Divider()

                VStack(spacing: 8) {
                    TextEditor(text: $commitMessage)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 40, idealHeight: 60, maxHeight: 100)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            Group {
                                if commitMessage.isEmpty {
                                    Text("Commit message...")
                                        .foregroundStyle(.tertiary)
                                        .padding(.leading, 12)
                                        .padding(.top, 16)
                                }
                            },
                            alignment: .topLeading
                        )

                    HStack {
                        Toggle("Amend", isOn: $amendMode)
                            .toggleStyle(.checkbox)
                            .font(.caption)

                        Spacer()

                        Button {
                            isGeneratingMessage = true
                            Task {
                                if let generated = await state.coordinator.generateCommitMessage() {
                                    commitMessage = generated
                                }
                                isGeneratingMessage = false
                            }
                        } label: {
                            if isGeneratingMessage {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "sparkles")
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .help("Generate commit message with Apple Intelligence")
                        .accessibilityLabel("Generate commit message")
                        .disabled(stagedFiles.isEmpty || state.operationInProgress || isGeneratingMessage)

                        Button(action: {
                            let msg = commitMessage
                            let amend = amendMode
                            Task {
                                let ok = await state.coordinator.performCommit(message: msg, amend: amend)
                                if ok {
                                    commitMessage = ""
                                    amendMode = false
                                }
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Commit")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .keyboardShortcut(.return, modifiers: .command)
                        .disabled(
                            (stagedFiles.isEmpty && !amendMode)
                            || commitMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || state.operationInProgress
                        )
                    }
                }
                .padding(10)
            }
        }
    }
}

struct FileChangeSection: View {
    let title: String
    let count: Int
    let files: [GitFileChange]
    @Binding var selectedFile: GitFileChange?
    let sectionID: String
    @Binding var activeSection: String
    @Binding var isCollapsed: Bool
    let actionIcon: String
    let actionColor: Color
    let onAction: (GitFileChange) -> Void
    let bulkActionLabel: String
    let onBulkAction: () -> Void

    // Only show selection if this section is active
    private var sectionSelection: Binding<GitFileChange?> {
        Binding(
            get: { activeSection == sectionID ? selectedFile : nil },
            set: { newValue in
                if let newValue {
                    activeSection = sectionID
                    selectedFile = newValue
                }
            }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Button {
                    isCollapsed.toggle()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 10)

                        Text(title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .lineLimit(1)

                        Text("\(count)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(.quaternary, in: Capsule())
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer()

                if !files.isEmpty {
                    Button(bulkActionLabel) {
                        onBulkAction()
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.blue)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)

            if !isCollapsed {
                List(selection: sectionSelection) {
                    ForEach(files) { file in
                        FileChangeRow(file: file, actionIcon: actionIcon, actionColor: actionColor) {
                            onAction(file)
                        }
                        .tag(file)
                        .listRowInsets(EdgeInsets(top: 2, leading: 6, bottom: 2, trailing: 6))
                    }
                }
                .listStyle(.plain)
                .frame(minHeight: 30)
            }
        }
    }
}

private struct SplitResizeHandle: View {
    let onDragChanged: (CGFloat) -> Void
    let onDragEnded: () -> Void
    let onDoubleClick: () -> Void

    @State private var isHovering = false

    var body: some View {
        ZStack {
            Divider()
            RoundedRectangle(cornerRadius: 1.5)
                .fill(isHovering ? Color.secondary.opacity(0.6) : Color.secondary.opacity(0.25))
                .frame(width: 28, height: 3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
            if hovering {
                NSCursor.resizeUpDown.push()
            } else {
                NSCursor.pop()
            }
        }
        .onTapGesture(count: 2) {
            onDoubleClick()
        }
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { value in
                    onDragChanged(value.translation.height)
                }
                .onEnded { _ in
                    onDragEnded()
                }
        )
    }
}

struct FileChangeRow: View {
    let file: GitFileChange
    let actionIcon: String
    let actionColor: Color
    let onAction: () -> Void

    private var statusColor: Color {
        switch file.status {
        case .modified: return .orange
        case .added: return .green
        case .deleted: return .red
        case .renamed: return .blue
        case .untracked: return .gray
        case .conflicted: return .purple
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Text(file.status.rawValue)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(statusColor)
                .frame(width: 14)

            Text(file.path)
                .font(.system(.caption, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.head)

            Spacer(minLength: 4)

            Button(action: onAction) {
                Image(systemName: actionIcon)
                    .foregroundStyle(actionColor)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(file.isStaged ? "Unstage \(file.path)" : "Stage \(file.path)")
            .accessibilityIdentifier(file.isStaged ? "staging.unstage" : "staging.stage")
        }
        .contentShape(Rectangle())
    }
}

#Preview {
    StagingAreaView(state: AppState())
        .frame(width: 350, height: 600)
}
