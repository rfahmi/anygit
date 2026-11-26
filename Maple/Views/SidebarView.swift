//
//  SidebarView.swift
//  Maple
//
//  Created by Pool Camacho on 4/13/26.
//

import SwiftUI

struct SidebarView: View {
    @Bindable var state: AppState
    @Binding var showClone: Bool
    var onToggleSidebar: (() -> Void)?
    @State private var isHoveringAddMenu = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                if let onToggleSidebar {
                    Button(action: onToggleSidebar) {
                        Image(systemName: "sidebar.left")
                            .font(.system(size: 13, weight: .medium))
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(HeaderCircleButtonStyle())
                    .help("Hide Sidebar")
                }

                Menu {
                    Button {
                        openFolderPicker(state: state)
                    } label: {
                        Label("Open Repository...", systemImage: "folder")
                    }
                    Button {
                        showClone = true
                    } label: {
                        Label("Clone Repository...", systemImage: "square.and.arrow.down")
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(isHoveringAddMenu ? .primary : .secondary)
                        .frame(width: 28, height: 28)
                        .background(
                            isHoveringAddMenu ? Color.primary.opacity(0.10) : .clear,
                            in: Circle()
                        )
                        .contentShape(Circle())
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .animation(.easeOut(duration: 0.12), value: isHoveringAddMenu)
                .onHover { isHoveringAddMenu = $0 }
                .focusEffectDisabled()
                .help("Add Repository")
                .accessibilityLabel("Add Repository")
                .accessibilityIdentifier("sidebar.addRepository")

                Button(action: {
                    Task { await state.coordinator.refresh() }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13, weight: .medium))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(HeaderCircleButtonStyle())
                .help("Refresh")
                .accessibilityLabel("Refresh")
                .accessibilityIdentifier("sidebar.refresh")

                Spacer()
            }
            .padding(.leading, 76)
            .padding(.trailing, 8)
            .frame(height: 36)
            .background(.bar)

            Divider()

            List(selection: $state.selectedRepository) {
            Section("Repositories") {
                ForEach(state.repositories) { repo in
                    SidebarRepoRow(repository: repo) {
                        state.coordinator.removeRepository(repo)
                    }
                    .tag(repo)
                }

                if state.repositories.isEmpty {
                    Text("No repositories")
                        .foregroundStyle(.tertiary)
                        .font(.caption)
                }
            }

            if !state.branches.isEmpty {
                Section("Branches") {
                    ForEach(state.branches.filter { !$0.isRemote }) { branch in
                        Label {
                            Text(branch.name)
                                .fontWeight(branch.isCurrent ? .semibold : .regular)
                                .lineLimit(1)
                        } icon: {
                            Image(systemName: branch.isCurrent ? "arrow.triangle.branch" : "line.diagonal")
                                .foregroundStyle(branch.isCurrent ? .green : .secondary)
                        }
                    }
                }

                Section("Remotes") {
                    ForEach(state.branches.filter { $0.isRemote }) { branch in
                        Label {
                            Text(branch.name)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        } icon: {
                            Image(systemName: "cloud")
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        }
    }
}

struct SidebarRepoRow: View {
    let repository: GitRepository
    var onRemove: (() -> Void)?
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "folder.fill")
                .foregroundStyle(.orange)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text(repository.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.caption2)
                    Text(repository.currentBranch)
                        .font(.caption)
                        .lineLimit(1)
                }
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 4)

            if isHovering, let onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 18, height: 18)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .focusEffectDisabled()
                .help("Remove Repository")
                .accessibilityLabel("Remove \(repository.name)")
            }

            Menu {
                OpenInMenuItems(repositoryPath: repository.path)
            } label: {
                Image(systemName: "arrow.up.forward.app")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .tint(.secondary)
            .fixedSize()
            .help("Open in IDE or App")
            .accessibilityLabel("Open \(repository.name) in IDE")
        }
        .padding(.vertical, 2)
        .onHover { isHovering = $0 }
        .contextMenu {
            Menu("Open in") {
                OpenInMenuItems(repositoryPath: repository.path)
            }
            if let onRemove {
                Divider()
                Button("Remove Repository", role: .destructive, action: onRemove)
            }
        }
    }
}

private struct OpenInMenuItems: View {
    let repositoryPath: String

    var body: some View {
        let editors = RepoOpener.installedEditors()
        let terminals = RepoOpener.installedTerminals()

        ForEach(editors) { app in
            Button {
                RepoOpener.openRepository(at: repositoryPath, with: app.url)
            } label: {
                Label(app.name, systemImage: app.systemImage)
            }
        }

        if !editors.isEmpty && !terminals.isEmpty {
            Divider()
        }

        ForEach(terminals) { app in
            Button {
                RepoOpener.openRepository(at: repositoryPath, with: app.url)
            } label: {
                Label(app.name, systemImage: app.systemImage)
            }
        }

        Divider()

        Button {
            RepoOpener.revealInFinder(path: repositoryPath)
        } label: {
            Label("Finder", systemImage: "folder")
        }

        Button {
            RepoOpener.chooseOtherAppAndOpen(repositoryPath: repositoryPath)
        } label: {
            Label("Other App…", systemImage: "ellipsis.circle")
        }
    }
}

#Preview {
    SidebarView(state: AppState(), showClone: .constant(false))
        .frame(width: 250, height: 500)
}
