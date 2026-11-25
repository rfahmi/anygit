//
//  CommitHistoryView.swift
//  Maple
//
//  Created by Pool Camacho on 4/13/26.
//

import SwiftUI

struct CommitHistoryView: View {
    @Bindable var state: AppState
    var availableWidth: CGFloat = 800
    @Binding var layout: SplitLayout

    @State private var branchTargetCommit: GitCommit?
    @State private var resetTargetCommit: GitCommit?

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

    var body: some View {
        // Build the graph layout once per render (it was previously rebuilt two
        // to three times: for the header width, the column header, and each row).
        let commits = visibleCommits
        let currentLayout = CommitGraphBuilder.build(from: commits)
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

            List(selection: $state.selectedCommit) {
                ForEach(Array(commits.enumerated()), id: \.element.id) { index, commit in
                    CommitRow(
                        commit: commit,
                        rowIndex: index,
                        commits: commits,
                        unpushedCommitIDs: state.unpushedCommitIDs,
                        layout: currentLayout,
                        graphWidth: graphW,
                        laneWidth: laneWidth,
                        rowHeight: rowHeight,
                        showAuthor: showAuthor,
                        showDate: showDate,
                        showSHA: showSHA
                    )
                    .tag(commit)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .contextMenu {
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
            .listStyle(.plain)
        }
        .sheet(item: $branchTargetCommit) { commit in
            NewBranchDialog(state: state, startPoint: commit)
        }
        .sheet(item: $resetTargetCommit) { commit in
            ResetToCommitDialog(state: state, commit: commit)
        }
    }
}

struct CommitRow: View {
    let commit: GitCommit
    let rowIndex: Int
    let commits: [GitCommit]
    let unpushedCommitIDs: Set<String>
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
                ForEach(mergedBadges, id: \.label) { badge in
                    BranchTag(name: badge.label, isSyncedWithOrigin: badge.isSynced, color: branchColor)
                }
                Text(commit.message)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

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
        .padding(.trailing, 12)
        .frame(height: rowHeight)
        .contentShape(Rectangle())
    }
}

struct CommitGraphRowCanvas: View {
    let rowIndex: Int
    let commits: [GitCommit]
    let unpushedCommitIDs: Set<String>
    let layout: CommitGraphLayout
    let laneWidth: CGFloat
    let rowHeight: CGFloat

    private let edgeWidth: CGFloat = 2.0
    private let nodeDiameter: CGFloat = 9
    private let mergeInnerDiameter: CGFloat = 5
    private let mergeOuterDiameter: CGFloat = 13
    private let mergeRingWidth: CGFloat = 2.0
    private let laneOffset: CGFloat = 12

    var body: some View {
        Canvas { context, _ in
            func xFor(lane: Int) -> CGFloat {
                laneOffset + CGFloat(lane) * laneWidth + laneWidth / 2
            }

            for edge in layout.edges {
                guard edge.fromRow <= rowIndex, rowIndex <= edge.toRow else { continue }

                let fromX = xFor(lane: edge.fromLane)
                let toX = xFor(lane: edge.toLane)
                let color = CommitGraphColors.color(forLane: edge.toLane)
                let path = edgePath(from: fromX, to: toX, edgeFromRow: edge.fromRow, edgeToRow: edge.toRow)
                let isUnpushedEdge = edge.fromRow >= 0
                    && edge.fromRow < commits.count
                    && unpushedCommitIDs.contains(commits[edge.fromRow].id)

                let style = isUnpushedEdge
                    ? StrokeStyle(lineWidth: edgeWidth, lineCap: .round, dash: [2.5, 3.5])
                    : StrokeStyle(lineWidth: edgeWidth, lineCap: .round)

                context.stroke(path, with: .color(color), style: style)
            }

            if let node = layout.node(atRow: rowIndex) {
                drawNode(node, in: context, xFor: xFor)
            }
        }
    }

    /// Returns the slice of the edge that lives in the current row. Lane transitions
    /// happen entirely inside the child row (the `fromRow` end) so branches visibly
    /// originate from the source commit rather than drifting across multiple rows.
    private func edgePath(from fromX: CGFloat, to toX: CGFloat, edgeFromRow: Int, edgeToRow: Int) -> Path {
        var path = Path()

        if edgeFromRow == rowIndex && edgeToRow == rowIndex {
            path.move(to: CGPoint(x: fromX, y: rowHeight / 2))
            path.addLine(to: CGPoint(x: toX, y: rowHeight / 2))
        } else if edgeFromRow == rowIndex {
            path.move(to: CGPoint(x: fromX, y: rowHeight / 2))
            if fromX == toX {
                path.addLine(to: CGPoint(x: toX, y: rowHeight))
            } else {
                // Smoother S: stay at source-x longer then sweep into target-x near the bottom
                path.addCurve(
                    to: CGPoint(x: toX, y: rowHeight),
                    control1: CGPoint(x: fromX, y: rowHeight * 0.75),
                    control2: CGPoint(x: toX, y: rowHeight * 0.80)
                )
            }
        } else if edgeToRow == rowIndex {
            path.move(to: CGPoint(x: toX, y: 0))
            path.addLine(to: CGPoint(x: toX, y: rowHeight / 2))
        } else {
            path.move(to: CGPoint(x: toX, y: 0))
            path.addLine(to: CGPoint(x: toX, y: rowHeight))
        }

        return path
    }

    /// Regular commit: filled dot. Merge: hollow ring with a small inner dot, so joins
    /// stay readable over vertical lane lines that cross behind them.
    private func drawNode(_ node: CommitGraphLayout.Node, in context: GraphicsContext, xFor: (Int) -> CGFloat) {
        let x = xFor(node.lane)
        let y = rowHeight / 2
        let color = CommitGraphColors.color(forLane: node.lane)

        if node.isMerge {
            let outerRect = CGRect(
                x: x - mergeOuterDiameter / 2,
                y: y - mergeOuterDiameter / 2,
                width: mergeOuterDiameter,
                height: mergeOuterDiameter
            )
            context.stroke(
                Path(ellipseIn: outerRect),
                with: .color(color),
                lineWidth: mergeRingWidth
            )

            let innerRect = CGRect(
                x: x - mergeInnerDiameter / 2,
                y: y - mergeInnerDiameter / 2,
                width: mergeInnerDiameter,
                height: mergeInnerDiameter
            )
            context.fill(Path(ellipseIn: innerRect), with: .color(color))
        } else {
            let rect = CGRect(
                x: x - nodeDiameter / 2,
                y: y - nodeDiameter / 2,
                width: nodeDiameter,
                height: nodeDiameter
            )
            context.fill(Path(ellipseIn: rect), with: .color(color))
        }
    }
}

struct BranchTag: View {
    let name: String
    var isSyncedWithOrigin: Bool = false
    let color: Color

    var body: some View {
        HStack(spacing: 3) {
            if isSyncedWithOrigin {
                Image(systemName: "cloud.fill")
                    .font(.system(size: 8))
            }
            Text(name)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .lineLimit(1)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
        .foregroundStyle(color)
        .help(isSyncedWithOrigin ? "Synced with origin/\(name)" : name)
    }
}

#Preview {
    CommitHistoryView(state: AppState(), availableWidth: 800)
        .frame(width: 800, height: 400)
}
