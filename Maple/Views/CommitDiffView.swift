//
//  CommitDiffView.swift
//  Maple
//
//  Created by Maple on 11/25/26.
//

import SwiftUI

struct CommitDiffView: View {
    let commit: GitCommit?
    let files: [DiffFile]

    @State private var collapsedFileIDs: Set<UUID> = []

    private var allCollapsed: Bool {
        !files.isEmpty && files.allSatisfy { collapsedFileIDs.contains($0.id) }
    }

    private var totalAdditions: Int {
        files.reduce(0) { $0 + countLines(in: $1, ofType: .addition) }
    }

    private var totalDeletions: Int {
        files.reduce(0) { $0 + countLines(in: $1, ofType: .deletion) }
    }

    var body: some View {
        VStack(spacing: 0) {
            if let commit {
                headerBar(commit: commit)
                Divider()
            }

            if files.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text")
                        .font(.title2)
                        .foregroundStyle(.tertiary)
                    Text("No file changes in this commit")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical) {
                    LazyVStack(spacing: 0) {
                        ForEach(files) { file in
                            CommitFileSection(
                                file: file,
                                isCollapsed: collapsedFileIDs.contains(file.id),
                                additions: countLines(in: file, ofType: .addition),
                                deletions: countLines(in: file, ofType: .deletion),
                                onToggle: { toggleFile(file.id) }
                            )
                        }
                    }
                }
            }
        }
        .onChange(of: commit?.id) {
            collapsedFileIDs = []
        }
    }

    @ViewBuilder
    private func headerBar(commit: GitCommit) -> some View {
        HStack(spacing: 8) {
            Button {
                if allCollapsed {
                    collapsedFileIDs = []
                } else {
                    collapsedFileIDs = Set(files.map(\.id))
                }
            } label: {
                Label(
                    allCollapsed ? "Expand all" : "Collapse all",
                    systemImage: allCollapsed ? "chevron.right" : "chevron.down"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            Divider()
                .frame(height: 14)

            Text(commit.shortID)
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            Text(commit.message)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer()

            Text("\(files.count) \(files.count == 1 ? "file" : "files")")
                .font(.caption)
                .foregroundStyle(.secondary)

            DiffStatBadges(additions: totalAdditions, deletions: totalDeletions)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.bar)
    }

    private func toggleFile(_ id: UUID) {
        if collapsedFileIDs.contains(id) {
            collapsedFileIDs.remove(id)
        } else {
            collapsedFileIDs.insert(id)
        }
    }

    private func countLines(in file: DiffFile, ofType type: DiffLine.LineType) -> Int {
        file.hunks.reduce(0) { running, hunk in
            running + hunk.lines.reduce(0) { $1.type == type ? $0 + 1 : $0 }
        }
    }
}

private struct CommitFileSection: View {
    let file: DiffFile
    let isCollapsed: Bool
    let additions: Int
    let deletions: Int
    let onToggle: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onToggle) {
                HStack(spacing: 8) {
                    Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 12)

                    Image(systemName: file.isBinary ? "doc.badge.gearshape" : "doc.text")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)

                    Text(file.path ?? "Unknown file")
                        .font(.system(.callout, design: .monospaced))
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    if file.isBinary {
                        Text("Binary")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
                    } else {
                        DiffStatBadges(additions: additions, deletions: deletions)
                    }

                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.accentColor.opacity(0.08))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Divider()

            if !isCollapsed {
                if file.isBinary {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.badge.gearshape")
                            .foregroundStyle(.tertiary)
                        Text("Binary file changed (no text diff)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    Divider()
                } else {
                    ForEach(Array(file.hunks.enumerated()), id: \.offset) { _, hunk in
                        DiffLineView(line: DiffLine(
                            content: hunk.header,
                            type: .header,
                            oldLineNumber: nil,
                            newLineNumber: nil
                        ))
                        ForEach(Array(hunk.lines.enumerated()), id: \.offset) { _, line in
                            DiffLineView(line: line)
                        }
                    }
                    Divider()
                }
            }
        }
    }
}

private struct DiffStatBadges: View {
    let additions: Int
    let deletions: Int

    var body: some View {
        HStack(spacing: 4) {
            if deletions > 0 {
                Text("-\(deletions)")
                    .font(.system(.caption2, design: .monospaced))
                    .fontWeight(.semibold)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.red.opacity(0.14), in: RoundedRectangle(cornerRadius: 4))
            }
            if additions > 0 {
                Text("+\(additions)")
                    .font(.system(.caption2, design: .monospaced))
                    .fontWeight(.semibold)
                    .foregroundStyle(.green)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.14), in: RoundedRectangle(cornerRadius: 4))
            }
        }
    }
}
