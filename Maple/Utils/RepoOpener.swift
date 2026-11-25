//
//  RepoOpener.swift
//  Maple
//
//  Created by Maple on 11/25/26.
//

import AppKit
import Foundation
import UniformTypeIdentifiers

struct ExternalApp: Identifiable {
    let id: String
    let name: String
    let url: URL
    let systemImage: String
}

enum RepoOpener {
    private struct AppSpec {
        let name: String
        let bundleID: String
        let systemImage: String
    }

    private static let editorSpecs: [AppSpec] = [
        AppSpec(name: "VS Code", bundleID: "com.microsoft.VSCode", systemImage: "chevron.left.forwardslash.chevron.right"),
        AppSpec(name: "VS Code Insiders", bundleID: "com.microsoft.VSCodeInsiders", systemImage: "chevron.left.forwardslash.chevron.right"),
        AppSpec(name: "Antigravity IDE", bundleID: "com.google.antigravity-ide", systemImage: "sparkles"),
        AppSpec(name: "Antigravity", bundleID: "com.google.antigravity", systemImage: "sparkles"),
        AppSpec(name: "Cursor", bundleID: "com.todesktop.230313mzl4w4u92", systemImage: "cursorarrow.rays"),
        AppSpec(name: "Windsurf", bundleID: "com.exafunction.windsurf", systemImage: "wind"),
        AppSpec(name: "Zed", bundleID: "dev.zed.Zed", systemImage: "bolt"),
        AppSpec(name: "Xcode", bundleID: "com.apple.dt.Xcode", systemImage: "hammer"),
        AppSpec(name: "Android Studio", bundleID: "com.google.android.studio", systemImage: "smartphone"),
        AppSpec(name: "IntelliJ IDEA", bundleID: "com.jetbrains.intellij", systemImage: "cube"),
        AppSpec(name: "IntelliJ IDEA CE", bundleID: "com.jetbrains.intellij.ce", systemImage: "cube"),
        AppSpec(name: "Sublime Text", bundleID: "com.sublimetext.4", systemImage: "doc.plaintext")
    ]

    private static let terminalSpecs: [AppSpec] = [
        AppSpec(name: "iTerm", bundleID: "com.googlecode.iterm2", systemImage: "terminal"),
        AppSpec(name: "Terminal", bundleID: "com.apple.Terminal", systemImage: "terminal")
    ]

    static func installedEditors() -> [ExternalApp] {
        installedApps(from: editorSpecs)
    }

    static func installedTerminals() -> [ExternalApp] {
        installedApps(from: terminalSpecs)
    }

    private static func installedApps(from specs: [AppSpec]) -> [ExternalApp] {
        specs.compactMap { spec in
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: spec.bundleID) else {
                return nil
            }
            return ExternalApp(id: spec.bundleID, name: spec.name, url: url, systemImage: spec.systemImage)
        }
    }

    static func openRepository(at path: String, with appURL: URL) {
        let repoURL = URL(fileURLWithPath: path)
        let config = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.open([repoURL], withApplicationAt: appURL, configuration: config)
    }

    static func revealInFinder(path: String) {
        let repoURL = URL(fileURLWithPath: path)
        NSWorkspace.shared.activateFileViewerSelecting([repoURL])
    }

    static func chooseOtherAppAndOpen(repositoryPath: String) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.message = "Choose an application to open this repository"
        panel.prompt = "Open"

        if panel.runModal() == .OK, let appURL = panel.url {
            openRepository(at: repositoryPath, with: appURL)
        }
    }
}
