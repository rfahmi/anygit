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

    private var hasSelection: Bool {
        state.selectedCommit != nil && !state.commitDiffFiles.isEmpty
    }

    var body: some View {
        GeometryReader { geometry in
            if layout == .horizontal {
                let historyWidth = hasSelection ? geometry.size.width * 0.55 : geometry.size.width

                HStack(spacing: 0) {
                    CommitHistoryView(state: state, availableWidth: historyWidth, layout: $layout)
                        .frame(width: max(0, historyWidth))
                        .clipped()

                    if hasSelection {
                        Divider()

                        CommitDiffView(
                            commit: state.selectedCommit,
                            files: state.commitDiffFiles
                        )
                        .frame(width: max(0, geometry.size.width * 0.45 - 1))
                        .clipped()
                    }
                }
            } else {
                VStack(spacing: 0) {
                    CommitHistoryView(state: state, availableWidth: availableWidth, layout: $layout)
                        .frame(height: hasSelection ? max(0, geometry.size.height * 0.55) : geometry.size.height)
                        .clipped()

                    if hasSelection {
                        Divider()

                        CommitDiffView(
                            commit: state.selectedCommit,
                            files: state.commitDiffFiles
                        )
                        .frame(height: max(0, geometry.size.height * 0.45 - 1))
                        .clipped()
                    }
                }
            }
        }
    }
}
