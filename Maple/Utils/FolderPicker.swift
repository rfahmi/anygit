//
//  FolderPicker.swift
//  Maple
//
//  Created by Pool Camacho on 4/13/26.
//

import SwiftUI
import AppKit

func openFolderPicker(state: AppState) {
    let panel = NSOpenPanel()
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    panel.allowsMultipleSelection = true
    panel.message = "Select one or more Git repository folders"
    panel.prompt = "Open"

    if panel.runModal() == .OK, !panel.urls.isEmpty {
        let paths = panel.urls.map(\.path)
        Task {
            await state.coordinator.openRepositories(at: paths)
        }
    }
}
