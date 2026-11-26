//
//  ToolbarView.swift
//  Maple
//
//  Created by Pool Camacho on 4/13/26.
//

import SwiftUI

struct ToolbarView: View {
    @Bindable var state: AppState
    var availableWidth: CGFloat = 800
    @Binding var showSidebar: Bool
    @Binding var showNewBranch: Bool
    @Binding var showStashSave: Bool
    @Binding var showMerge: Bool
    @Binding var showRebase: Bool
    @State private var showBranchSwitcher = false
    @State private var isHoveringBranch = false

    private var isCompact: Bool { availableWidth < 740 }
    private var isNarrow: Bool { availableWidth < 480 }

    var body: some View {
        HStack(spacing: isCompact ? 8 : 12) {
            if !showSidebar {
                Button(action: { showSidebar = true }) {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 13, weight: .medium))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(HeaderCircleButtonStyle())
                .padding(.leading, 66)
                .help("Show Sidebar")
            }

            HStack(spacing: 10) {
                if let repoName = state.selectedRepository?.name {
                    Text(repoName)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .fixedSize()
                }

                Button {
                    showBranchSwitcher.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.branch")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if !isNarrow {
                            Text(state.selectedRepository?.currentBranch ?? "No branch")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .lineLimit(1)
                                .fixedSize()
                        }
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        isHoveringBranch ? Color.primary.opacity(0.12) : Color.secondary.opacity(0.16),
                        in: RoundedRectangle(cornerRadius: 6)
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .onHover { isHoveringBranch = $0 }
                .disabled(state.operationInProgress)
                .help("Switch branch")
                .popover(isPresented: $showBranchSwitcher, arrowEdge: .bottom) {
                    BranchSwitcherPopover(
                        state: state,
                        isPresented: $showBranchSwitcher,
                        onNewBranch: {
                            showBranchSwitcher = false
                            showNewBranch = true
                        }
                    )
                }
                .fixedSize()
            }
            .fixedSize()

            if !isNarrow {
                Divider()
                    .frame(height: 20)
            }

            HStack(spacing: isCompact ? 2 : 4) {
                actionButtons
            }
            .disabled(state.operationInProgress)

            Spacer(minLength: 8)

            trailingControls
        }
        .padding(.horizontal, 14)
        .frame(height: 36)
        .background(.bar)
    }

    @ViewBuilder
    private var actionButtons: some View {
        if isNarrow {
            ToolbarIconButton(icon: "arrow.down.circle", color: .blue, help: "Pull") {
                Task { await state.coordinator.performPull() }
            }
            ToolbarIconButton(icon: "arrow.up.circle", color: .green, help: "Push") {
                Task { await state.coordinator.performPush() }
            }
        } else if isCompact {
            ToolbarIconButton(icon: "arrow.down.circle", color: .blue, help: "Pull") {
                Task { await state.coordinator.performPull() }
            }
            ToolbarIconButton(icon: "arrow.up.circle", color: .green, help: "Push") {
                Task { await state.coordinator.performPush() }
            }
            ToolbarIconButton(icon: "arrow.down.doc", color: .cyan, help: "Fetch") {
                Task { await state.coordinator.performFetch() }
            }
            ToolbarIconButton(icon: "arrow.uturn.backward.circle", color: .orange, help: "Stash") {
                showStashSave = true
            }

            Divider()
                .frame(height: 18)
                .padding(.horizontal, 2)

            ToolbarIconButton(icon: "plus.circle", color: .teal, help: "Branch") {
                showNewBranch = true
            }
            ToolbarIconButton(icon: "arrow.triangle.merge", color: .purple, help: "Merge") {
                showMerge = true
            }
            ToolbarIconButton(icon: "arrow.triangle.branch", color: .orange, help: "Rebase") {
                showRebase = true
            }
        } else {
            ToolbarActionButton(icon: "arrow.down.circle", label: "Pull", color: .blue) {
                Task { await state.coordinator.performPull() }
            }
            ToolbarActionButton(icon: "arrow.up.circle", label: "Push", color: .green) {
                Task { await state.coordinator.performPush() }
            }
            ToolbarActionButton(icon: "arrow.down.doc", label: "Fetch", color: .cyan) {
                Task { await state.coordinator.performFetch() }
            }
            ToolbarActionButton(icon: "arrow.uturn.backward.circle", label: "Stash", color: .orange) {
                showStashSave = true
            }

            Divider()
                .frame(height: 20)
                .padding(.horizontal, 2)

            ToolbarActionButton(icon: "plus.circle", label: "Branch", color: .teal) {
                showNewBranch = true
            }
            ToolbarActionButton(icon: "arrow.triangle.merge", label: "Merge", color: .purple) {
                showMerge = true
            }
            ToolbarActionButton(icon: "arrow.triangle.branch", label: "Rebase", color: .orange) {
                showRebase = true
            }
        }
    }

    private var trailingControls: some View {
        HStack(spacing: 8) {
            if state.operationInProgress {
                ProgressView()
                    .controlSize(.small)
            }

            if let msg = state.successMessage {
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(.green)
                    .lineLimit(1)
                    .task {
                        try? await Task.sleep(for: .seconds(3))
                        state.successMessage = nil
                    }
            }

            if !isNarrow {
                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Search...", text: $state.searchText)
                        .textFieldStyle(.plain)
                        .frame(width: isCompact ? 100 : 150)
                        .accessibilityIdentifier("toolbar.search")
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
            }
        }
    }
}

struct ToolbarActionButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 1) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.85))
                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 42, height: 32)
        }
        .buttonStyle(ToolbarTileButtonStyle())
        .help(label)
        .accessibilityLabel(label)
        .accessibilityIdentifier("toolbar.\(label.lowercased())")
    }
}

struct ToolbarIconButton: View {
    let icon: String
    let color: Color
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.primary.opacity(0.85))
                .frame(width: 30, height: 28)
        }
        .buttonStyle(ToolbarTileButtonStyle())
        .help(help)
        .accessibilityLabel(help)
        .accessibilityIdentifier("toolbar.\(help.lowercased())")
    }
}

struct HeaderCircleButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isHovering || configuration.isPressed ? .primary : .secondary)
            .background(
                backgroundColor(isPressed: configuration.isPressed),
                in: Circle()
            )
            .contentShape(Circle())
            .scaleEffect(configuration.isPressed && isEnabled ? 0.94 : 1.0)
            .opacity(isEnabled ? 1.0 : 0.45)
            .animation(.easeOut(duration: 0.12), value: isHovering)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
            .onHover { isHovering = $0 }
            .focusEffectDisabled()
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        guard isEnabled else { return .clear }
        if isPressed { return Color.primary.opacity(0.16) }
        if isHovering { return Color.primary.opacity(0.10) }
        return .clear
    }
}

struct ToolbarTileButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                backgroundColor(isPressed: configuration.isPressed),
                in: RoundedRectangle(cornerRadius: 7)
            )
            .contentShape(RoundedRectangle(cornerRadius: 7))
            .scaleEffect(configuration.isPressed && isEnabled ? 0.95 : 1.0)
            .opacity(isEnabled ? 1.0 : 0.45)
            .animation(.easeOut(duration: 0.12), value: isHovering)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
            .onHover { hovering in
                isHovering = hovering
            }
            .focusEffectDisabled()
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        guard isEnabled else { return .clear }
        if isPressed { return Color.primary.opacity(0.15) }
        if isHovering { return Color.primary.opacity(0.08) }
        return .clear
    }
}

private struct BranchSwitcherPopover: View {
    @Bindable var state: AppState
    @Binding var isPresented: Bool
    let onNewBranch: () -> Void
    @State private var query = ""

    private var filteredLocal: [GitBranch] {
        filterBranches(state.branches.filter { !$0.isRemote })
    }

    private var filteredRemote: [GitBranch] {
        filterBranches(state.branches.filter { $0.isRemote && !$0.name.hasSuffix("/HEAD") })
    }

    private func filterBranches(_ branches: [GitBranch]) -> [GitBranch] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return branches }
        return branches.filter { $0.name.localizedStandardContains(trimmed) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Switch branch…", text: $query)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)

            Divider()

            ScrollView(.vertical) {
                LazyVStack(alignment: .leading, spacing: 2) {
                    if !filteredLocal.isEmpty {
                        sectionHeader("Local")
                        ForEach(filteredLocal) { branch in
                            BranchOptionRow(
                                name: branch.name,
                                systemImage: "arrow.triangle.branch",
                                isCurrent: branch.isCurrent
                            ) {
                                isPresented = false
                                if !branch.isCurrent {
                                    Task { await state.coordinator.checkoutBranch(branch) }
                                }
                            }
                        }
                    }

                    if !filteredRemote.isEmpty {
                        sectionHeader("Remote (creates local branch)")
                            .padding(.top, filteredLocal.isEmpty ? 0 : 6)
                        ForEach(filteredRemote) { branch in
                            BranchOptionRow(
                                name: branch.name,
                                systemImage: "globe",
                                isCurrent: false
                            ) {
                                isPresented = false
                                Task { await state.coordinator.checkoutBranch(branch) }
                            }
                        }
                    }

                    if filteredLocal.isEmpty && filteredRemote.isEmpty {
                        Text("No matching branches")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 16)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(6)
            }
            .frame(maxHeight: 280)

            Divider()

            Button(action: onNewBranch) {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle")
                    Text("New Branch…")
                    Spacer()
                }
                .font(.callout)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .frame(width: 280)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.top, 4)
            .padding(.bottom, 2)
    }
}

private struct BranchOptionRow: View {
    let name: String
    let systemImage: String
    let isCurrent: Bool
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 14)

                Text(name)
                    .font(.callout)
                    .fontWeight(isCurrent ? .semibold : .regular)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                if isCurrent {
                    Image(systemName: "checkmark")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                isHovering ? Color.primary.opacity(0.08) : .clear,
                in: RoundedRectangle(cornerRadius: 6)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}

#Preview("Full") {
    ToolbarView(
        state: AppState(),
        availableWidth: 800,
        showSidebar: .constant(true),
        showNewBranch: .constant(false),
        showStashSave: .constant(false),
        showMerge: .constant(false),
        showRebase: .constant(false)
    )
    .frame(width: 800)
}
