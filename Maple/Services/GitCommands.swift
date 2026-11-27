//
//  GitCommands.swift
//  Maple
//
//  Created by Pool Camacho on 4/13/26.
//

import Foundation

extension GitService {

    private static let networkTimeout: TimeInterval = 60

    // MARK: - Commit

    func commit(message: String, amend: Bool = false, in directory: String) async throws {
        var args = ["commit", "-m", message]
        if amend {
            args.append("--amend")
        }
        _ = try await run(args, in: directory)
    }

    // MARK: - Push

    @discardableResult
    func push(
        remote: String = "origin",
        branch: String? = nil,
        setUpstream: Bool = false,
        in directory: String
    ) async throws -> String {
        var args = ["push"]
        if setUpstream {
            args.append("-u")
        }
        args.append(remote)
        if let branch {
            args.append(branch)
        }
        let output = try await run(args, in: directory, timeout: Self.networkTimeout)
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The upstream (tracking) ref of the current branch, e.g. "origin/main", or
    /// nil if the branch has none.
    func upstreamBranch(in directory: String) async -> String? {
        let result = try? await run(
            ["rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}"],
            in: directory
        )
        let trimmed = result?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmed?.isEmpty == false) ? trimmed : nil
    }

    /// Commit SHAs across local branches not yet pushed to any remote
    /// (plus any commits on HEAD ahead of its configured upstream).
    func unpushedCommitIDs(in directory: String) async -> Set<String> {
        var result: Set<String> = []

        if let allLocalOut = try? await run(["rev-list", "--branches", "--not", "--remotes"], in: directory) {
            for line in allLocalOut.split(separator: "\n") {
                let sha = String(line).trimmingCharacters(in: .whitespaces)
                if !sha.isEmpty { result.insert(sha) }
            }
        }

        if await upstreamBranch(in: directory) != nil,
           let headOut = try? await run(["rev-list", "@{u}..HEAD"], in: directory) {
            for line in headOut.split(separator: "\n") {
                let sha = String(line).trimmingCharacters(in: .whitespaces)
                if !sha.isEmpty { result.insert(sha) }
            }
        }

        return result
    }

    /// Configured remote names, in git's listing order.
    func remotes(in directory: String) async -> [String] {
        let output = (try? await run(["remote"], in: directory)) ?? ""
        return output
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    // MARK: - Pull

    @discardableResult
    func pull(remote: String = "origin", branch: String? = nil, in directory: String) async throws -> String {
        var args = ["pull", remote]
        if let branch {
            args.append(branch)
        }
        let output = try await run(args, in: directory, timeout: Self.networkTimeout)
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Fetch

    @discardableResult
    func fetch(remote: String = "origin", in directory: String) async throws -> String {
        let output = try await run(["fetch", remote], in: directory, timeout: Self.networkTimeout)
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Clone

    private static let cloneTimeout: TimeInterval = 600

    /// Clones `url` into `parentDirectory`/`name` and returns the resulting repo
    /// path. `parentDirectory` must already exist.
    func clone(url: String, into parentDirectory: String, name: String) async throws -> String {
        let destination = (parentDirectory as NSString).appendingPathComponent(name)
        _ = try await run(["clone", url, destination], in: parentDirectory, timeout: Self.cloneTimeout)
        return destination
    }

    /// Derives a folder name from a clone URL, e.g.
    /// `https://github.com/acme/repo.git` or `git@github.com:acme/repo.git` ->
    /// `repo`. Falls back to "repository" if nothing usable is found.
    nonisolated static func repositoryName(fromCloneURL url: String) -> String {
        var trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        while trimmed.hasSuffix("/") { trimmed = String(trimmed.dropLast()) }
        if trimmed.hasSuffix(".git") { trimmed = String(trimmed.dropLast(4)) }
        while trimmed.hasSuffix("/") { trimmed = String(trimmed.dropLast()) }

        if let separator = trimmed.lastIndex(where: { $0 == "/" || $0 == ":" }) {
            trimmed = String(trimmed[trimmed.index(after: separator)...])
        }
        return trimmed.isEmpty ? "repository" : trimmed
    }

    // MARK: - Commit Details & Diffs

    func diffFilesForCommit(_ commitHash: String, in directory: String) async throws -> [DiffFile] {
        let output = try await run(
            ["show", "--no-color", "--format=", commitHash],
            in: directory
        )
        return Self.parseDiffFiles(output)
    }

    func stagedDiffForCommitMessage(in directory: String, maxDiffChars: Int = 6000) async throws -> String {
        let stat = try await run(["diff", "--cached", "--stat"], in: directory)
        let diff = try await run(["diff", "--cached", "--no-color", "--unified=2"], in: directory)
        let trimmedDiff = diff.count > maxDiffChars
            ? String(diff.prefix(maxDiffChars)) + "\n... (diff truncated)"
            : diff
        return "Files changed:\n\(stat)\nDiff:\n\(trimmedDiff)"
    }

    func commitDetails(for commitHash: String, in directory: String) async throws -> GitCommitDetails {
        let separator = "<MAPLE_SEP>"
        let format = ["%H", "%h", "%an", "%ae", "%ad", "%cn", "%ce", "%cd", "%P", "%D", "%B"].joined(separator: separator)
        let metaOutput = try await run(
            ["show", "--no-patch", "--date=format:%Y-%m-%d %H:%M:%S %z", "--format=\(format)", commitHash],
            in: directory
        )
        let statOutput = (try? await run(
            ["show", "--no-patch", "--stat", "--format=", commitHash],
            in: directory
        )) ?? ""

        let parts = metaOutput.components(separatedBy: separator)
        func field(_ index: Int, fallback: String = "") -> String {
            index < parts.count ? parts[index] : fallback
        }

        let fullMessage = (parts.count > 10 ? parts[10...].joined(separator: separator) : "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return GitCommitDetails(
            sha: field(0, fallback: commitHash),
            shortSHA: field(1, fallback: String(commitHash.prefix(7))),
            authorName: field(2),
            authorEmail: field(3),
            authorDate: field(4),
            committerName: field(5),
            committerEmail: field(6),
            committerDate: field(7),
            parents: field(8).components(separatedBy: " ").filter { !$0.isEmpty },
            refs: Self.parseAllBranchesFromRefs(field(9)),
            fullMessage: fullMessage,
            statSummary: statOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    // MARK: - Apply patch (for interactive staging)

    /// Pipes a patch to `git apply`, optionally with `--cached` (to stage into
    /// the index) and/or `--reverse` (to unstage from the index).
    func applyPatch(_ patch: String, cached: Bool = false, reverse: Bool = false, in directory: String) async throws {
        var args = ["apply", "--whitespace=nowarn"]
        if cached { args.append("--cached") }
        if reverse { args.append("--reverse") }
        args.append("-")
        _ = try await run(args, in: directory, stdin: patch)
    }

    // MARK: - Blame

    func blame(for filePath: String, in directory: String) async throws -> [BlameLine] {
        let output = try await run(["blame", "--porcelain", "--", filePath], in: directory)
        return Self.parseBlame(output)
    }

    static func parseBlame(_ output: String) -> [BlameLine] {
        struct CommitMeta {
            var author: String = ""
            var date: Date = Date()
            var summary: String = ""
        }

        var lines: [BlameLine] = []
        var metaCache: [String: CommitMeta] = [:]

        var currentHash = ""
        var currentFinalLine = 0
        var currentMeta = CommitMeta()

        for raw in output.components(separatedBy: "\n") {
            if raw.hasPrefix("\t") {
                let content = String(raw.dropFirst())
                lines.append(BlameLine(
                    lineNumber: currentFinalLine,
                    content: content,
                    commitHash: currentHash,
                    shortHash: String(currentHash.prefix(7)),
                    author: currentMeta.author,
                    date: currentMeta.date,
                    summary: currentMeta.summary
                ))
                continue
            }

            let parts = raw.components(separatedBy: " ")
            // Blame porcelain commit header: "<40-char hash> <origLine> <finalLine> [<numLines>]"
            if parts.count >= 3, parts[0].count == 40, Int(parts[2]) != nil {
                currentHash = parts[0]
                currentFinalLine = Int(parts[2]) ?? 0
                currentMeta = metaCache[currentHash] ?? CommitMeta()
            } else if raw.hasPrefix("author ") {
                currentMeta.author = String(raw.dropFirst("author ".count))
                metaCache[currentHash] = currentMeta
            } else if raw.hasPrefix("author-time ") {
                let ts = String(raw.dropFirst("author-time ".count))
                currentMeta.date = Date(timeIntervalSince1970: TimeInterval(ts) ?? 0)
                metaCache[currentHash] = currentMeta
            } else if raw.hasPrefix("summary ") {
                currentMeta.summary = String(raw.dropFirst("summary ".count))
                metaCache[currentHash] = currentMeta
            }
        }

        return lines
    }

    func diffForCommit(_ commitHash: String, in directory: String) async throws -> [DiffLine] {
        let output = try await run(
            ["show", "--no-color", "--format=", commitHash],
            in: directory
        )
        return Self.parseDiff(output)
    }

    /// `git diff` skips untracked files, so we synthesize an all-additions diff
    /// by reading the file directly.
    func diffForUntrackedFile(_ filePath: String, in directory: String) async throws -> [DiffLine] {
        let fullPath = (directory as NSString).appendingPathComponent(filePath)
        guard let data = FileManager.default.contents(atPath: fullPath),
              let content = String(data: data, encoding: .utf8) else {
            return []
        }

        var lines: [DiffLine] = []
        lines.append(DiffLine(content: "new file: \(filePath)", type: .header, oldLineNumber: nil, newLineNumber: nil))

        for (index, line) in content.components(separatedBy: "\n").enumerated() {
            lines.append(DiffLine(
                content: line,
                type: .addition,
                oldLineNumber: nil,
                newLineNumber: index + 1
            ))
        }

        return lines
    }

    // MARK: - Discard changes

    /// Discards unstaged working-tree changes for a single file. Untracked
    /// files are removed with `git clean`; tracked files are restored from the
    /// index with `git checkout --`.
    func discard(file: String, status: GitFileChange.FileStatus, in directory: String) async throws {
        if status == .untracked {
            _ = try await run(["clean", "-fd", "--", file], in: directory)
        } else {
            _ = try await run(["checkout", "--", file], in: directory)
        }
    }

    /// Discards all unstaged working-tree changes and removes untracked files.
    func discardAll(in directory: String) async throws {
        _ = try await run(["checkout", "--", "."], in: directory)
        _ = try await run(["clean", "-fd"], in: directory)
    }
}
