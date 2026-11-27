//
//  CommitGraphBuilder.swift
//  Maple
//
//  Created by Pool Camacho on 4/13/26.
//

import Foundation

nonisolated struct CommitGraphLayout: Sendable {
    let nodes: [Node]
    let edges: [Edge]
    let laneCount: Int
    private let nodesByRow: [Int: Node]

    init(nodes: [Node], edges: [Edge], laneCount: Int) {
        self.nodes = nodes
        self.edges = edges
        self.laneCount = laneCount
        self.nodesByRow = Dictionary(
            nodes.map { ($0.rowIndex, $0) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    struct Node: Sendable, Identifiable {
        let id: String
        let lane: Int
        let rowIndex: Int
        let isMerge: Bool
    }

    struct Edge: Sendable {
        let fromRow: Int
        let fromLane: Int
        let toRow: Int
        let toLane: Int
        let isMergeParent: Bool   // true if this edge represents a non-first parent of a merge
    }

    func node(atRow row: Int) -> Node? {
        nodesByRow[row]
    }
}

nonisolated enum CommitGraphBuilder {
    static let workingTreeNodeID = "__WORKING_TREE__"

    /// Builds a lane/edge layout for commits assumed to be in reverse chronological
    /// order (newest first). Each commit's parents are resolved by hash; parents that
    /// are not present in `commits` (e.g. beyond `maxCount`) are dropped.
    static func build(from commits: [GitCommit], currentBranch: String? = nil) -> CommitGraphLayout {
        struct PendingEdge {
            let fromRow: Int
            let fromLane: Int
            let parentID: String
            let isMergeParent: Bool
        }

        let headAncestors = firstParentChain(for: currentBranch, in: commits)
        let reserveLaneZero = !headAncestors.isEmpty
        var activeLanes: [String?] = reserveLaneZero ? [nil] : []
        var nodes: [CommitGraphLayout.Node] = []
        var positions: [String: (lane: Int, row: Int)] = [:]
        var pendingEdges: [PendingEdge] = []
        var maxLaneSeen = 0

        for (row, commit) in commits.enumerated() {
            let isHeadLine = headAncestors.contains(commit.id)
            let lane = claimOrAssignLane(
                for: commit.id,
                isHeadLine: isHeadLine,
                reserveLaneZero: reserveLaneZero,
                activeLanes: &activeLanes
            )

            let isMerge = commit.parents.count > 1
            nodes.append(.init(id: commit.id, lane: lane, rowIndex: row, isMerge: isMerge))
            positions[commit.id] = (lane, row)
            maxLaneSeen = max(maxLaneSeen, lane + 1)

            if commit.parents.isEmpty {
                activeLanes[lane] = nil
            } else {
                activeLanes[lane] = commit.parents[0]
                pendingEdges.append(PendingEdge(fromRow: row, fromLane: lane, parentID: commit.parents[0], isMergeParent: false))

                for parent in commit.parents.dropFirst() {
                    let parentLane = assignSideLane(
                        for: parent,
                        isHeadParent: headAncestors.contains(parent),
                        reserveLaneZero: reserveLaneZero,
                        activeLanes: &activeLanes
                    )
                    maxLaneSeen = max(maxLaneSeen, parentLane + 1)
                    pendingEdges.append(PendingEdge(fromRow: row, fromLane: lane, parentID: parent, isMergeParent: true))
                }
            }
        }

        let edges = pendingEdges.compactMap { pending -> CommitGraphLayout.Edge? in
            guard let parentPos = positions[pending.parentID] else { return nil }
            return .init(
                fromRow: pending.fromRow,
                fromLane: pending.fromLane,
                toRow: parentPos.row,
                toLane: parentPos.lane,
                isMergeParent: pending.isMergeParent
            )
        }

        return CommitGraphLayout(nodes: nodes, edges: edges, laneCount: max(1, maxLaneSeen))
    }

    private static func firstParentChain(for branch: String?, in commits: [GitCommit]) -> Set<String> {
        guard let branch,
              let head = commits.first(where: { $0.refs.contains(branch) || $0.branch == branch }) else {
            return []
        }
        let byID = Dictionary(commits.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var chain: Set<String> = []
        if commits.first?.id == workingTreeNodeID {
            chain.insert(workingTreeNodeID)
        }
        var cursor: GitCommit? = head
        while let current = cursor, chain.insert(current.id).inserted {
            cursor = current.parents.first.flatMap { byID[$0] }
        }
        return chain
    }

    private static func claimOrAssignLane(
        for commitID: String,
        isHeadLine: Bool,
        reserveLaneZero: Bool,
        activeLanes: inout [String?]
    ) -> Int {
        var claimedLane: Int?
        for (idx, expected) in activeLanes.enumerated() where expected == commitID {
            if claimedLane == nil {
                claimedLane = idx
            } else {
                activeLanes[idx] = nil
            }
        }
        if isHeadLine, reserveLaneZero { return 0 }
        if let claimedLane { return claimedLane }

        let minLane = reserveLaneZero ? 1 : 0
        if let freeLane = activeLanes.indices.dropFirst(minLane).first(where: { activeLanes[$0] == nil }) {
            return freeLane
        }
        let lane = activeLanes.count
        activeLanes.append(nil)
        return lane
    }

    private static func assignSideLane(
        for parentID: String,
        isHeadParent: Bool,
        reserveLaneZero: Bool,
        activeLanes: inout [String?]
    ) -> Int {
        if isHeadParent, reserveLaneZero {
            activeLanes[0] = parentID
            return 0
        }
        let minLane = reserveLaneZero ? 1 : 0
        if let freeLane = activeLanes.indices.dropFirst(minLane).first(where: { activeLanes[$0] == nil }) {
            activeLanes[freeLane] = parentID
            return freeLane
        }
        let lane = activeLanes.count
        activeLanes.append(parentID)
        return lane
    }
}
