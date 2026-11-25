//
//  GitModels.swift
//  Maple
//
//  Created by Pool Camacho on 4/13/26.
//

import Foundation

struct GitRepository: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let path: String
    var currentBranch: String = "main"

    nonisolated init(name: String, path: String, currentBranch: String = "main") {
        self.id = path
        self.name = name
        self.path = path
        self.currentBranch = currentBranch
    }
}

struct GitCommit: Identifiable, Sendable {
    let id: String
    let shortID: String
    let message: String
    let author: String
    let date: Date
    let branch: String?
    let refs: [String]
    let parents: [String]

    nonisolated init(
        id: String,
        shortID: String,
        message: String,
        author: String,
        date: Date,
        branch: String?,
        parents: [String],
        refs: [String] = []
    ) {
        self.id = id
        self.shortID = shortID
        self.message = message
        self.author = author
        self.date = date
        self.branch = branch
        self.parents = parents
        self.refs = refs
    }
}

nonisolated struct GitCommitDetails: Sendable {
    let sha: String
    let shortSHA: String
    let authorName: String
    let authorEmail: String
    let authorDate: String
    let committerName: String
    let committerEmail: String
    let committerDate: String
    let parents: [String]
    let refs: [String]
    let fullMessage: String
    let statSummary: String
}

nonisolated struct GitFileChange: Identifiable, Hashable, Sendable {
    let id: String
    let path: String
    let status: FileStatus
    var isStaged: Bool

    nonisolated init(path: String, status: FileStatus, isStaged: Bool) {
        self.id = "\(path):\(isStaged ? "staged" : "unstaged")"
        self.path = path
        self.status = status
        self.isStaged = isStaged
    }

    enum FileStatus: String, Sendable {
        case modified = "M"
        case added = "A"
        case deleted = "D"
        case renamed = "R"
        case untracked = "?"
        case conflicted = "!"
    }
}

enum RepoOperationState: Sendable, Equatable {
    case idle
    case merging(head: String?)      // contents of .git/MERGE_HEAD (short SHA or branch)
    case rebasing(head: String?)     // branch being rebased
    case cherryPicking
    case reverting

    var isInProgress: Bool {
        if case .idle = self { return false }
        return true
    }

    var label: String {
        switch self {
        case .idle: return ""
        case .merging(let head): return head.map { "Merging \($0)" } ?? "Merging"
        case .rebasing(let head): return head.map { "Rebasing \($0)" } ?? "Rebasing"
        case .cherryPicking: return "Cherry-picking"
        case .reverting: return "Reverting"
        }
    }
}

struct GitBranch: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let isRemote: Bool
    let isCurrent: Bool

    nonisolated init(name: String, isRemote: Bool, isCurrent: Bool) {
        self.id = "\(isRemote ? "remote:" : "local:")\(name)"
        self.name = name
        self.isRemote = isRemote
        self.isCurrent = isCurrent
    }
}

nonisolated struct GitTag: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let targetShortSHA: String
    /// Annotation subject for annotated tags; the tagged commit's subject for
    /// lightweight tags.
    let subject: String

    nonisolated init(name: String, targetShortSHA: String, subject: String) {
        self.id = name
        self.name = name
        self.targetShortSHA = targetShortSHA
        self.subject = subject
    }
}

/// A contiguous run of diff lines under a single `@@ ... @@` hunk header.
/// Carries the original header text so patches can be reconstructed without
/// re-parsing line numbers into the same format git expects.
nonisolated struct DiffHunk: Identifiable, Sendable {
    let id = UUID()
    let header: String
    let oldStart: Int
    let oldCount: Int
    let newStart: Int
    let newCount: Int
    let lines: [DiffLine]

    nonisolated init(
        header: String,
        oldStart: Int,
        oldCount: Int,
        newStart: Int,
        newCount: Int,
        lines: [DiffLine]
    ) {
        self.header = header
        self.oldStart = oldStart
        self.oldCount = oldCount
        self.newStart = newStart
        self.newCount = newCount
        self.lines = lines
    }
}

/// One file's diff: the raw preamble lines (`diff --git`, `index`, `---`, `+++`)
/// grouped together with that file's hunks. Preserving the preamble is what
/// lets us round-trip a subset of hunks back into `git apply --cached`.
nonisolated struct DiffFile: Identifiable, Sendable {
    let id = UUID()
    let path: String?
    let preamble: [String]
    let hunks: [DiffHunk]
    /// True when git reported a binary difference (no textual hunks to show).
    let isBinary: Bool

    nonisolated init(path: String?, preamble: [String], hunks: [DiffHunk], isBinary: Bool = false) {
        self.path = path
        self.preamble = preamble
        self.hunks = hunks
        self.isBinary = isBinary
    }

    /// Flattened view for rendering; mirrors the old `[DiffLine]` shape
    /// (hunk headers as `.header` lines, followed by their content lines).
    var flattened: [DiffLine] {
        var out: [DiffLine] = []
        for hunk in hunks {
            out.append(DiffLine(content: hunk.header, type: .header, oldLineNumber: nil, newLineNumber: nil))
            out.append(contentsOf: hunk.lines)
        }
        return out
    }

    /// Builds a patch string including only the hunks at the given indices.
    /// Only valid for whole-hunk selection (the hunk header's line counts stay
    /// truthful). Partial-line selection lives in `patchText(forLines:)`.
    func patchText(forHunkIndices selected: Set<Int>) -> String {
        guard !selected.isEmpty, !preamble.isEmpty else { return "" }
        var lines: [String] = preamble
        for (index, hunk) in hunks.enumerated() where selected.contains(index) {
            lines.append(hunk.header)
            for line in hunk.lines {
                switch line.type {
                case .addition: lines.append("+" + line.content)
                case .deletion: lines.append("-" + line.content)
                case .context: lines.append(" " + line.content)
                case .header: continue
                }
            }
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// Builds a patch that keeps only the `+` / `-` lines named by `selection`
    /// within each hunk.
    /// - When `reverse` is `false` (staging): unselected additions are dropped
    ///   and unselected deletions become context lines.
    /// - When `reverse` is `true` (unstaging with `git apply --reverse`):
    ///   unselected additions become context lines (they are present in the
    ///   index) and unselected deletions are dropped (they are absent from the
    ///   index).
    ///
    /// - Parameters:
    ///   - selection: map of hunk index → set of line indices within
    ///     that hunk's `lines` array to keep as real `+` / `-` edits.
    ///   - reverse: set `true` when building a patch for `git apply --reverse`.
    /// - Returns: a git-apply-compatible patch, or an empty string if no hunk
    ///   contributes any selected change.
    func patchText(forLines selection: [Int: Set<Int>], reverse: Bool = false) -> String {
        guard !preamble.isEmpty else { return "" }

        var hunkLines: [String] = []
        var anyEmitted = false
        var totalOldCount = 0
        var totalNewCount = 0

        for (hunkIndex, hunk) in hunks.enumerated() {
            guard let selectedIndices = selection[hunkIndex],
                  !selectedIndices.isEmpty else { continue }

            let rewritten = Self.rewriteHunk(hunk, selectedLineIndices: selectedIndices, reverse: reverse)
            guard rewritten.hasRealEdit else { continue }

            let oldStart = rewritten.oldCount > 0 ? max(1, hunk.oldStart) : hunk.oldStart
            let newStart = rewritten.newCount > 0 ? max(1, hunk.newStart) : hunk.newStart
            hunkLines.append("@@ -\(oldStart),\(rewritten.oldCount) +\(newStart),\(rewritten.newCount) @@")
            hunkLines.append(contentsOf: rewritten.body)
            totalOldCount += rewritten.oldCount
            totalNewCount += rewritten.newCount
            anyEmitted = true
        }

        guard anyEmitted else { return "" }

        // If a newly added file is only partially unstaged (oldCount > 0), the
        // index still retains lines so git apply --reverse must see a normal
        // file header rather than `new file mode` / `--- /dev/null`.
        // Symmetrically, partially staging a deletion (newCount > 0) must not
        // claim `+++ /dev/null`.
        var adjustedPreamble = preamble
        if reverse, totalOldCount > 0, let filePath = path {
            adjustedPreamble = preamble.compactMap { line in
                if line.hasPrefix("new file mode ") { return nil }
                if line == "--- /dev/null" { return "--- a/\(filePath)" }
                return line
            }
        } else if !reverse, totalNewCount > 0, let filePath = path {
            adjustedPreamble = preamble.compactMap { line in
                if line.hasPrefix("deleted file mode ") { return nil }
                if line == "+++ /dev/null" { return "+++ b/\(filePath)" }
                return line
            }
        }

        return (adjustedPreamble + hunkLines).joined(separator: "\n") + "\n"
    }

    private struct RewrittenHunk {
        var body: [String]
        var oldCount: Int
        var newCount: Int
        var hasRealEdit: Bool
    }

    private static func rewriteHunk(_ hunk: DiffHunk, selectedLineIndices: Set<Int>, reverse: Bool) -> RewrittenHunk {
        var result = RewrittenHunk(body: [], oldCount: 0, newCount: 0, hasRealEdit: false)
        for (lineIndex, line) in hunk.lines.enumerated() {
            let isSelected = selectedLineIndices.contains(lineIndex)
            emit(line: line, isSelected: isSelected, reverse: reverse, into: &result)
        }
        return result
    }

    private static func emit(line: DiffLine, isSelected: Bool, reverse: Bool, into result: inout RewrittenHunk) {
        switch line.type {
        case .context:
            result.body.append(" " + line.content)
            result.oldCount += 1
            result.newCount += 1
        case .addition:
            if isSelected {
                result.body.append("+" + line.content)
                result.newCount += 1
                result.hasRealEdit = true
            } else if reverse {
                // In reverse mode, unselected additions already exist in the index
                // and must remain as context lines so `git apply --reverse` matches.
                result.body.append(" " + line.content)
                result.oldCount += 1
                result.newCount += 1
            }
        case .deletion:
            if isSelected {
                result.body.append("-" + line.content)
                result.oldCount += 1
                result.hasRealEdit = true
            } else if !reverse {
                // In forward mode, unselected deletions exist in the base and must
                // remain as context lines. In reverse mode, they are absent from the
                // index so they are dropped.
                result.body.append(" " + line.content)
                result.oldCount += 1
                result.newCount += 1
            }
        case .header:
            return
        }
    }
}

struct BlameLine: Sendable {
    let lineNumber: Int
    let content: String
    let commitHash: String
    let shortHash: String
    let author: String
    let date: Date
    let summary: String

    nonisolated init(lineNumber: Int, content: String, commitHash: String, shortHash: String, author: String, date: Date, summary: String) {
        self.lineNumber = lineNumber
        self.content = content
        self.commitHash = commitHash
        self.shortHash = shortHash
        self.author = author
        self.date = date
        self.summary = summary
    }
}

nonisolated struct DiffLine: Sendable {
    let content: String
    let type: LineType
    let oldLineNumber: Int?
    let newLineNumber: Int?

    nonisolated init(content: String, type: LineType, oldLineNumber: Int?, newLineNumber: Int?) {
        self.content = content
        self.type = type
        self.oldLineNumber = oldLineNumber
        self.newLineNumber = newLineNumber
    }

    enum LineType: Sendable {
        case context
        case addition
        case deletion
        case header
    }
}
