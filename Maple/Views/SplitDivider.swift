//
//  SplitDivider.swift
//  Maple
//
//  Created by Nur Fahmi on 11/26/26.
//

import AppKit
import SwiftUI

/// Draggable 1pt divider for resizing adjacent split panes.
struct SplitDivider: View {
    enum Axis {
        /// Vertical hairline separating left and right panes.
        case horizontal
        /// Horizontal hairline separating top and bottom panes.
        case vertical
    }

    let axis: Axis
    let onDragChanged: (CGFloat) -> Void
    var onDragEnded: () -> Void = {}

    @State private var isHovering = false
    @State private var isDragging = false

    private var cursor: NSCursor {
        axis == .horizontal ? .resizeLeftRight : .resizeUpDown
    }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(isHovering || isDragging ? Color.accentColor.opacity(0.6) : Color(nsColor: .separatorColor))
                .frame(
                    width: axis == .horizontal ? 1 : nil,
                    height: axis == .vertical ? 1 : nil
                )
        }
        .frame(
            width: axis == .horizontal ? 7 : nil,
            height: axis == .vertical ? 7 : nil
        )
        .frame(
            maxWidth: axis == .vertical ? .infinity : nil,
            maxHeight: axis == .horizontal ? .infinity : nil
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
            if hovering {
                cursor.push()
            } else {
                NSCursor.pop()
            }
        }
        .gesture(
            DragGesture(minimumDistance: 1, coordinateSpace: .global)
                .onChanged { value in
                    isDragging = true
                    let delta = axis == .horizontal ? value.translation.width : value.translation.height
                    onDragChanged(delta)
                }
                .onEnded { _ in
                    isDragging = false
                    onDragEnded()
                }
        )
    }
}
