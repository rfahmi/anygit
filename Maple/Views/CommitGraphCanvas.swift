//
//  CommitGraphCanvas.swift
//  Maple
//
//  Created by Pool Camacho on 4/13/26.
//

import SwiftUI

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
                let isWorkingTreeEdge = edge.fromRow >= 0
                    && edge.fromRow < commits.count
                    && commits[edge.fromRow].id == CommitGraphBuilder.workingTreeNodeID
                let isUnpushedEdge = edge.fromRow >= 0
                    && edge.fromRow < commits.count
                    && unpushedCommitIDs.contains(commits[edge.fromRow].id)

                let style = (isUnpushedEdge || isWorkingTreeEdge)
                    ? StrokeStyle(lineWidth: edgeWidth, lineCap: .round, dash: [0.01, 5.0])
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
            let isWorkingTreeNode = rowIndex >= 0
                && rowIndex < commits.count
                && commits[rowIndex].id == CommitGraphBuilder.workingTreeNodeID
            let isUnpushedNode = rowIndex >= 0
                && rowIndex < commits.count
                && unpushedCommitIDs.contains(commits[rowIndex].id)
            if isWorkingTreeNode {
                let square = RoundedRectangle(cornerRadius: 2)
                context.fill(square.path(in: rect), with: .color(color))
            } else if isUnpushedNode {
                var clearContext = context
                clearContext.blendMode = .clear
                clearContext.fill(Path(ellipseIn: rect), with: .color(.black))
                context.stroke(Path(ellipseIn: rect), with: .color(color), lineWidth: 2.0)
            } else {
                context.fill(Path(ellipseIn: rect), with: .color(color))
            }
        }
    }
}

struct BranchTag: View {
    let name: String
    var isSyncedWithOrigin: Bool = false
    var isCurrent: Bool = false
    var isLocalOnly: Bool = false
    let color: Color

    private var helpText: String {
        if isCurrent {
            return isLocalOnly
                ? "Current branch (\(name)) — local only, not published to remote"
                : "Current branch (\(name))"
        }
        if isLocalOnly {
            return "\(name) — local only, not published to remote"
        }
        return isSyncedWithOrigin ? "Synced with origin/\(name)" : name
    }

    var body: some View {
        HStack(spacing: 3) {
            if isCurrent {
                Image(systemName: "arrowtriangle.right.fill")
                    .font(.system(size: 7))
            }
            if isLocalOnly {
                Image(systemName: "icloud.slash")
                    .font(.system(size: 8))
            } else if isSyncedWithOrigin && !isCurrent {
                Image(systemName: "cloud.fill")
                    .font(.system(size: 8))
            }
            Text(name)
                .font(.system(size: 10, weight: isCurrent ? .bold : .medium, design: .monospaced))
                .lineLimit(1)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(isCurrent ? color : color.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
        .foregroundStyle(isCurrent ? .white : color)
        .help(helpText)
    }
}
