//
//  CommitMessageGenerator.swift
//  Maple
//
//  Created by Maple on 11/25/26.
//

import Foundation
import FoundationModels

enum CommitMessageGenerator {
    enum GeneratorError: LocalizedError {
        case modelUnavailable
        case emptyResult

        var errorDescription: String? {
            switch self {
            case .modelUnavailable:
                return "Apple Intelligence is not available on this Mac. Enable it in System Settings to generate commit messages."
            case .emptyResult:
                return "Could not generate a commit message from the staged diff."
            }
        }
    }

    static func generate(from stagedDiffSummary: String) async throws -> String {
        guard SystemLanguageModel.default.isAvailable else {
            throw GeneratorError.modelUnavailable
        }

        let session = LanguageModelSession(
            instructions: """
            You write concise Git commit messages in Conventional Commits format \
            (feat:, fix:, refactor:, docs:, test:, chore:, style:). \
            Output ONLY the commit message subject line (max 72 characters, imperative mood, no trailing period, no markdown, no quotes).
            """
        )

        let prompt = """
        Write a commit message for these staged changes:

        \(stagedDiffSummary)
        """

        let response = try await session.respond(to: prompt)
        let cleaned = response.content
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"`"))
            .components(separatedBy: .newlines)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !cleaned.isEmpty else {
            throw GeneratorError.emptyResult
        }
        return cleaned
    }
}
