//
//  HistoryTabView.swift
//  Maple
//
//  Created by Pool Camacho on 4/13/26.
//

import SwiftUI

enum SplitLayout: String, CaseIterable {
    case vertical
    case horizontal

    var systemImage: String {
        switch self {
        case .vertical: return "rectangle.split.1x2"
        case .horizontal: return "rectangle.split.2x1"
        }
    }

    var helpText: String {
        switch self {
        case .vertical: return "Vertical layout (top / bottom)"
        case .horizontal: return "Horizontal layout (side by side)"
        }
    }
}

struct HistoryTabView: View {
    @Bindable var state: AppState
    let availableWidth: CGFloat
    @AppStorage("historyLayout") private var layout: SplitLayout = .vertical
    @AppStorage("historyHorizontalRatio") private var horizontalRatio: Double = 0.55
    @AppStorage("historyVerticalRatio") private var verticalRatio: Double = 0.55
    @State private var dragStartRatio: Double?

    private var hasSelection: Bool {
        state.selectedCommit != nil && !state.commitDiffFiles.isEmpty
    }

    var body: some View {
        GeometryReader { geometry in
            if layout == .horizontal {
                let totalWidth = max(geometry.size.width, 1)
                let historyWidth = hasSelection ? totalWidth * horizontalRatio : totalWidth
                let diffWidth = max(0, totalWidth - historyWidth - 7)

                HStack(spacing: 0) {
                    CommitHistoryView(state: state, availableWidth: historyWidth, layout: $layout)
                        .frame(width: max(0, historyWidth))
                        .clipped()

                    if hasSelection {
                        SplitDivider(
                            axis: .horizontal,
                            onDragChanged: { delta in
                                let base = dragStartRatio ?? horizontalRatio
                                if dragStartRatio == nil { dragStartRatio = base }
                                horizontalRatio = min(max(base + delta / totalWidth, 0.25), 0.75)
                            },
                            onDragEnded: { dragStartRatio = nil }
                        )

                        CommitDiffView(
                            commit: state.selectedCommit,
                            files: state.commitDiffFiles
                        )
                        .frame(width: diffWidth)
                        .clipped()
                    }
                }
            } else {
                let totalHeight = max(geometry.size.height, 1)
                let historyHeight = hasSelection ? totalHeight * verticalRatio : totalHeight
                let diffHeight = max(0, totalHeight - historyHeight - 7)

                VStack(spacing: 0) {
                    CommitHistoryView(state: state, availableWidth: availableWidth, layout: $layout)
                        .frame(height: max(0, historyHeight))
                        .clipped()

                    if hasSelection {
                        SplitDivider(
                            axis: .vertical,
                            onDragChanged: { delta in
                                let base = dragStartRatio ?? verticalRatio
                                if dragStartRatio == nil { dragStartRatio = base }
                                verticalRatio = min(max(base + delta / totalHeight, 0.25), 0.75)
                            },
                            onDragEnded: { dragStartRatio = nil }
                        )

                        CommitDiffView(
                            commit: state.selectedCommit,
                            files: state.commitDiffFiles
                        )
                        .frame(height: diffHeight)
                        .clipped()
                    }
                }
            }
        }
    }
}
